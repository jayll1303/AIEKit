---
inclusion: auto
name: inference-deployment
description: Conventions for model serving and deployment. Match when user asks about deploy, serve, inference, vLLM, TGI, Triton, API endpoint, production, Docker, or containerize model.
---

# Inference & Deployment Conventions

When deploying or serving ML models, follow these conventions.

## Choose the Right Serving Engine

See #[[file:docs/skill-interconnection-map.md]] section "Serving Alternatives".

| Need | Skill |
|------|-------|
| LLM + OpenAI-compatible API | vllm-tgi-inference |
| Structured output, prefix caching | sglang-serving |
| Max NVIDIA throughput, FP8 | tensorrt-llm |
| Local LLM, single-user, CLI | ollama-local-llm |
| GGUF inference, CPU+GPU, max control | llama-cpp-inference |
| Multi-model ensemble, custom pipeline | triton-deployment |
| Embedding models | text-embeddings-inference |
| Offline/edge speech | sherpa-onnx |

## Pre-deployment Checklist — HARD GATE

Do NOT deploy without checking:

1. **Model format**: Is the model in the correct format for the engine? (ONNX for Triton, safetensors for vLLM...)
2. **VRAM budget**: Does the model fit in the target GPU? Need to quantize first? (→ model-quantization)
3. **Dependencies**: Does the container have the correct CUDA/cuDNN? (→ docker-gpu-setup)
4. **Health check**: Does `/health` or `/v1/models` endpoint return OK?
5. **Load test**: Try concurrent requests before claiming production-ready

## Containerization Pattern

When containerizing model serving:

```
1. Choose appropriate NGC base image (→ docker-gpu-setup)
2. Install dependencies with uv (→ python-ml-deps)
3. Copy model weights into container or mount as volume
4. Expose port + health check
5. docker-compose with GPU passthrough
```

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Just use vLLM for everything" | Check the decision table — Triton is better for multi-model, TGI for grammar |
| "Default config is fine for production" | MUST tune gpu-memory-utilization, max-num-seqs, batch size |
| "Deploy is done once it starts" | MUST test health check + run load test |
| "No need to quantize, GPU has enough VRAM" | Quantization reduces latency + cost — always consider it |
