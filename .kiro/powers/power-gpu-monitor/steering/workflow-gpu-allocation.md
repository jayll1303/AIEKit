---
inclusion: auto
name: gpu-allocation
description: Multi-GPU allocation strategies and memory budgeting. Use when planning multi-GPU training, tensor parallelism, pipeline parallelism, or optimizing GPU resource sharing.
---

# GPU Allocation & Multi-GPU Strategies

## Single GPU Budgeting

```
Total VRAM budget:
├─ Model weights: 60-80% (inference) / 30-40% (training)
├─ KV cache / Activations: 15-30%
├─ CUDA overhead: 5-10%
└─ Safety buffer: 5-10%

Ví dụ RTX 4090 (24GB):
├─ Model: ~16GB → max INT8 16B model hoặc Q4 30B model
├─ KV cache: ~5GB
├─ Overhead: ~2GB
└─ Buffer: ~1GB
```

## Multi-GPU: Khi nào cần?

| Scenario | Single GPU đủ? | Strategy |
|----------|----------------|----------|
| Inference 7-8B FP16 | 24GB GPU: Yes | Single GPU |
| Inference 70B FP16 | No (140GB) | Tensor Parallel 2-4 GPUs |
| Inference 70B Q4 | 48GB GPU: Maybe | Single A100 80GB hoặc TP=2 |
| Training 7B LoRA | 24GB: Yes | Single GPU |
| Training 7B Full FT | No (80GB+) | DeepSpeed ZeRO-3 |
| Training 70B QLoRA | 48GB: Maybe | Single A100 80GB |

## Tensor Parallelism (TP) — Inference

Chia model weights across GPUs. Mỗi GPU giữ 1/N model.

```
VRAM per GPU ≈ total_model_vram / tp_size + kv_cache + overhead

Ví dụ Llama-70B FP16 trên 4× A100 40GB:
  Model: 140GB / 4 = 35GB per GPU
  KV cache: ~3GB per GPU
  Overhead: ~2GB
  Total: ~40GB per GPU → vừa đủ A100 40GB
```

Config:
- vLLM: `--tensor-parallel-size 4`
- TGI: `--num-shard 4`
- SGLang: `--tp 4`

Quy tắc: TP size phải là power of 2 (1, 2, 4, 8) và ≤ num_attention_heads.

## Pipeline Parallelism (PP) — Training

Chia model layers across GPUs. GPU 0 = layers 0-15, GPU 1 = layers 16-31...

```
VRAM per GPU ≈ layers_per_gpu × vram_per_layer + optimizer_states + activations
```

Dùng khi: model quá lớn cho TP alone, hoặc GPUs connected qua slow interconnect.

## DeepSpeed ZeRO — Training

| ZeRO Stage | Shards gì | VRAM savings | Khi nào dùng |
|------------|-----------|--------------|--------------|
| Stage 1 | Optimizer states | ~4x less optimizer VRAM | 2-4 GPUs, model fits in VRAM |
| Stage 2 | + Gradients | ~8x less | 4-8 GPUs |
| Stage 3 | + Parameters | Near-linear scaling | Model không fit single GPU |
| Stage 3 + Offload | + CPU offload | Max savings | Limited GPU VRAM |

## GPU Sharing: Multiple Processes

```
get_gpu_info → check current usage
get_top_processes → identify GPU consumers

Sharing rules:
├─ Training + Inference trên cùng GPU: KHÔNG recommend
│   (Training allocates max VRAM, inference sẽ OOM)
├─ Multiple inference servers: OK nếu tổng VRAM < 90% total
│   (vLLM: --gpu-memory-utilization 0.4 cho mỗi server)
└─ Inference + monitoring: OK (monitoring dùng ít VRAM)
```

## Hardware Decision Table

| Budget | GPU | VRAM | Best for |
|--------|-----|------|----------|
| Consumer | RTX 4090 | 24GB | 7-8B inference, QLoRA training |
| Mid-range | A10G | 24GB | Same as 4090, cloud-friendly |
| Professional | A100 40GB | 40GB | 13-30B inference, LoRA 70B |
| High-end | A100 80GB | 80GB | 70B inference, QLoRA 70B |
| Top | H100 80GB | 80GB | Fastest, FP8 support, 70B+ |

## Monitoring During Training/Inference

```
Periodic check (mỗi 5-10 phút khi training):
  get_gpu_info → VRAM usage trend
  ├─ VRAM tăng dần → Memory leak, check code
  ├─ VRAM stable → OK
  └─ VRAM spike → Batch size quá lớn cho một số samples

  get_gpu_info → Temperature
  ├─ <75°C → Optimal
  ├─ 75-85°C → Normal under load
  └─ >85°C → Risk throttling, check cooling
```
