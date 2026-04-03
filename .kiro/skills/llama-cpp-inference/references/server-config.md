# llama-server Configuration Guide

Detailed configuration reference for llama-server: flags, continuous batching, chat templates, embedding mode, multi-user serving, speculative decoding, and API endpoints.

## Complete Server Flags

### Model & Context

| Flag | Default | Description |
|---|---|---|
| `-m, --model` | required | Path to GGUF model file |
| `-c, --ctx-size` | 4096 | Context size in tokens. Ảnh hưởng trực tiếp VRAM usage |
| `-n, --predict` | -1 | Max tokens to predict (-1 = infinite) |
| `-s, --seed` | -1 | Random seed (-1 = random) |
| `--keep` | 0 | Số tokens giữ lại từ initial prompt khi context shift |
| `-r, --reverse-prompt` | none | Stop generation khi gặp string này |

### GPU Offloading

| Flag | Default | Description |
|---|---|---|
| `-ngl, --n-gpu-layers` | 0 | Số layers offload lên GPU. 99 = full offload |
| `-sm, --split-mode` | layer | Multi-GPU split: `layer` (default), `row`, `none` |
| `-mg, --main-gpu` | 0 | GPU chính cho computation khi multi-GPU |
| `-ts, --tensor-split` | auto | Tỷ lệ VRAM split giữa GPUs (e.g., `3,7` cho 30%/70%) |

### Performance

| Flag | Default | Description |
|---|---|---|
| `-t, --threads` | auto | CPU threads cho generation (= physical cores) |
| `-tb, --threads-batch` | auto | CPU threads cho batch processing |
| `-b, --batch-size` | 2048 | Batch size cho prompt processing |
| `-ub, --ubatch-size` | 512 | Micro-batch size cho pipeline parallelism |
| `-fa, --flash-attn` | false | Enable flash attention (giảm VRAM, tăng speed) |
| `--mlock` | false | Lock model trong RAM (tránh swap) |
| `--no-mmap` | false | Disable memory mapping |
| `--numa` | disabled | NUMA optimization: `distribute`, `isolate`, `numactl` |

### Server & Network

| Flag | Default | Description |
|---|---|---|
| `--host` | 127.0.0.1 | Bind address (0.0.0.0 cho external access) |
| `--port` | 8080 | Listen port |
| `--api-key` | none | API key cho authentication |
| `--ssl-key-file` | none | SSL private key file path |
| `--ssl-cert-file` | none | SSL certificate file path |
| `--timeout` | 600 | Request timeout in seconds |

### Batching & Slots

| Flag | Default | Description |
|---|---|---|
| `-np, --parallel` | 1 | Số parallel slots (concurrent users) |
| `-cb, --cont-batching` | true | Continuous batching (auto khi -np > 1) |
| `--slots-endpoint` | false | Enable `/slots` endpoint để monitor slot usage |

## Continuous Batching Setup

Continuous batching cho phép serve nhiều users đồng thời, mỗi user có slot riêng trong KV cache.

### Basic Multi-User Config

```bash
# 4 parallel users, continuous batching
llama-server -m ./models/model.Q4_K_M.gguf \
  -c 8192 -ngl 99 \
  -np 4 -cb \
  --host 0.0.0.0 --port 8080
```

### VRAM Estimation cho Multi-User

```
Total VRAM ≈ model_size + (n_ctx × n_parallel × bytes_per_token)
```

Ví dụ: Q4_K_M 7B (4.1 GB) + 4 slots × 4096 ctx:
- Không flash-attn: ~4.1 + 2.0 = ~6.1 GB
- Với flash-attn: ~4.1 + 1.2 = ~5.3 GB

### Slot Monitoring

```bash
# Enable slot monitoring
llama-server -m model.gguf -np 4 --slots-endpoint

# Check slot status
curl -s http://localhost:8080/slots | python -m json.tool
```

Response cho biết mỗi slot đang idle hay processing, context usage, và tokens generated.

### Tuning Parallel Slots

| Slots (-np) | Context per slot | Total context | Use Case |
|---|---|---|---|
| 1 | Full -c | -c | Single user, max context |
| 2-4 | -c / -np | -c | Small team, balanced |
| 8-16 | -c / -np | -c | Multi-user API, shorter contexts |

⚠️ Context được chia đều giữa slots: `-c 8192 -np 4` = mỗi slot 2048 tokens. Tăng `-c` nếu cần context dài per user.

## Chat Templates

Chat template quyết định cách format messages cho model. Sai template = output garbage.

### Built-in Templates

| Template | Models | Flag |
|---|---|---|
| `llama2` | Llama 2 Chat, CodeLlama | `--chat-template llama2` |
| `llama3` | Llama 3, Llama 3.1 | `--chat-template llama3` |
| `chatml` | Qwen, Yi, Mistral (some) | `--chat-template chatml` |
| `phi` | Phi-2, Phi-3 | `--chat-template phi3` |
| `gemma` | Gemma, Gemma 2 | `--chat-template gemma` |
| `command-r` | Command R, Command R+ | `--chat-template command-r` |
| `deepseek` | DeepSeek V2, V3 | `--chat-template deepseek` |
| `monarch` | Monarch models | `--chat-template monarch` |

### Custom Jinja Template

```bash
# Dùng custom Jinja2 template file
llama-server -m model.gguf \
  --chat-template-file ./my-template.jinja
```

### Auto-Detection

Nếu không chỉ định `--chat-template`, llama-server sẽ cố detect từ GGUF metadata. Tuy nhiên, không phải mọi GGUF đều có metadata đúng → luôn chỉ định explicit khi biết model family.

## Embedding Mode

```bash
# Launch server với embedding support
llama-server -m ./models/nomic-embed-text-v1.5.Q8_0.gguf \
  --embedding --port 8080 -c 8192

# Generate embeddings
curl -s http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed",
    "input": "Hello world"
  }' | python -m json.tool
```

⚠️ Embedding mode dùng model embedding chuyên dụng (nomic-embed, bge, e5...), không phải LLM chat model. LLM embeddings chất lượng thấp hơn nhiều.

### Batch Embeddings

```bash
curl -s http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed",
    "input": ["text 1", "text 2", "text 3"]
  }'
```

## Speculative Decoding

Dùng draft model nhỏ để tăng tốc generation từ model lớn.

```bash
# Main model + draft model
llama-server \
  -m ./models/llama-3.1-70b.Q4_K_M.gguf \
  -md ./models/llama-3.1-8b.Q4_K_M.gguf \
  --draft-max 16 --draft-min 1 \
  -ngl 99 -ngld 99 \
  -c 4096 --port 8080
```

| Flag | Description |
|---|---|
| `-md, --model-draft` | Path to draft GGUF model (nhỏ hơn, cùng tokenizer) |
| `--draft-max` | Max speculative tokens per step |
| `--draft-min` | Min speculative tokens per step |
| `-ngld, --n-gpu-layers-draft` | GPU layers cho draft model |

**Requirements:**
- Draft model phải cùng tokenizer/vocabulary với main model
- Draft model nên nhỏ hơn 3-5x so với main model
- Speedup thường 1.5-2.5x, phụ thuộc vào acceptance rate

## API Endpoints

### OpenAI-Compatible Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/v1/chat/completions` | POST | Chat completion (streaming supported) |
| `/v1/completions` | POST | Text completion |
| `/v1/embeddings` | POST | Generate embeddings (cần `--embedding`) |
| `/v1/models` | GET | List loaded models |

### llama.cpp Native Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Server health check |
| `/slots` | GET | Slot status (cần `--slots-endpoint`) |
| `/metrics` | GET | Prometheus metrics |
| `/completion` | POST | Native completion endpoint |
| `/tokenize` | POST | Tokenize text |
| `/detokenize` | POST | Detokenize tokens |

### Health Check

```bash
# Basic health
curl -s http://localhost:8080/health
# Returns: {"slots_idle":4,"slots_processing":0,"status":"ok"}

# Prometheus metrics
curl -s http://localhost:8080/metrics
```

### Streaming Response

```bash
curl -N http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "model",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

## Production Checklist

```bash
# Production-ready launch
llama-server -m ./models/model.Q4_K_M.gguf \
  --host 0.0.0.0 --port 8080 \
  -c 8192 -ngl 99 -fa \
  -np 4 -cb \
  --api-key "your-secret-key" \
  --timeout 300 \
  --chat-template llama3 \
  --mlock \
  -t $(nproc --all)
```

**Checklist:**
- [ ] `-ngl 99` hoặc đủ layers cho GPU offload
- [ ] `-fa` enabled cho flash attention
- [ ] `-np` phù hợp với expected concurrent users
- [ ] `--api-key` set cho authentication
- [ ] `--chat-template` explicit, không rely on auto-detect
- [ ] `--mlock` để tránh model bị swap ra disk
- [ ] Monitor với `/health` và `/metrics` endpoints
