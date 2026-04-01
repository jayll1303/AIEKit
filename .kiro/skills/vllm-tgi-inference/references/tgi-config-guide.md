# TGI Configuration Guide

Detailed configuration reference for HuggingFace Text Generation Inference (TGI), covering Docker launch patterns, sharding, quantization, watermarking, and grammar-constrained generation.

## Docker Launch Patterns

TGI is primarily deployed via Docker. The official image includes all dependencies.

### Basic Launch

```bash
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  -e HUGGING_FACE_HUB_TOKEN=$HF_TOKEN \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct
```

### With Model Cache

```bash
# Mount a persistent cache directory to avoid re-downloading
docker run --gpus all -p 8080:80 \
  -v $PWD/tgi-cache:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct
```

### docker-compose.yml

```yaml
services:
  tgi:
    image: ghcr.io/huggingface/text-generation-inference:latest
    ports:
      - "8080:80"
    volumes:
      - ./tgi-cache:/data
    environment:
      - HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    shm_size: "1g"
    command: >
      --model-id meta-llama/Llama-3.1-8B-Instruct
      --max-input-tokens 2048
      --max-total-tokens 4096
```

## Sharding (Multi-GPU)

TGI supports tensor parallelism via the `--num-shard` flag.

### Configuration

```bash
# 2-GPU sharding
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-70B-Instruct \
  --num-shard 2

# 4-GPU sharding
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-70B-Instruct \
  --num-shard 4
```

### Sharding Requirements

- Number of shards must evenly divide the model's attention heads
- All GPUs should have the same VRAM capacity
- NCCL must be functional across GPUs
- Use `CUDA_VISIBLE_DEVICES` to select specific GPUs

```bash
# Use only GPU 0 and GPU 2
docker run --gpus '"device=0,2"' -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-70B-Instruct \
  --num-shard 2
```

## Quantization

TGI supports several quantization methods for reduced VRAM usage.

### Supported Methods

| Method | Flag | Notes |
|---|---|---|
| AWQ | `--quantize awq` | Pre-quantized AWQ models |
| GPTQ | `--quantize gptq` | Pre-quantized GPTQ models |
| bitsandbytes NF4 | `--quantize bitsandbytes-nf4` | Runtime 4-bit quantization |
| bitsandbytes FP4 | `--quantize bitsandbytes-fp4` | Runtime 4-bit (FP4 variant) |
| EETQ | `--quantize eetq` | 8-bit quantization |

### AWQ Example

```bash
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id TheBloke/Llama-2-13B-AWQ \
  --quantize awq \
  --max-input-tokens 2048 \
  --max-total-tokens 4096
```

### Runtime Quantization (bitsandbytes)

```bash
# 4-bit NF4 runtime quantization (no pre-quantized model needed)
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct \
  --quantize bitsandbytes-nf4
```

## Watermarking

TGI includes built-in text watermarking support for detecting AI-generated text.

```bash
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct \
  --watermark
```

Watermarking embeds a statistical signal in generated text that can be detected later without access to the model. The watermark is invisible to human readers but detectable algorithmically.

## Grammar-Constrained Generation

TGI supports constraining output to match a specific grammar, useful for structured output (JSON, XML, etc.).

### JSON Schema Constraint

```bash
# Request with JSON schema constraint via API
curl -s http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Extract the name and age from: John is 30 years old.",
    "parameters": {
      "max_new_tokens": 100,
      "grammar": {
        "type": "json",
        "value": {
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"}
          },
          "required": ["name", "age"]
        }
      }
    }
  }'
```

### Regex Constraint

```bash
curl -s http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Generate a US phone number:",
    "parameters": {
      "max_new_tokens": 20,
      "grammar": {
        "type": "regex",
        "value": "\\d{3}-\\d{3}-\\d{4}"
      }
    }
  }'
```

## Token Limits and Batching

### Token Configuration

| Flag | Default | Description |
|---|---|---|
| `--max-input-tokens` | 1024 | Maximum input sequence length |
| `--max-total-tokens` | 2048 | Maximum total tokens (input + generated) |
| `--max-batch-prefill-tokens` | 4096 | Max tokens in a single prefill batch |
| `--max-concurrent-requests` | 128 | Max concurrent requests |
| `--waiting-served-ratio` | 0.3 | Ratio of waiting vs served requests for scheduling |

### Tuning for Throughput

```bash
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct \
  --max-concurrent-requests 256 \
  --max-batch-prefill-tokens 8192 \
  --max-total-tokens 4096
```

### Tuning for Low Latency

```bash
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct \
  --max-concurrent-requests 16 \
  --max-batch-prefill-tokens 2048
```

## TGI API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/generate` | POST | Single generation (TGI native) |
| `/generate_stream` | POST | Streaming generation (TGI native) |
| `/v1/chat/completions` | POST | OpenAI-compatible chat |
| `/v1/completions` | POST | OpenAI-compatible completion |
| `/v1/models` | GET | List served models |
| `/health` | GET | Health check |
| `/info` | GET | Model and server info |
| `/metrics` | GET | Prometheus metrics |

## Environment Variables

| Variable | Description |
|---|---|
| `HUGGING_FACE_HUB_TOKEN` | HuggingFace token for gated models |
| `CUDA_VISIBLE_DEVICES` | Restrict visible GPUs |
| `LOG_LEVEL` | Logging level (info, debug, warn) |
| `PORT` | Override default port (80) |

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for NVIDIA Container Toolkit setup and GPU passthrough configuration
