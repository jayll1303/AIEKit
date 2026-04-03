# VRAM Estimation Guide

## Quick Formula

### Inference VRAM

```
VRAM_inference ≈ model_params × bytes_per_param + KV_cache + overhead

bytes_per_param:
  FP32 = 4 bytes
  FP16/BF16 = 2 bytes
  INT8 = 1 byte
  INT4 (GPTQ/AWQ) = 0.5 bytes
  GGUF Q4_K_M ≈ 0.55 bytes (mixed quantization)

KV_cache ≈ 2 × num_layers × hidden_size × 2 × seq_len × batch_size × bytes_per_param
overhead ≈ 10-20% of model size
```

### Training VRAM

```
VRAM_training ≈ model_weights + optimizer_states + gradients + activations

Full fine-tune (AdamW):
  weights: params × 2 bytes (BF16)
  optimizer: params × 8 bytes (2 FP32 moments)
  gradients: params × 2 bytes
  activations: varies (dominant for long sequences)
  Total ≈ params × 12 bytes + activations

LoRA (r=16):
  base weights: params × 2 bytes (frozen, no optimizer)
  LoRA weights: ~0.5-2% of params × 12 bytes
  activations: same as full fine-tune
  Total ≈ params × 2 bytes + small overhead

QLoRA (4-bit base + LoRA):
  base weights: params × 0.5 bytes (NF4)
  LoRA weights: ~0.5-2% of params × 12 bytes
  activations: reduced with gradient checkpointing
  Total ≈ params × 0.5 bytes + small overhead
```

## Quick Reference Table: Inference

| Model | Params | FP16 | INT8 | INT4/GGUF Q4 | Min GPU |
|-------|--------|------|------|--------------|---------|
| Llama-3.2-1B | 1.2B | 2.4 GB | 1.2 GB | 0.7 GB | Any |
| Llama-3.2-3B | 3.2B | 6.4 GB | 3.2 GB | 1.8 GB | RTX 3060 |
| Llama-3.1-8B | 8B | 16 GB | 8 GB | 4.5 GB | RTX 4090 |
| Qwen2.5-14B | 14B | 28 GB | 14 GB | 8 GB | A100 40GB |
| Llama-3.1-70B | 70B | 140 GB | 70 GB | 40 GB | 2×A100 80GB |
| Llama-3.1-405B | 405B | 810 GB | 405 GB | 230 GB | 8×A100 80GB |

*Giá trị trên chưa bao gồm KV cache. Thêm 1-10GB tùy seq_len và batch_size.*

## Quick Reference Table: Training

| Model | Full FT (BF16) | LoRA (r=16) | QLoRA (4-bit) |
|-------|----------------|-------------|---------------|
| 1-3B | 12-36 GB | 8-12 GB | 4-8 GB |
| 7-8B | 80-100 GB | 16-24 GB | 8-12 GB |
| 13B | 150+ GB | 24-32 GB | 12-16 GB |
| 70B | Không khả thi single GPU | 80-160 GB | 40-48 GB |

*Batch size = 1, seq_len = 2048. Tăng batch/seq → tăng VRAM tuyến tính.*

## VRAM Optimization Strategies

```
VRAM không đủ?
├─ Inference:
│   ├─ Quantize model (→ model-quantization)
│   ├─ Reduce max_model_len / max_seq_len
│   ├─ Reduce gpu-memory-utilization (vLLM: --gpu-memory-utilization 0.8)
│   └─ Use tensor parallelism (multi-GPU)
│
├─ Training:
│   ├─ Switch to QLoRA (→ hf-transformers-trainer hoặc unsloth-training)
│   ├─ Enable gradient checkpointing
│   ├─ Reduce batch_size (use gradient accumulation thay thế)
│   ├─ Reduce max_seq_length
│   ├─ Use Unsloth (70% less VRAM → unsloth-training)
│   └─ Use DeepSpeed ZeRO Stage 2/3 (multi-GPU)
│
└─ Cả hai:
    ├─ Kill other GPU processes (get_top_processes → identify)
    ├─ Use smaller model variant
    └─ Rent cloud GPU (A100/H100)
```

## Practical Decision Flow

```
get_gpu_info → available_vram = total - used

available_vram >= model_vram_needed × 1.2?
├─ Yes → Proceed with current config
├─ Close (within 20%) → Reduce batch/seq, enable optimizations
└─ No (need >50% more) → Quantize or use smaller model
```

Luôn nhân VRAM estimate × 1.2 để có buffer cho CUDA overhead và fragmentation.
