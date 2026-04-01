# VRAM Optimization

Detailed VRAM estimation formulas, DeepSpeed ZeRO stage configurations, FSDP setup, and memory profiling techniques for training LLMs on local GPU hardware.

## VRAM Estimation Formulas

### Model Weight Memory

```
Model weights (bytes) = num_parameters × bytes_per_param

FP32: bytes_per_param = 4
FP16/BF16: bytes_per_param = 2
INT8: bytes_per_param = 1
INT4 (NF4): bytes_per_param = 0.5
```

### Full Fine-Tuning VRAM

```
Total VRAM ≈ Model weights + Optimizer states + Gradients + Activations

Model weights (FP16):     P × 2 bytes
Optimizer states (AdamW):  P × 8 bytes  (FP32 copy + momentum + variance)
Gradients (FP16):          P × 2 bytes
Activations:               Variable (depends on batch size, seq length)

Rule of thumb: Full fine-tune ≈ P × 12-16 bytes
  7B model: ~84-112 GB → needs multi-GPU or ZeRO
  With gradient checkpointing: reduces activation memory by ~60%
```

### LoRA VRAM

```
Total VRAM ≈ Base model weights + LoRA params + Optimizer (LoRA only) + Activations

Base model (FP16):         P × 2 bytes
LoRA params:               ~0.1-0.5% of P (negligible)
Optimizer (LoRA only):     LoRA_params × 8 bytes (small)
Activations:               Reduced (fewer backward passes)

Rule of thumb: LoRA ≈ P × 2.5 bytes
  7B model: ~17.5 GB
```

### QLoRA VRAM

```
Total VRAM ≈ Quantized base + LoRA params + Optimizer (LoRA only) + Activations

Base model (4-bit NF4):    P × 0.5 bytes
Double quantization:       Saves ~0.4 bits/param additional
LoRA params (FP16):        ~0.1-0.5% of P
Optimizer (LoRA only):     LoRA_params × 8 bytes

Rule of thumb: QLoRA ≈ P × 0.85 bytes
  7B model: ~6 GB
  13B model: ~10 GB
  70B model: ~40 GB
```

### VRAM Summary Table

| Model | FP16 Inference | LoRA Training | QLoRA Training | Full Fine-tune |
|---|---|---|---|---|
| 7B | ~14 GB | ~18 GB | ~6 GB | ~84 GB |
| 13B | ~26 GB | ~32 GB | ~10 GB | ~156 GB |
| 34B | ~68 GB | ~85 GB | ~24 GB | ~408 GB |
| 70B | ~140 GB | ~175 GB | ~40 GB | ~840 GB |

*Full fine-tune includes AdamW optimizer states. Actual values vary with batch size and sequence length.*

## DeepSpeed ZeRO Stages

### ZeRO Stage Overview

| Stage | What's Sharded | VRAM Savings | Communication Overhead |
|---|---|---|---|
| ZeRO-0 | Nothing (DDP) | None | Low |
| ZeRO-1 | Optimizer states | ~4× reduction | Low |
| ZeRO-2 | Optimizer + Gradients | ~8× reduction | Medium |
| ZeRO-3 | Optimizer + Gradients + Parameters | ~N× reduction (N=GPUs) | High |

### ZeRO-2 Config (Recommended for LoRA multi-GPU)

```json
{
    "bf16": {"enabled": true},
    "zero_optimization": {
        "stage": 2,
        "offload_optimizer": {
            "device": "none"
        },
        "allgather_partitions": true,
        "allgather_bucket_size": 2e8,
        "overlap_comm": true,
        "reduce_scatter": true,
        "reduce_bucket_size": 2e8,
        "contiguous_gradients": true
    },
    "gradient_accumulation_steps": "auto",
    "gradient_clipping": "auto",
    "train_batch_size": "auto",
    "train_micro_batch_size_per_gpu": "auto"
}
```

### ZeRO-3 Config (For 70B+ full fine-tune)

```json
{
    "bf16": {"enabled": true},
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "cpu",
            "pin_memory": true
        },
        "offload_param": {
            "device": "cpu",
            "pin_memory": true
        },
        "overlap_comm": true,
        "contiguous_gradients": true,
        "sub_group_size": 1e9,
        "reduce_bucket_size": "auto",
        "stage3_prefetch_bucket_size": "auto",
        "stage3_param_persistence_threshold": "auto",
        "stage3_max_live_parameters": 1e9,
        "stage3_max_reuse_distance": 1e9,
        "stage3_gather_16bit_weights_on_model_save": true
    },
    "gradient_accumulation_steps": "auto",
    "gradient_clipping": "auto",
    "train_batch_size": "auto",
    "train_micro_batch_size_per_gpu": "auto"
}
```

### Using DeepSpeed with Trainer

```python
from transformers import TrainingArguments

# Save the JSON config above as ds_config_zero2.json
args = TrainingArguments(
    output_dir="./output",
    deepspeed="ds_config_zero2.json",
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    bf16=True,
    num_train_epochs=3,
)
```

```bash
# Launch with DeepSpeed (4 GPUs)
deepspeed --num_gpus=4 train.py --deepspeed ds_config_zero2.json

# Or with torchrun
torchrun --nproc_per_node=4 train.py --deepspeed ds_config_zero2.json
```

### ZeRO-3 + QLoRA (70B on 4× A100 40GB)

```python
# Combine QLoRA with ZeRO-3 for 70B models
args = TrainingArguments(
    output_dir="./output",
    deepspeed="ds_config_zero3.json",
    per_device_train_batch_size=1,
    gradient_accumulation_steps=16,
    bf16=True,
    gradient_checkpointing=True,
)
# With 4× A100 40GB: ~40 GB per GPU → fits 70B QLoRA
```

## FSDP (Fully Sharded Data Parallel)

### Basic FSDP Config

```python
from transformers import TrainingArguments

args = TrainingArguments(
    output_dir="./output",
    fsdp="full_shard auto_wrap",
    fsdp_config={
        "fsdp_transformer_layer_cls_to_wrap": "LlamaDecoderLayer",
        "backward_prefetch": "backward_pre",
        "forward_prefetch": True,
        "use_orig_params": True,
    },
    bf16=True,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    gradient_checkpointing=True,
)
```

```bash
# Launch with torchrun
torchrun --nproc_per_node=4 train.py
```

### FSDP vs DeepSpeed

| Aspect | FSDP | DeepSpeed ZeRO |
|---|---|---|
| Integration | Native PyTorch | Third-party library |
| CPU offloading | Limited | Full support (ZeRO-3 + offload) |
| Ease of use | Simpler config | More config options |
| QLoRA support | Good | Good (with recent versions) |
| Best for | PyTorch-native workflows | Maximum flexibility, 70B+ models |

## Memory Profiling

### Quick VRAM Check

```python
import torch

def print_gpu_memory():
    """Print current GPU memory usage."""
    if torch.cuda.is_available():
        allocated = torch.cuda.memory_allocated() / 1e9
        reserved = torch.cuda.memory_reserved() / 1e9
        max_allocated = torch.cuda.max_memory_allocated() / 1e9
        print(f"Allocated: {allocated:.2f} GB")
        print(f"Reserved:  {reserved:.2f} GB")
        print(f"Peak:      {max_allocated:.2f} GB")

# Call after model loading
print_gpu_memory()
```

### Detailed Memory Summary

```python
# After a forward pass
print(torch.cuda.memory_summary(abbreviated=True))
```

### Monitor During Training

```bash
# Watch GPU usage every second
nvidia-smi -l 1

# Or use watch for cleaner output
watch -n 1 nvidia-smi

# Log to file
nvidia-smi --query-gpu=timestamp,memory.used,memory.total,utilization.gpu \
  --format=csv -l 5 > gpu_log.csv
```

### PyTorch Memory Snapshot (Advanced)

```python
import torch

# Start recording memory history
torch.cuda.memory._record_memory_history()

# Run your training step
output = model(**batch)
loss = output.loss
loss.backward()

# Save snapshot for visualization
torch.cuda.memory._dump_snapshot("memory_snapshot.pickle")
torch.cuda.memory._record_memory_history(enabled=None)

# Visualize at: https://pytorch.org/memory_viz
```

## Optimization Techniques Summary

| Technique | VRAM Savings | Speed Impact | When to Use |
|---|---|---|---|
| Gradient checkpointing | ~30-40% | ~20% slower | Always for large models |
| BF16 mixed precision | ~50% vs FP32 | Faster | Ampere+ GPUs (A100, RTX 3090+) |
| FP16 mixed precision | ~50% vs FP32 | Faster | Older GPUs (V100, RTX 2080) |
| Gradient accumulation | Reduces per-step memory | Neutral | When batch size = 1 is still OOM |
| QLoRA (4-bit base) | ~75% vs FP16 | Slightly slower | Limited VRAM, single GPU |
| DeepSpeed ZeRO-2 | ~8× per GPU | Slight overhead | Multi-GPU LoRA training |
| DeepSpeed ZeRO-3 | ~N× per GPU | More overhead | 70B+ models, multi-GPU |
| CPU offloading | Fits larger models | Much slower | When GPU VRAM is insufficient |
| Packing (SFTTrainer) | Better utilization | Faster | Short training examples |
| Reduce sequence length | Linear reduction | Faster | When full context isn't needed |
