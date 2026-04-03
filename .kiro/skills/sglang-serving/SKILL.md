---
name: sglang-serving
description: "Serve LLMs with SGLang for structured generation and high-throughput inference. Use when launching SGLang server, using RadixAttention prefix caching, constrained JSON/regex output, structured decoding, or when needing faster inference than vLLM."
---

# SGLang Serving

Server launch patterns and configuration for deploying LLM inference using SGLang Runtime (SRT). Covers RadixAttention prefix caching, structured output (JSON schema, regex, EBNF), quantized model serving, and OpenAI-compatible API usage.

## Scope

This skill handles:
- Launching SGLang server with correct flags, quantization, and tensor parallelism
- Configuring RadixAttention prefix caching for shared-prefix workloads
- Structured output generation: JSON schema, regex, EBNF constrained decoding
- Calling OpenAI-compatible `/v1/` endpoints from Python, sglang client, or curl
- Tuning chunked prefill, memory fraction, and batch scheduling for throughput
- Diagnosing model loading failures, OOM errors, and slow generation

Does NOT handle:
- Training or fine-tuning models (→ hf-transformers-trainer, unsloth-training)
- Quantizing models before serving (GGUF, GPTQ, AWQ conversion) (→ model-quantization)
- Running Ollama or llama.cpp local inference (→ ollama-local-llm, llama-cpp-inference)
- Building GPU-enabled Docker containers or NGC base images (→ docker-gpu-setup)
- Resolving CUDA/cuDNN/driver version conflicts on host (→ python-ml-deps)

## When to Use

- Deploying a local LLM server with structured output (JSON schema, regex, EBNF)
- Workloads with shared prefixes (system prompts, few-shot) that benefit from RadixAttention
- Needing higher throughput than vLLM for prefix-heavy workloads (up to 3× faster)
- Launching SGLang server with tensor parallelism across multiple GPUs
- Serving FP8, INT4, AWQ, or GPTQ quantized models
- Choosing between SGLang, vLLM, and TGI for a deployment scenario

## Engine Decision Table

| Scenario | Recommended | Key Config | Why |
|---|---|---|---|
| Structured JSON/regex output | **SGLang** | `json_schema`, `regex` params | Native constrained decoding, fastest structured output |
| Shared prefix workloads (few-shot, system prompt) | **SGLang** | RadixAttention (automatic) | Up to 3× faster with prefix caching via radix tree |
| Maximum throughput, broad model support | vLLM | `--max-num-seqs 256` | Mature PagedAttention, largest model ecosystem |
| Docker-native, HF ecosystem | TGI | Docker image | Official HF container, built-in grammar constraints |
| GGUF local inference | vLLM / llama.cpp | `--quantization` / `llama-server` | SGLang không hỗ trợ GGUF |
| Multi-modal (vision + language) | **SGLang** | `--model-path` (VLM) | Native VLM support, RadixAttention for image tokens |
| EBNF grammar constraints | **SGLang** | `ebnf` param | Built-in EBNF grammar engine |

**Rules of thumb**:
- **SGLang** excels at structured output, prefix caching, and multi-modal serving.
- **vLLM** excels at broad model/quantization support and mature ecosystem.
- **TGI** excels at Docker-native deployment and HuggingFace integration.
- All three expose OpenAI-compatible APIs — client code is interchangeable.

## Quick Start

### Installation

```bash
pip install "sglang[all]"
```

⚠️ **HARD GATE:** Do NOT launch server trước khi estimate VRAM. Rule of thumb: FP16 ≈ 2 GB per 1B params, 4-bit ≈ 0.5 GB per 1B params, plus 1-2 GB overhead. Run `nvidia-smi` để confirm available VRAM.

### Basic Server Launch

```bash
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 \
  --port 30000
```

**Validate:** `curl -s http://localhost:30000/v1/models | python -m json.tool` returns model list. If not → check `nvidia-smi` và server logs.

### Tensor Parallelism (Multi-GPU)

```bash
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-70B-Instruct \
  --tp 2 \
  --port 30000
```

**Validate:** `nvidia-smi` shows VRAM usage on all TP GPUs. TP size phải chia hết số attention heads.

### Serving Quantized Models

```bash
# FP8 quantized
python -m sglang.launch_server \
  --model-path neuralmagic/Meta-Llama-3.1-8B-Instruct-FP8 \
  --port 30000

# AWQ quantized
python -m sglang.launch_server \
  --model-path TheBloke/Llama-2-7B-AWQ \
  --quantization awq \
  --port 30000

# GPTQ quantized
python -m sglang.launch_server \
  --model-path TheBloke/Llama-2-7B-GPTQ \
  --quantization gptq \
  --port 30000
```

### Key Flags

| Flag | Default | Description |
|---|---|---|
| `--model-path` | required | HuggingFace model ID hoặc local path |
| `--port` | 30000 | Server port |
| `--tp` | 1 | Tensor parallelism (số GPU) |
| `--quantization` | none | `awq`, `gptq`, `fp8`, `marlin` |
| `--mem-fraction-static` | 0.88 | Fraction GPU memory cho KV cache (0.0-1.0) |
| `--chunked-prefill-size` | auto | Chunk size cho prefill (giảm TTFT) |
| `--max-running-requests` | auto | Max concurrent requests |
| `--context-length` | auto | Override max context length |
| `--trust-remote-code` | false | Allow custom model code |
| `--disable-radix-cache` | false | Tắt RadixAttention (debug only) |

## Structured Output

SGLang hỗ trợ constrained decoding trực tiếp qua OpenAI-compatible API:

```python
from openai import OpenAI
import json

client = OpenAI(base_url="http://localhost:30000/v1", api_key="none")

# JSON Schema constrained output
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a user profile"}],
    extra_body={
        "json_schema": json.dumps({
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer"},
                "email": {"type": "string", "format": "email"}
            },
            "required": ["name", "age", "email"]
        })
    },
)

# Regex constrained output
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a phone number"}],
    extra_body={"regex": r"\d{3}-\d{3}-\d{4}"},
)
```

> For detailed structured output patterns including EBNF grammar, batch generation, and function calling, see [Structured Output reference](references/structured-output.md)

## Client Code

OpenAI-compatible API — same client code as vLLM/TGI:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:30000/v1", api_key="none")

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain RadixAttention in one paragraph."},
    ],
    temperature=0.7,
    max_tokens=256,
)
print(response.choices[0].message.content)
```

```bash
# curl
curl -s http://localhost:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7,
    "max_tokens": 128
  }' | python -m json.tool
```

## Diagnostic Checklist

```
Model fails to load or OOM?
├─ VRAM estimation
│   ├─ FP16: ~2 GB per 1B params
│   ├─ 4-bit quantized: ~0.5 GB per 1B params
│   ├─ Add ~1-2 GB overhead cho KV cache + runtime
│   └─ Check: nvidia-smi trước và trong khi load
│
├─ Memory fraction
│   ├─ --mem-fraction-static 0.88 (default) — giảm nếu OOM
│   ├─ --context-length để limit context → giảm KV cache
│   └─ --max-running-requests để limit concurrent requests
│
├─ Tensor parallel config
│   ├─ TP size phải chia hết attention heads
│   ├─ Tất cả GPU phải cùng VRAM capacity
│   └─ Check NCCL errors → verify GPU interconnect
│
├─ Slow first request?
│   ├─ Normal: RadixAttention cache cold start
│   ├─ Subsequent requests with shared prefix sẽ nhanh hơn nhiều
│   └─ --chunked-prefill-size để giảm TTFT
│
├─ Slow generation?
│   ├─ Check GPU utilization: nvidia-smi -l 1
│   ├─ AWQ thường nhanh hơn GPTQ cho inference
│   └─ PCIe bottleneck? → NVLink hoặc giảm TP size
│
└─ Model not supported?
    ├─ Check: github.com/sgl-project/sglang supported models
    └─ Custom architectures: --trust-remote-code
```

> For detailed performance tuning including RadixAttention, chunked prefill, and benchmarking, see [Performance Tuning reference](references/performance-tuning.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "SGLang giống vLLM, dùng cái nào cũng được" | SGLang có RadixAttention — với shared prefix workloads (few-shot, system prompt), throughput cao hơn vLLM 2-3×. Nhưng vLLM có ecosystem rộng hơn và hỗ trợ GGUF. Chọn theo workload. |
| "Tắt RadixAttention để tiết kiệm memory" | RadixAttention là core advantage của SGLang. Tắt nó (`--disable-radix-cache`) chỉ nên dùng khi debug. Trong production, prefix caching giảm VRAM usage cho repeated prefixes. |
| "Set `--mem-fraction-static 1.0` cho max throughput" | Giống vLLM, reserve 100% VRAM sẽ OOM khi concurrent requests tăng. Default 0.88 đã tối ưu. Không nên vượt 0.95. |
| "Structured output chậm, dùng post-processing parse JSON tốt hơn" | SGLang constrained decoding (json_schema, regex) enforce output format at token level — không cần retry khi JSON invalid. Nhanh hơn và reliable hơn post-processing. |
| "Dùng SGLang cho GGUF models" | SGLang không hỗ trợ GGUF. Dùng vLLM hoặc llama.cpp cho GGUF inference. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to quantize model to GPTQ/AWQ/FP8 before serving | model-quantization | Handles AutoGPTQ, AutoAWQ, FP8 conversion workflows |
| GPU not visible or need Docker container setup | docker-gpu-setup | NVIDIA Container Toolkit, docker-compose GPU passthrough |
| CUDA/cuDNN version mismatch khi install SGLang | python-ml-deps | PyTorch CUDA index URLs, driver/toolkit compatibility |
| Want vLLM or TGI instead of SGLang | vllm-tgi-inference | vLLM PagedAttention, TGI Docker-native deployment |
| Want GGUF inference (not supported by SGLang) | llama-cpp-inference | llama-server, llama-cli, llama-cpp-python |

## References

- [Structured Output](references/structured-output.md) — JSON schema, regex, EBNF constrained generation, function calling, batch structured output
  **Load when:** implementing structured/constrained output, JSON schema decoding, regex patterns, EBNF grammar, or function calling with SGLang
- [Performance Tuning](references/performance-tuning.md) — RadixAttention deep dive, chunked prefill, tensor parallelism, FP8/INT4 serving, memory tuning, benchmarking
  **Load when:** optimizing throughput, tuning RadixAttention prefix caching, configuring chunked prefill, or benchmarking SGLang vs vLLM
