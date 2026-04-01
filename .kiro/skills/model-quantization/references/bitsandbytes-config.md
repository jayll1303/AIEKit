# BitsAndBytes Configuration Patterns

Detailed patterns for runtime quantization with bitsandbytes, covering 4-bit (NF4, FP4), 8-bit, double quantization, compute dtype selection, and integration with HuggingFace Transformers.

## Installation

```bash
# Standard install (requires CUDA)
pip install bitsandbytes

# With uv
uv pip install bitsandbytes

# Verify CUDA detection
python -c "import bitsandbytes; print(bitsandbytes.cuda_setup)"
```

**Requirements**: CUDA 11.8+ and a compatible NVIDIA GPU. bitsandbytes does not require a pre-quantized model — it quantizes weights at load time.

> **See also**: [python-ml-deps](../python-ml-deps/SKILL.md) for resolving bitsandbytes CUDA installation issues

## 4-bit Quantization Patterns

### NF4 (Normal Float 4-bit) — Recommended

NF4 is information-theoretically optimal for normally distributed weights. This is the default and recommended 4-bit type.

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
import torch

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)
```

### FP4 (Float Point 4-bit)

FP4 uses standard floating-point representation. Slightly lower quality than NF4 for most models but may work better for non-normally distributed weights.

```python
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="fp4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=False,
)
```

### NF4 vs FP4 Comparison

| Aspect | NF4 | FP4 |
|---|---|---|
| Quality (typical LLMs) | Better | Slightly lower |
| Theory | Optimal for normal distributions | Standard float representation |
| Recommended for | Most LLMs, QLoRA | Edge cases, non-standard architectures |
| Default in Transformers | Yes | No |

## 8-bit Quantization

8-bit quantization provides higher quality with moderate VRAM savings. Uses LLM.int8() algorithm with mixed-precision decomposition.

### Basic 8-bit Loading

```python
bnb_config = BitsAndBytesConfig(
    load_in_8bit=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)
```

### 8-bit with Threshold Tuning

The `llm_int8_threshold` controls which features use FP16 (outliers) vs INT8. Lower threshold = more features in FP16 = better quality but more VRAM.

```python
bnb_config = BitsAndBytesConfig(
    load_in_8bit=True,
    llm_int8_threshold=6.0,          # Default: 6.0
    llm_int8_has_fp16_weight=False,   # Keep weights in INT8
    llm_int8_skip_modules=None,       # Skip specific modules from quantization
)
```

### 8-bit Config Options

| Parameter | Default | Description |
|---|---|---|
| `llm_int8_threshold` | 6.0 | Outlier threshold for mixed-precision decomposition |
| `llm_int8_has_fp16_weight` | False | Store weights in FP16 (uses more memory) |
| `llm_int8_skip_modules` | None | List of module names to skip (keep in FP16) |
| `llm_int8_enable_fp32_cpu_offload` | False | Offload some layers to CPU in FP32 |

## Double Quantization

Double quantization quantizes the quantization constants themselves, saving ~0.4 bits per parameter with negligible quality impact.

```python
# With double quantization (recommended for 4-bit)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,    # Saves ~0.4 bits/param
)

# Without double quantization
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=False,
)
```

### VRAM Impact of Double Quantization

| Model Size | 4-bit (no double) | 4-bit (double quant) | Savings |
|---|---|---|---|
| 7B params | ~4.8 GB | ~4.5 GB | ~0.3 GB |
| 13B params | ~8.5 GB | ~7.9 GB | ~0.6 GB |
| 70B params | ~40 GB | ~37 GB | ~3 GB |

## Compute Dtype Selection

The compute dtype determines the precision used for matrix multiplications during inference. This affects speed and numerical accuracy.

```python
import torch

# BFloat16 — recommended for Ampere+ GPUs (A100, RTX 3090, RTX 4090)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
)

# Float16 — for older GPUs (V100, RTX 2080, T4)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16,
)

# Float32 — highest precision, slowest (debugging only)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float32,
)
```

### Compute Dtype Comparison

| Dtype | GPU Support | Speed | Precision | Recommended For |
|---|---|---|---|---|
| `torch.bfloat16` | Ampere+ (SM 80+) | Fast | Good | Default for modern GPUs |
| `torch.float16` | All CUDA GPUs | Fast | Good | Older GPUs (V100, T4) |
| `torch.float32` | All GPUs | Slow | Best | Debugging, precision-sensitive tasks |

**How to check GPU compute capability**:
```python
import torch
major, minor = torch.cuda.get_device_capability()
print(f"Compute capability: {major}.{minor}")
# Ampere = 8.x, use bfloat16
# Turing = 7.5, use float16
# Volta = 7.0, use float16
```

## QLoRA Integration

bitsandbytes 4-bit is the foundation for QLoRA training. The quantized base model is frozen, and LoRA adapters are trained in higher precision.

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
import torch

# Load base model in 4-bit
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)

# Prepare for k-bit training
model = prepare_model_for_kbit_training(model)

# Add LoRA adapters
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Typical output: trainable params: 13M || all params: 8B || trainable%: 0.16%
```

## Skipping Modules from Quantization

Some modules (e.g., `lm_head`, layer norms) may benefit from staying in full precision:

```python
# 4-bit with specific modules skipped
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    llm_int8_skip_modules=["lm_head"],  # Keep lm_head in FP16
)
```

## VRAM Estimation

| Model Size | FP16 | 8-bit | 4-bit NF4 | 4-bit NF4 + double quant |
|---|---|---|---|---|
| 7B | ~14 GB | ~8.5 GB | ~4.8 GB | ~4.5 GB |
| 13B | ~26 GB | ~15 GB | ~8.5 GB | ~7.9 GB |
| 34B | ~68 GB | ~38 GB | ~20 GB | ~18.5 GB |
| 70B | ~140 GB | ~75 GB | ~40 GB | ~37 GB |

*Note: Actual VRAM includes KV cache, activations, and overhead. Add ~1-2 GB for inference, ~4-8 GB for training.*

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `bitsandbytes` import error | CUDA not detected | Verify `nvidia-smi` works, reinstall with matching CUDA |
| `CUDA_SETUP` warnings | Wrong CUDA path | Set `LD_LIBRARY_PATH` to include CUDA lib directory |
| NaN outputs with 4-bit | Compute dtype mismatch | Use `bfloat16` on Ampere+, `float16` on older GPUs |
| Slow inference with 8-bit | Too many outlier features | Increase `llm_int8_threshold` (e.g., 8.0) |
| OOM despite 4-bit loading | KV cache + activations | Reduce `max_length`, use `torch.cuda.empty_cache()` |
| Quality much worse than expected | Double quant on sensitive model | Try `bnb_4bit_use_double_quant=False` |
| Cannot save quantized model | bitsandbytes models are runtime-only | Use GPTQ/AWQ for persistent quantized models |
