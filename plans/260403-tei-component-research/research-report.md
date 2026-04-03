# TEI (Text Embeddings Inference) — Research & Component Recommendation

## Tóm tắt TEI

[Text Embeddings Inference](https://huggingface.co/docs/text-embeddings-inference) là toolkit Rust-based của Hugging Face để deploy và serve embedding models, re-rankers, và sequence classification models.

### Key Features
- Docker-based deployment (GPU + CPU)
- Dynamic batching (token-based)
- Flash Attention, Candle, cuBLASLt optimizations
- OpenAI-compatible API (`/v1/embeddings`)
- Prometheus metrics + OpenTelemetry tracing
- Safetensors weight loading
- 3 backends: Candle (Rust), ORT (ONNX), Python (PyTorch)

### API Endpoints
| Endpoint | Mục đích |
|---|---|
| `POST /embed` | Generate embeddings |
| `POST /rerank` | Re-rank documents |
| `POST /predict` | Sequence classification |
| `POST /v1/embeddings` | OpenAI-compatible |
| `GET /health` | Health check |
| `GET /metrics` | Prometheus metrics |

### Supported Models (top picks)
- Qwen3-Embedding (0.6B, 4B, 8B)
- Alibaba GTE series
- intfloat/multilingual-e5-large-instruct
- nomic-ai/nomic-embed-text-v1.5
- BAAI/bge-reranker-large (re-ranking)
- sentence-transformers/all-mpnet-base-v2

### Docker Images (v1.9)
| Hardware | Image |
|---|---|
| CPU | `ghcr.io/huggingface/text-embeddings-inference:cpu-1.9` |
| A100/A30 | `ghcr.io/huggingface/text-embeddings-inference:1.9` |
| A10/A40 | `ghcr.io/huggingface/text-embeddings-inference:86-1.9` |
| RTX 4000 | `ghcr.io/huggingface/text-embeddings-inference:89-1.9` |
| H100 | `ghcr.io/huggingface/text-embeddings-inference:hopper-1.9` |

### CLI Config quan trọng
- `--model-id`: HF model ID hoặc local path
- `--pooling`: cls / mean / splade / last-token
- `--max-batch-tokens`: Token budget (default 16384)
- `--max-concurrent-requests`: Concurrency limit (default 512)
- `--dtype`: float16 / float32
- `--hf-token`: Private model access
- `--auto-truncate`: Auto truncate long inputs

---

## Recommendation: Tạo SKILL

### Tại sao Skill, không phải Steering/Hook/Power?

| Component | Phù hợp? | Lý do |
|---|---|---|
| Steering | ❌ | TEI không phải convention/rule cần luôn trong context. Nó là tool deployment knowledge. |
| Hook | ❌ | TEI không trigger theo IDE events. Không có file pattern hay tool use nào liên quan. |
| Power | ❌ (overkill) | TEI không có MCP server riêng. Không cần bundle MCP + steering + hooks. |
| **Skill** | ✅ | TEI là portable instruction package — agent cần biết HOW to deploy/configure/troubleshoot khi developer hỏi. On-demand loading phù hợp nhất. |

### Skill sẽ cover
1. Docker deployment (GPU/CPU image selection)
2. Model selection (embedding vs reranker vs classification)
3. API usage (cURL, Python SDK, OpenAI SDK)
4. Performance tuning (batch tokens, concurrency, pooling)
5. Troubleshooting (OOM, model not supported, CUDA errors)
6. Integration patterns (RAG pipeline, semantic search)
