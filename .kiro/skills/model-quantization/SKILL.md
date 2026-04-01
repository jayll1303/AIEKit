---
name: model-quantization
description: "Quantize large language models to reduce VRAM and accelerate inference with GGUF, GPTQ, AWQ, bitsandbytes. Use when converting models to GGUF format, applying GPTQ/AWQ weight-only quantization, loading models in 4-bit or 8-bit with BitsAndBytesConfig, or comparing quantization methods for VRAM budget."
---

# Model Quantization

Workflows and configuration patterns for quantizing LLMs on local GPU hardware using GGUF (llama.cpp), GPTQ (AutoGPTQ), AWQ (AutoAWQ), and bitsandbytes runtime quantization. Covers method selection, conversion workflows, quality-size tradeoffs, and diagnostic checklists.

## Scope

This skill handles:
- Converting HuggingFace models to GGUF format with llama.cpp (convert_hf_to_gguf.py, llama-quantize)
- Applying GPTQ and AWQ weight-only quantization with calibration datasets
- Loading models in 4-bit or 8-bit precision at runtime with BitsAndBytesConfig
- Selecting quantization method based on VRAM budget, quality requirements, and serving target
- Diagnosing quantization errors, quality degradation, and calibration issues

Does NOT handle:
- Installing CUDA-aware dependencies like AutoGPTQ, AutoAWQ, bitsandbytes (→ python-ml-deps)
- Downloading source models or uploading quantized models to HuggingFace Hub (→ hf-hub-datasets)
- Serving quantized models with vLLM or TGI inference engines (→ vllm-tgi-inference)
- Fine-tuning with QLoRA or PEFT adapters (→ hf-transformers-trainer)

## When to Use

- Converting a HuggingFace model to GGUF format for llama.cpp or Ollama
- Applying GPTQ quantization with a calibration dataset for weight-only compression
- Applying AWQ quantization for activation-aware weight quantization
- Loading a model in 4-bit or 8-bit precision at runtime with bitsandbytes
- Choosing between quantization methods based on VRAM budget and quality requirements
- Comparing perplexity, throughput, and VRAM usage across quantization methods
- Diagnosing quantization errors, quality degradation, or calibration issues
- Preparing quantized models for serving with vLLM or TGI

## Quantization Decision Table

Pick the right method based on your goal:

| Goal | Method | Format | Quality Impact | Size Reduction | Best For |
|---|---|---|---|---|---|
| Smallest model size | GGUF Q4_K_M | GGUF | Moderate loss | ~75% smaller | llama.cpp, Ollama, edge devices |
| Best quality at reduced size | GGUF Q8_0 / GPTQ 8-bit | GGUF / Safetensors | Minimal loss | ~50% smaller | Quality-sensitive applications |
| Fastest inference (GPU) | AWQ 4-bit | Safetensors | Low-moderate loss | ~75% smaller | vLLM, TGI serving |
| High throughput serving | GPTQ 4-bit | Safetensors | Low-moderate loss | ~75% smaller | vLLM, TGI, Transformers |
| Runtime-only (no pre-quant) | bitsandbytes 4-bit NF4 | In-memory | Low loss | ~75% VRAM saved | QLoRA training, quick inference |
| Runtime 8-bit | bitsandbytes 8-bit | In-memory | Very low loss | ~50% VRAM saved | Fine-tuning, prototyping |
| Balanced size + quality | GGUF Q5_K_M | GGUF | Low loss | ~65% smaller | General-purpose local inference |

**Rules of thumb**:
- For **llama.cpp / Ollama**: Use GGUF. Start with Q4_K_M, upgrade to Q5_K_M or Q8_0 if quality matters.
- For **vLLM / TGI serving**: Use AWQ or GPTQ 4-bit. AWQ generally has better inference speed.
- For **QLoRA training**: Use bitsandbytes 4-bit NF4 — no pre-quantization step needed.
- For **quick prototyping**: Use bitsandbytes — loads directly from HuggingFace with one config change.

## GGUF Conversion (llama.cpp)

Convert HuggingFace models to GGUF format for use with llama.cpp, Ollama, and other GGUF-compatible runtimes.

⚠️ **HARD GATE:** Do NOT quantize before estimating target VRAM budget and selecting method from the decision table above.

### Quick Workflow

```bash
# 1. Clone llama.cpp and build
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j$(nproc)

# 2. Download model from HuggingFace
pip install huggingface-hub
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct --local-dir ./models/llama-3.1-8b

# 3. Convert to GGUF (FP16 base)
python convert_hf_to_gguf.py ./models/llama-3.1-8b --outfile ./models/llama-3.1-8b.f16.gguf --outtype f16

# 4. Quantize to desired level
./llama-quantize ./models/llama-3.1-8b.f16.gguf ./models/llama-3.1-8b.Q4_K_M.gguf Q4_K_M
```

**Validate:** After step 3, verify the FP16 GGUF file exists and is non-empty (`ls -lh *.f16.gguf`). If not → check model architecture support in llama.cpp with `python convert_hf_to_gguf.py --help`.

**Validate:** After step 4, verify the quantized GGUF file size is smaller than the FP16 file (`ls -lh *.gguf`). If not → confirm the quantization level is valid with `./llama-quantize --help`.

### Quantization Levels

| Level | Bits | Quality | Size (7B model) | Use Case |
|---|---|---|---|---|
| Q4_K_M | 4-bit (mixed) | Good | ~4.1 GB | Default choice, balanced |
| Q5_K_M | 5-bit (mixed) | Very good | ~4.8 GB | Better quality, slightly larger |
| Q8_0 | 8-bit | Excellent | ~7.2 GB | Near-lossless, larger |
| Q3_K_M | 3-bit (mixed) | Acceptable | ~3.3 GB | Extreme compression |
| Q6_K | 6-bit | Very good | ~5.5 GB | High quality, moderate size |
| F16 | 16-bit | Lossless | ~13.5 GB | Base for further quantization |

### Importance Matrix (imatrix)

For better quality at low bit levels, use an importance matrix:

```bash
# Generate importance matrix from calibration data
./llama-imatrix -m ./models/llama-3.1-8b.f16.gguf \
  -f calibration-data.txt \
  -o ./models/llama-3.1-8b.imatrix

# Quantize with importance matrix
./llama-quantize --imatrix ./models/llama-3.1-8b.imatrix \
  ./models/llama-3.1-8b.f16.gguf \
  ./models/llama-3.1-8b.IQ4_XS.gguf IQ4_XS
```

> For detailed conversion steps, imatrix generation, and troubleshooting, see [GGUF Conversion reference](references/gguf-conversion.md)

## GPTQ/AWQ Workflow

Weight-only quantization methods that require a calibration dataset. Produce Safetensors files compatible with Transformers, vLLM, and TGI.

### AutoGPTQ Quick Start

```python
from transformers import AutoTokenizer
from auto_gptq import AutoGPTQForCausalLM, BaseQuantizeConfig

model_id = "meta-llama/Llama-3.1-8B-Instruct"
quant_output = "./llama-3.1-8b-gptq-4bit"

# Quantization config
quantize_config = BaseQuantizeConfig(
    bits=4,
    group_size=128,
    damp_percent=0.1,
    desc_act=True,          # Activation order — better quality, slower
    sym=False,               # Asymmetric quantization
)

tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoGPTQForCausalLM.from_pretrained(model_id, quantize_config)

# Calibration dataset (list of tokenized examples)
calibration_dataset = [
    tokenizer(text, return_tensors="pt", max_length=2048, truncation=True)
    for text in calibration_texts[:128]  # 128 samples typical
]

# Quantize and save
model.quantize(calibration_dataset)
model.save_quantized(quant_output)
tokenizer.save_pretrained(quant_output)
```

**Validate:** After quantization completes, verify the output directory contains `model.safetensors` and `quantize_config.json` (`ls quant_output/`). If not → check calibration dataset has ≥128 samples and max_length ≥ 2048.

### AutoAWQ Quick Start

```python
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

model_id = "meta-llama/Llama-3.1-8B-Instruct"
quant_output = "./llama-3.1-8b-awq-4bit"

model = AutoAWQForCausalLM.from_pretrained(model_id)
tokenizer = AutoTokenizer.from_pretrained(model_id)

# AWQ quantization config
quant_config = {
    "zero_point": True,
    "q_group_size": 128,
    "w_bit": 4,
    "version": "GEMM",      # GEMM for GPU inference, GEMV for CPU
}

# Quantize (uses built-in calibration)
model.quantize(tokenizer, quant_config=quant_config)

# Save quantized model
model.save_quantized(quant_output)
tokenizer.save_pretrained(quant_output)
```

**Validate:** After saving, verify the output directory contains `model.safetensors` and `quant_config.json`. If not → check VRAM is sufficient for the full model during quantization.

### Loading Quantized Models in Transformers

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

# GPTQ model
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-GPTQ",
    device_map="auto",
)

# AWQ model
model = AutoModelForCausalLM.from_pretrained(
    "TheBloke/Llama-2-7B-AWQ",
    device_map="auto",
)
```

> For detailed calibration dataset preparation, advanced configs, and Transformers integration, see [GPTQ/AWQ Recipes reference](references/gptq-awq-recipes.md)

## BitsAndBytes Runtime Quantization

Runtime quantization with bitsandbytes — no pre-quantization step needed. Load any HuggingFace model in reduced precision directly.

### 4-bit Loading (NF4 — recommended for QLoRA)

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
import torch

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",           # NF4 (default) or "fp4"
    bnb_4bit_compute_dtype=torch.bfloat16, # Compute in bf16 for speed
    bnb_4bit_use_double_quant=True,       # Double quantization saves ~0.4 bits/param
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
```

### 8-bit Loading

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

### When to Use Which

| Config | VRAM (7B model) | Quality | Use Case |
|---|---|---|---|
| 4-bit NF4 + double quant | ~4.5 GB | Good | QLoRA training, inference on low VRAM |
| 4-bit FP4 | ~4.5 GB | Slightly lower | Alternative to NF4 |
| 8-bit | ~8.5 GB | Very good | Fine-tuning, high-quality inference |
| FP16 (no quant) | ~14 GB | Baseline | Full precision reference |

> For detailed BitsAndBytesConfig options, compute dtype selection, and advanced patterns, see [BitsAndBytes Config reference](references/bitsandbytes-config.md)

## Diagnostic Checklist

When encountering quantization errors or quality degradation:

```
Quality degradation after quantization?
├─ Calibration dataset issues (GPTQ/AWQ)
│   ├─ Too few samples? → Use 128-256 samples minimum
│   ├─ Domain mismatch? → Use data similar to your target task
│   ├─ Too short sequences? → Use max_length ≥ 2048
│   └─ Low diversity? → Mix multiple data sources
│
├─ Group size tuning
│   ├─ group_size=128 (default) → Good balance
│   ├─ group_size=64 → Better quality, larger model
│   └─ group_size=32 → Best quality, significantly larger
│
├─ Outlier-aware options
│   ├─ GPTQ: Enable desc_act=True for activation-ordered quantization
│   ├─ AWQ: Already activation-aware by design
│   └─ bitsandbytes: Try 8-bit instead of 4-bit for sensitive layers
│
├─ Quantization level too aggressive?
│   ├─ GGUF: Move from Q4_K_M → Q5_K_M → Q8_0
│   ├─ GPTQ/AWQ: Try 8-bit instead of 4-bit
│   └─ bitsandbytes: Switch from 4-bit to 8-bit
│
├─ Model architecture issues
│   ├─ Some architectures quantize poorly at 4-bit (e.g., small models <3B)
│   └─ MoE models may need per-expert calibration
│
└─ GGUF-specific issues
    ├─ convert_hf_to_gguf.py fails? → Check model architecture support in llama.cpp
    ├─ Poor quality at Q4? → Use importance matrix (imatrix)
    └─ Tokenizer mismatch? → Verify tokenizer config in GGUF metadata
```

### Quick Validation

After quantizing, always validate quality:

```python
# Quick perplexity check
from lm_eval import evaluator

results = evaluator.simple_evaluate(
    model="hf",
    model_args=f"pretrained={quant_model_path}",
    tasks=["wikitext"],
    batch_size=4,
)
print(f"Perplexity: {results['results']['wikitext_word_perplexity']:.2f}")
```

```bash
# GGUF perplexity check with llama.cpp
./llama-perplexity -m ./models/llama-3.1-8b.Q4_K_M.gguf \
  -f wikitext-2-raw/wiki.test.raw
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Model nhỏ, Q4 chắc đủ tốt — skip VRAM estimation" | Luôn ước lượng VRAM budget trước khi chọn method. Model <3B quantize Q4 thường bị quality degradation nghiêm trọng. Dùng decision table. |
| "Calibration dataset không quan trọng, dùng random text" | Calibration dataset ảnh hưởng trực tiếp đến quality. Dùng ≥128 samples, domain-matched, max_length ≥ 2048. |
| "GGUF và GPTQ giống nhau, chọn cái nào cũng được" | GGUF dùng cho llama.cpp/Ollama (CPU+GPU), GPTQ/AWQ dùng cho vLLM/TGI (GPU only). Chọn sai format = không tương thích runtime. |
| "Quantize xong là xong, không cần validate" | Luôn chạy perplexity check sau quantization. Quality degradation >10% so với FP16 = cần tăng bit level hoặc dùng imatrix. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to download source model or upload quantized model to HuggingFace Hub | hf-hub-datasets | Handles snapshot_download, push_to_hub, and private repo access |
| Need to serve quantized model with vLLM or TGI | vllm-tgi-inference | Covers vllm serve, TGI Docker, tensor parallelism for quantized models |
| Need to install AutoGPTQ, AutoAWQ, bitsandbytes, or llama-cpp-python | python-ml-deps | Resolves CUDA-aware dependency installation and version conflicts |
| Need to fine-tune with QLoRA after quantization | hf-transformers-trainer | Covers SFTTrainer, LoRA/QLoRA config, PEFT adapters |

## References

- [GGUF Conversion](references/gguf-conversion.md) — Detailed llama.cpp conversion workflow, quantization levels, importance matrix generation, and troubleshooting
  **Load when:** converting a HuggingFace model to GGUF format or troubleshooting convert_hf_to_gguf.py errors
- [GPTQ/AWQ Recipes](references/gptq-awq-recipes.md) — Calibration dataset preparation, advanced quantization configs, model saving, and Transformers integration
  **Load when:** applying GPTQ or AWQ quantization with custom calibration datasets or advanced config tuning
- [BitsAndBytes Config](references/bitsandbytes-config.md) — BitsAndBytesConfig patterns for 4-bit (NF4, FP4), 8-bit, double quantization, and compute dtype selection
  **Load when:** loading models with BitsAndBytesConfig or choosing between NF4, FP4, and 8-bit runtime quantization
- [Quality Benchmarks](references/quality-benchmarks.md) — Benchmark comparisons across quantization methods for Llama, Mistral, and Qwen model families
  **Load when:** comparing perplexity, throughput, or VRAM usage across quantization methods for a specific model family