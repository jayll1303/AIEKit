---
name: text-embeddings-inference
description: "Deploy and serve embedding/reranker models with HuggingFace TEI. Use when launching TEI Docker, configuring embeddings API, choosing embedding models, tuning batch performance, or building RAG pipelines with TEI."
---

# Text Embeddings Inference (TEI)

Deploy and configure HuggingFace's TEI server for high-performance text embeddings, re-ranking, and sequence classification.

## Scope

Handles: TEI Docker deployment, model selection, API usage, performance tuning, client integration.
Does NOT handle:
- Model training/fine-tuning (→ hf-transformers-trainer)
- Model quantization (→ model-quantization)
- Vector database setup (→ text-embeddings-rag)
- General HF Hub operations (→ hf-hub-datasets)

## When to Use

- Deploying a local embedding server for RAG or semantic search
- Choosing between embedding models for TEI
- Configuring TEI Docker for specific GPU hardware
- Using TEI's OpenAI-compatible API
- Tuning TEI batch/concurrency for throughput
- Setting up re-ranker models for search quality

## Hardware → Docker Image Decision Table

| Hardware | CUDA CC | Docker Image Tag |
|---|---|---|
| CPU (x86_64) | N/A | `cpu-1.9` |
| CPU (ARM64) | N/A | `cpu-arm64-1.9` |
| T4, RTX 2000 | 75 | `turing-1.9` (experimental) |
| A100, A30 | 80 | `1.9` (default) |
| A10, A40 | 86 | `86-1.9` |
| RTX 4000 series | 89 | `89-1.9` |
| H100 | 90 | `hopper-1.9` |
| B200, GB200 | 100 | `100-1.9` (experimental) |
| RTX 5090 | 120 | `120-1.9` (experimental) |

Base registry: `ghcr.io/huggingface/text-embeddings-inference`

## Model Type Decision Table

| Task | Model Examples | Endpoint | Use Case |
|---|---|---|---|
| Embeddings | Qwen3-Embedding-0.6B, gte-large-en-v1.5, nomic-embed-text-v1.5 | `POST /embed` | Semantic search, RAG |
| Re-ranking | BAAI/bge-reranker-large, gte-multilingual-reranker-base | `POST /rerank` | Improve retrieval quality |
| Classification | SamLowe/roberta-base-go_emotions | `POST /predict` | Sentiment, intent detection |

## Quick Start: Deploy Embedding Model

1. Choose model and image tag for your GPU:
```bash
model=Qwen/Qwen3-Embedding-0.6B
volume=$PWD/data
docker run --gpus all -p 8080:80 -v $volume:/data --pull always \
  ghcr.io/huggingface/text-embeddings-inference:1.9 \
  --model-id $model
```
2. Test health: `curl http://localhost:8080/health`
**Validate:** Returns 200 OK.

3. Test embedding:
```bash
curl http://localhost:8080/embed \
  -X POST \
  -d '{"inputs":"What is Deep Learning?"}' \
  -H 'Content-Type: application/json'
```
**Validate:** Returns JSON array of float vectors.

## Quick Start: Deploy Re-ranker

1. Launch re-ranker:
```bash
model=BAAI/bge-reranker-large
docker run --gpus all -p 8080:80 -v $PWD/data:/data --pull always \
  ghcr.io/huggingface/text-embeddings-inference:1.9 \
  --model-id $model
```
2. Test rerank:
```bash
curl http://localhost:8080/rerank \
  -X POST \
  -d '{"query":"What is Deep Learning?", "texts": ["Deep Learning is not...", "Deep learning is..."], "raw_scores": false}' \
  -H 'Content-Type: application/json'
```
**Validate:** Returns scored list, higher score = more relevant.

## Client Integration

### Python (huggingface_hub — recommended)
```python
from huggingface_hub import InferenceClient
client = InferenceClient()
embedding = client.feature_extraction(
    "What is deep learning?",
    model="http://localhost:8080/embed"
)
```

### Python (OpenAI SDK)
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8080/v1", api_key="-")
response = client.embeddings.create(
    model="text-embeddings-inference",
    input="What is Deep Learning?"
)
embedding = response.data[0].embedding
```

### Batch requests
```bash
curl http://localhost:8080/embed \
  -X POST \
  -d '{"inputs":["Today is a nice day", "I like you"]}' \
  -H 'Content-Type: application/json'
```

## Performance Tuning

| Parameter | Default | Tune When |
|---|---|---|
| `--max-batch-tokens` | 16384 | Increase for throughput, decrease if OOM |
| `--max-concurrent-requests` | 512 | Lower if server overloaded (returns 429) |
| `--max-client-batch-size` | 32 | Increase for bulk embedding jobs |
| `--tokenization-workers` | CPU cores | Adjust if tokenization is bottleneck |
| `--dtype float16` | auto | Force FP16 for GPU, FP32 for CPU |
| `--pooling` | auto-detect | Override: cls, mean, splade, last-token |

## Air-Gapped Deployment

For offline environments:
1. `git lfs install && git clone https://huggingface.co/<model-id>`
2. Mount local dir: `-v /path/to/models:/data`
3. Use local path: `--model-id /data/<model-name>`

## Monitoring

- Prometheus metrics: port 9000 (`/metrics`)
- OpenTelemetry: `--otlp-endpoint http://localhost:4317`
- Response headers: `x-compute-time`, `x-tokenization-time`, `x-queue-time`, `x-inference-time`

## Troubleshooting

```
Server won't start?
├─ OOM error?
│   ├─ Reduce --max-batch-tokens
│   ├─ Use smaller model (0.6B instead of 8B)
│   └─ Use --dtype float16
├─ Model not supported?
│   ├─ Check supported architectures: BERT, Qwen, GTE, Nomic, MPNet, ModernBERT, Gemma3
│   └─ Ensure model has safetensors weights
├─ CUDA error?
│   ├─ Check NVIDIA driver ≥ CUDA 12.2
│   ├─ Install NVIDIA Container Toolkit
│   └─ Use correct Docker image for your GPU (see Hardware table)
└─ Slow performance?
    ├─ Check --max-batch-tokens (increase for throughput)
    ├─ Verify Flash Attention enabled (Ampere+ default)
    └─ Monitor with Prometheus metrics
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Just use the default image" | MUST match Docker image to GPU architecture |
| "Any embedding model works" | Check supported model list — not all architectures supported |
| "CPU is fine for production" | GPU is 10-50x faster. CPU only for dev/testing |
| "Don't need to tune batch size" | Default 16384 tokens may OOM on small GPUs or waste capacity on large ones |

## References

- [TEI Official Docs](https://huggingface.co/docs/text-embeddings-inference) — Full documentation
- [Supported Models](https://huggingface.co/docs/text-embeddings-inference/supported_models) — Model compatibility
- [CLI Arguments](https://huggingface.co/docs/text-embeddings-inference/cli_arguments) — All config options
- [MTEB Leaderboard](https://huggingface.co/spaces/mteb/leaderboard) — Model quality benchmarks
