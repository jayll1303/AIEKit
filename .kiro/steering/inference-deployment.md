---
inclusion: auto
name: inference-deployment
description: Conventions cho model serving và deployment. Match khi user hỏi về deploy, serve, inference, vLLM, TGI, Triton, API endpoint, production, Docker, hoặc containerize model.
---

# Inference & Deployment Conventions

Khi deploy hoặc serve ML models, tuân thủ các conventions sau.

## Chọn đúng serving engine

Tham khảo #[[file:docs/skill-interconnection-map.md]] section "Serving Alternatives".

| Cần gì? | Dùng skill nào |
|---------|---------------|
| LLM + OpenAI-compatible API | vllm-tgi-inference |
| Structured output, prefix caching | sglang-serving |
| Max NVIDIA throughput, FP8 | tensorrt-llm |
| Local LLM, single-user, CLI | ollama-local-llm |
| GGUF inference, CPU+GPU, max control | llama-cpp-inference |
| Multi-model ensemble, custom pipeline | triton-deployment |
| Embedding models | text-embeddings-inference |
| Offline/edge speech | sherpa-onnx |

## Pre-deployment Checklist — HARD GATE

KHÔNG deploy mà chưa check:

1. **Model format**: Model đã ở đúng format cho engine? (ONNX cho Triton, safetensors cho vLLM...)
2. **VRAM budget**: Model fit trong GPU target? Cần quantize trước? (→ model-quantization)
3. **Dependencies**: Container có đủ CUDA/cuDNN? (→ docker-gpu-setup)
4. **Health check**: Endpoint `/health` hoặc `/v1/models` trả về OK
5. **Load test**: Thử concurrent requests trước khi claim production-ready

## Containerization Pattern

Khi containerize model serving:

```
1. Chọn NGC base image phù hợp (→ docker-gpu-setup)
2. Install dependencies với uv (→ python-ml-deps)
3. Copy model weights vào container hoặc mount volume
4. Expose port + health check
5. docker-compose với GPU passthrough
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Cứ dùng vLLM cho mọi thứ" | Check decision table — Triton tốt hơn cho multi-model, TGI cho grammar |
| "Default config là đủ cho production" | PHẢI tune gpu-memory-utilization, max-num-seqs, batch size |
| "Deploy xong là xong" | PHẢI test health check + load test |
| "Không cần quantize, GPU đủ VRAM" | Quantize giảm latency + cost, luôn cân nhắc |
