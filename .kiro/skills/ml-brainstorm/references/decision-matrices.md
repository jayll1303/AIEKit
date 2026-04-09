# Decision Matrices — Aggregated Reference

> Summary tables cho ML/AI brainstorming. Mỗi table là bản rút gọn — xem full table trong skill gốc.
> **Load when:** Brainstorming bất kỳ ML/AI decision nào.

## 1. Training Strategy

### Method Selection

| Scenario | Method | VRAM (7B) | VRAM (70B) | Speed | Quality | Skill |
|----------|--------|-----------|------------|-------|---------|-------|
| Max quality, unlimited VRAM | Full fine-tune | ~28 GB | ~280 GB | Baseline | Best | hf-transformers-trainer |
| Balanced quality + VRAM | LoRA | ~18 GB | ~160 GB | ~1.2x | Very good | hf-transformers-trainer |
| Limited VRAM (≤8 GB) | QLoRA | ~6 GB | ~40 GB | ~1x | Good | hf-transformers-trainer |
| Single GPU, max speed | Unsloth QLoRA | ~3.5 GB | ~20 GB | ~2x | Good | unsloth-training |
| Multi-GPU distributed | DeepSpeed ZeRO-3 | Shared | Shared | Varies | Best | hf-transformers-trainer |

→ Full table: `../hf-transformers-trainer/SKILL.md` → Training Scenario Decision Table
→ Unsloth comparison: `../unsloth-training/SKILL.md` → Unsloth vs Standard HF Trainer

### Alignment Method Selection

| Goal | Method | Data Format | VRAM Overhead | Skill |
|------|--------|-------------|---------------|-------|
| Instruction following | SFT | (instruction, response) pairs | Baseline | hf-transformers-trainer, unsloth-training |
| Preference alignment | DPO | (prompt, chosen, rejected) triples | ~2x vs SFT | hf-transformers-trainer, unsloth-training |
| Reasoning improvement | GRPO | Prompts + reward function | ~2.5x vs SFT | hf-transformers-trainer, unsloth-training |

→ Full workflows: `../hf-transformers-trainer/SKILL.md` → TRL Workflow Overview

## 2. Quantization Method

| Goal | Method | Format | Size Reduction | Quality | Runtime | Skill |
|------|--------|--------|----------------|---------|---------|-------|
| Smallest size | GGUF Q4_K_M | GGUF | ~75% | Moderate loss | llama.cpp, Ollama | model-quantization |
| Balanced size + quality | GGUF Q5_K_M | GGUF | ~65% | Low loss | llama.cpp, Ollama | model-quantization |
| Near-lossless | GGUF Q8_0 | GGUF | ~50% | Minimal loss | llama.cpp, Ollama | model-quantization |
| GPU serving (fastest) | AWQ 4-bit | Safetensors | ~75% | Low-moderate | vLLM, TGI | model-quantization |
| GPU serving (broad compat) | GPTQ 4-bit | Safetensors | ~75% | Low-moderate | vLLM, TGI, Transformers | model-quantization |
| No pre-quant needed | bitsandbytes NF4 | In-memory | ~75% VRAM | Low loss | Transformers (runtime) | model-quantization |
| QLoRA training | bitsandbytes NF4 | In-memory | ~75% VRAM | Low loss | Training only | hf-transformers-trainer |
| Max throughput NVIDIA | TensorRT FP8 | TRT engine | ~50% | Minimal | TensorRT-LLM | tensorrt-llm |

→ Full table: `../model-quantization/SKILL.md` → Quantization Decision Table

## 3. Serving Engine

| Scenario | Engine | Key Advantage | Skill |
|----------|--------|---------------|-------|
| Single GPU, quick setup | vLLM | Fastest startup, pip install | vllm-tgi-inference |
| Docker preferred | TGI | Official HF container | vllm-tgi-inference |
| Multi-GPU tensor parallel | vLLM | Mature TP, auto sharding | vllm-tgi-inference |
| Structured output (JSON/regex) | SGLang | RadixAttention, constrained decoding | sglang-serving |
| Grammar-constrained generation | TGI | Built-in grammar flags | vllm-tgi-inference |
| GGUF local, CPU+GPU | llama.cpp | Max control, CPU fallback | llama-cpp-inference |
| Single-user, CLI-first | Ollama | One-command setup | ollama-local-llm |
| Max throughput NVIDIA | TensorRT-LLM | Kernel fusion, FP8/INT4 | tensorrt-llm |
| Multi-model ensemble | Triton | Multi-backend, batching | triton-deployment |
| Embedding models only | TEI | Optimized embedding API | text-embeddings-inference |

→ Full table: `../vllm-tgi-inference/SKILL.md` → Engine Decision Table
→ All alternatives: `../../docs/skill-interconnection-map.md` → Serving Alternatives

## 4. RAG vs Fine-tune

| Criteria | RAG | Fine-tune | Hybrid |
|----------|-----|-----------|--------|
| Knowledge update frequency | High (real-time) | Low (retrain needed) | Medium |
| Domain-specific behavior | Weak | Strong | Strong |
| Hallucination control | Better (grounded) | Depends on data | Best |
| VRAM requirement | Low (embedding model) | High (training) | Medium |
| Data requirement | Documents | Labeled pairs | Both |
| Latency | Higher (retrieval + gen) | Lower (gen only) | Higher |
| Cost | Lower (no training) | Higher (GPU hours) | Highest |
| Best for | FAQ, docs, search | Style, reasoning, format | Complex apps |

### When to choose

- **RAG** khi: knowledge thay đổi thường xuyên, không cần thay đổi model behavior, budget thấp
- **Fine-tune** khi: cần model behavior cụ thể (style, format, reasoning), data ổn định, có GPU budget
- **Hybrid** khi: cần cả domain knowledge + specific behavior, production app phức tạp

| RAG approach | Chains to |
|-------------|-----------|
| Embedding + vector DB | text-embeddings-rag |
| Embedding model serving | text-embeddings-inference |
| Generation backend | vllm-tgi-inference, sglang-serving |

## 5. Infrastructure

### GPU Selection

| VRAM | Fits (inference) | Fits (QLoRA training) | Typical GPU |
|------|------------------|-----------------------|-------------|
| 8 GB | 7B Q4 | 7B QLoRA | RTX 3070/4070 |
| 16 GB | 7B FP16, 13B Q4 | 7B LoRA, 13B QLoRA | RTX 4080, T4 |
| 24 GB | 13B FP16, 34B Q4 | 13B LoRA, 34B QLoRA | RTX 3090/4090 |
| 40 GB | 34B FP16, 70B Q4 | 34B LoRA | A100 40GB |
| 80 GB | 70B FP16 | 70B QLoRA | A100 80GB, H100 |
| 2×80 GB | 70B FP16 + large KV | 70B LoRA | 2× A100/H100 |

### Docker vs Bare Metal

| Criteria | Docker | Bare Metal |
|----------|--------|------------|
| Reproducibility | ✅ Excellent | ❌ Manual |
| GPU passthrough | Needs NVIDIA Container Toolkit | Native |
| Setup complexity | Medium (one-time) | Low |
| Production deploy | ✅ Standard | ❌ Fragile |
| Multi-service | ✅ docker-compose | Manual |
| Debugging | Harder (container logs) | Easier (direct access) |

→ Docker setup: `../docker-gpu-setup/SKILL.md`
→ CUDA deps: `../python-ml-deps/SKILL.md`

### Experiment Tracking

| Tool | Self-hosted | Cloud | Free tier | Skill |
|------|------------|-------|-----------|-------|
| MLflow | ✅ | ✅ (Databricks) | Unlimited (self) | experiment-tracking |
| W&B | ✅ | ✅ | Limited | experiment-tracking |
| TensorBoard | ✅ | ❌ | Unlimited | (built-in PyTorch) |

→ Setup: `../experiment-tracking/SKILL.md`

## 6. VRAM Quick Estimation

### Formula

```
Training VRAM ≈ model_params × bytes_per_param × multiplier

FP16 inference:  params × 2 bytes
FP16 training:   params × 2 bytes × 4 (weights + optimizer + gradients + activations)
QLoRA training:  params × 0.5 bytes + adapter_params × 2 bytes × 3
LoRA training:   params × 2 bytes + adapter_params × 2 bytes × 3
```

### Quick Reference

| Model | FP16 Inference | QLoRA Train | LoRA Train | Full Train |
|-------|---------------|-------------|------------|------------|
| 1B | ~2 GB | ~1.5 GB | ~4 GB | ~8 GB |
| 3B | ~6 GB | ~3 GB | ~10 GB | ~24 GB |
| 7B | ~14 GB | ~6 GB | ~18 GB | ~28 GB |
| 13B | ~26 GB | ~10 GB | ~32 GB | ~52 GB |
| 34B | ~68 GB | ~24 GB | ~80 GB | ~136 GB |
| 70B | ~140 GB | ~40 GB | ~160 GB | ~280 GB |

→ Detailed estimation: run `../scripts/vram_estimator.py`
→ VRAM optimization: `../hf-transformers-trainer/SKILL.md` → VRAM Optimization Checklist
