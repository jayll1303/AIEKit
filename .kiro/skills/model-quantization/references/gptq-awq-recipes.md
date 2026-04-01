# GPTQ & AWQ Quantization Recipes

Detailed patterns for weight-only quantization using AutoGPTQ and AutoAWQ, including calibration dataset preparation, quantization configuration, model saving, and Transformers integration.

## Calibration Dataset Preparation

Both GPTQ and AWQ require a calibration dataset to measure weight importance. Quality of calibration data directly impacts quantized model quality.

### General Guidelines

- Use **128-256 samples** (more samples = better quality but slower quantization)
- Sequence length should match model's typical usage (2048-4096 tokens)
- Use **diverse, representative text** from your target domain
- Avoid repetitive or low-quality text

### Preparing Calibration Data from Datasets Library

```python
from datasets import load_dataset
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# Option 1: WikiText (general purpose)
dataset = load_dataset("wikitext", "wikitext-2-raw-v1", split="train")
calibration_texts = [
    text for text in dataset["text"]
    if len(text.strip()) > 100  # Filter short/empty lines
][:256]

# Option 2: C4 (diverse web text)
dataset = load_dataset("allenai/c4", "en", split="train", streaming=True)
calibration_texts = []
for sample in dataset:
    if len(sample["text"].strip()) > 200:
        calibration_texts.append(sample["text"])
    if len(calibration_texts) >= 256:
        break

# Option 3: Domain-specific (e.g., code)
dataset = load_dataset("codeparrot/github-code", split="train", streaming=True)
calibration_texts = []
for sample in dataset:
    if len(sample["code"].strip()) > 200:
        calibration_texts.append(sample["code"])
    if len(calibration_texts) >= 256:
        break
```

### Tokenizing for AutoGPTQ

```python
# AutoGPTQ expects list of tokenized dicts
calibration_dataset = [
    tokenizer(
        text,
        return_tensors="pt",
        max_length=2048,
        truncation=True,
        padding=False,
    )
    for text in calibration_texts
]
```

## AutoGPTQ Recipes

### Installation

```bash
# With CUDA support
pip install auto-gptq
# Or with specific CUDA version
pip install auto-gptq --extra-index-url https://huggingface.github.io/autogptq-index/whl/cu121/
```

### 4-bit Quantization (Standard)

```python
from transformers import AutoTokenizer
from auto_gptq import AutoGPTQForCausalLM, BaseQuantizeConfig

model_id = "meta-llama/Llama-3.1-8B-Instruct"
quant_output = "./llama-3.1-8b-gptq-4bit"

quantize_config = BaseQuantizeConfig(
    bits=4,                  # 4-bit quantization
    group_size=128,          # Quantize in groups of 128 weights
    damp_percent=0.1,        # Dampening factor for Hessian
    desc_act=True,           # Activation order (better quality, slower)
    sym=False,               # Asymmetric quantization (better quality)
    model_file_base_name="model",
)

tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoGPTQForCausalLM.from_pretrained(model_id, quantize_config)

# Quantize
model.quantize(calibration_dataset)

# Save
model.save_quantized(quant_output)
tokenizer.save_pretrained(quant_output)
```

### 8-bit Quantization (Higher Quality)

```python
quantize_config = BaseQuantizeConfig(
    bits=8,
    group_size=128,
    damp_percent=0.1,
    desc_act=True,
    sym=True,                # Symmetric works well for 8-bit
)
```

### Advanced Config Options

| Parameter | Default | Description |
|---|---|---|
| `bits` | 4 | Quantization bits (2, 3, 4, 8) |
| `group_size` | 128 | Weight group size (32, 64, 128, -1 for per-channel) |
| `damp_percent` | 0.1 | Hessian dampening (0.01-0.1) |
| `desc_act` | False | Activation-ordered quantization (better quality, slower inference) |
| `sym` | True | Symmetric (True) vs asymmetric (False) quantization |
| `true_sequential` | True | Quantize layers sequentially (more accurate) |
| `batch_size` | 1 | Calibration batch size |

### Group Size Impact

| Group Size | Quality | Model Size | Speed |
|---|---|---|---|
| 32 | Best | Largest | Slowest |
| 64 | Very good | Large | Moderate |
| **128** | **Good (default)** | **Moderate** | **Fast** |
| -1 (per-channel) | Lower | Smallest | Fastest |

## AutoAWQ Recipes

### Installation

```bash
pip install autoawq
# For specific CUDA version
pip install autoawq --extra-index-url https://huggingface.github.io/autoawq-index/whl/cu121/
```

### 4-bit Quantization (Standard)

```python
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

model_id = "meta-llama/Llama-3.1-8B-Instruct"
quant_output = "./llama-3.1-8b-awq-4bit"

model = AutoAWQForCausalLM.from_pretrained(model_id)
tokenizer = AutoTokenizer.from_pretrained(model_id)

quant_config = {
    "zero_point": True,       # Use zero-point quantization
    "q_group_size": 128,      # Group size
    "w_bit": 4,               # 4-bit weights
    "version": "GEMM",        # GEMM for GPU, GEMV for CPU
}

model.quantize(tokenizer, quant_config=quant_config)
model.save_quantized(quant_output)
tokenizer.save_pretrained(quant_output)
```

### AWQ Config Options

| Parameter | Default | Description |
|---|---|---|
| `w_bit` | 4 | Weight bits (4 is standard) |
| `q_group_size` | 128 | Quantization group size |
| `zero_point` | True | Zero-point quantization |
| `version` | "GEMM" | Kernel version: GEMM (GPU batch), GEMV (CPU/single) |

### AWQ Version Selection

| Version | Best For | Notes |
|---|---|---|
| `GEMM` | GPU inference, batched requests | Default, best throughput on GPU |
| `GEMV` | CPU inference, single requests | Better for sequential generation |

## Loading Quantized Models in Transformers

### GPTQ Models

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, GPTQConfig

# Basic loading
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-GPTQ",
    device_map="auto",
)

# With explicit GPTQ config
gptq_config = GPTQConfig(
    bits=4,
    disable_exllama=False,    # Use ExLlama kernel for faster inference
)
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-GPTQ",
    quantization_config=gptq_config,
    device_map="auto",
)
```

### AWQ Models

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, AwqConfig

# Basic loading
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-AWQ",
    device_map="auto",
)

# With explicit AWQ config
awq_config = AwqConfig(
    bits=4,
    fuse_max_seq_len=2048,    # Fused attention max sequence length
    do_fuse=True,             # Fuse attention layers for speed
)
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-AWQ",
    quantization_config=awq_config,
    device_map="auto",
)
```

## Uploading Quantized Models to Hub

```python
from huggingface_hub import HfApi

api = HfApi()

# Create repo
api.create_repo("your-username/Llama-3.1-8B-GPTQ-4bit", exist_ok=True)

# Upload quantized model
api.upload_folder(
    folder_path="./llama-3.1-8b-gptq-4bit",
    repo_id="your-username/Llama-3.1-8B-GPTQ-4bit",
)
```

## GPTQ vs AWQ Comparison

| Aspect | GPTQ | AWQ |
|---|---|---|
| Quantization speed | Slower (Hessian computation) | Faster (activation-aware scaling) |
| Quality at 4-bit | Very good | Very good (slightly better on some models) |
| Inference speed | Fast (ExLlama kernel) | Fast (GEMM kernel) |
| vLLM support | Yes | Yes |
| TGI support | Yes | Yes |
| Calibration data | Required (user-provided) | Required (built-in or user-provided) |
| Group size flexibility | 32, 64, 128, per-channel | 128 (standard) |
| 8-bit support | Yes | No (4-bit only) |
| Activation ordering | Optional (`desc_act`) | Built-in |

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| CUDA OOM during quantization | Model too large for single GPU | Use `device_map="auto"` or quantize on CPU (slower) |
| Poor quality after GPTQ | Bad calibration data or too few samples | Use 256+ diverse samples, enable `desc_act=True` |
| Slow GPTQ inference | ExLlama kernel not enabled | Set `disable_exllama=False` in GPTQConfig |
| AWQ `version` error | Wrong kernel version for hardware | Use `GEMM` for GPU, `GEMV` for CPU |
| Model loads but generates poorly | Tokenizer mismatch | Ensure tokenizer is saved alongside quantized model |
| `auto_gptq` import error | CUDA version mismatch | Install matching CUDA version: `pip install auto-gptq --extra-index-url ...` |
