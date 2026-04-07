---
name: unsloth-training
description: "Fine-tune LLMs 2x faster with 70% less VRAM using Unsloth. Use when using FastLanguageModel, Unsloth SFT/DPO/GRPO, 2x faster fine-tuning, or exporting to GGUF/vLLM."
---

# Unsloth LLM Fine-Tuning

Patterns for fine-tuning LLMs with Unsloth — a drop-in accelerator that makes training 2x faster and uses 70% less VRAM via custom Triton kernels. Covers FastLanguageModel API, SFT/DPO/GRPO via TRL+Unsloth, 4-bit QLoRA, model export (GGUF, merged, vLLM), and Unsloth-specific optimizations.

## Scope

This skill handles:
- Loading and configuring models with Unsloth `FastLanguageModel` API
- 4-bit QLoRA fine-tuning with Unsloth-optimized Triton kernels (2x speed, 70% less VRAM)
- SFT, DPO, GRPO training via TRL trainers integrated with Unsloth
- Model export: GGUF quantization (`save_pretrained_gguf`), merged 16bit/4bit (`save_pretrained_merged`), vLLM-ready
- Unsloth-specific features: RoPE scaling, longer context windows, gradient checkpointing offload

Does NOT handle:
- Standard HuggingFace Trainer without Unsloth optimizations (→ hf-transformers-trainer)
- Standalone model quantization with llama.cpp, GPTQ, AWQ (→ model-quantization)
- Serving fine-tuned models via vLLM or TGI (→ vllm-tgi-inference)
- Downloading datasets or models from HuggingFace Hub (→ hf-hub-datasets)
- Installing CUDA-aware Python dependencies (→ python-ml-deps)

## When to Use

- Fine-tuning a language model with 2x speed and 70% less VRAM on a single GPU
- Applying QLoRA with Unsloth-optimized Triton kernels
- Running SFT, DPO, or GRPO training via TRL + Unsloth
- Training reasoning models (GRPO) with as little as 5 GB VRAM
- Exporting fine-tuned models to GGUF, merged 16bit, or vLLM-ready format
- Model is in the Supported Models list below

## Unsloth vs Standard HF Trainer

| Criteria | Unsloth | Standard HF Trainer |
|---|---|---|
| Speed | 2x faster (Triton kernels) | Baseline |
| VRAM | 70% less | Baseline |
| Accuracy | No loss vs standard | Baseline |
| API | `FastLanguageModel` wrapper | `AutoModelForCausalLM` + PEFT |
| QLoRA | Built-in, optimized | Manual BitsAndBytesConfig + PEFT |
| Export | Built-in GGUF, merged, vLLM | Manual llama.cpp conversion |
| Multi-GPU | Limited (single GPU focus) | DeepSpeed, FSDP |
| Custom architectures | Supported models only | Any HF model |

**Khi nào dùng Unsloth:** Single GPU, muốn tốc độ + tiết kiệm VRAM, model nằm trong supported list.
**Khi nào dùng standard:** Multi-GPU, custom architecture, hoặc model chưa được Unsloth hỗ trợ.

## Supported Models

| Family | Models | Notes |
|---|---|---|
| Llama | Llama 3.3, 3.2, 3.1, 3, 2 | Full support, recommended |
| Mistral | Mistral v0.3, Mistral Small, Mistral NeMo | Full support |
| Qwen | Qwen 2.5, QwQ | Full support |
| Gemma | Gemma 2, 3 | Full support |
| Phi | Phi-4, Phi-3, Phi-3.5 | Full support |
| DeepSeek | DeepSeek-R1, V3, V2 | Distilled versions |
| Others | TinyLlama, CodeLlama, Yi, Zephyr | Community tested |

## Install

```bash
# Requires CUDA 11.8+ and PyTorch 2.1+
pip install unsloth

# Hoặc từ source (latest features)
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
```

**Validate:** `python -c "from unsloth import FastLanguageModel; print('OK')"` — nếu lỗi import → check CUDA version với `nvcc --version` và PyTorch CUDA với `python -c "import torch; print(torch.version.cuda)"`.

## Quick Start: SFT

⚠️ **HARD GATE:** Verify model nằm trong Supported Models table trước khi bắt đầu. Nếu model không được hỗ trợ → dùng hf-transformers-trainer thay thế.

```python
from unsloth import FastLanguageModel

# 1. Load model — Unsloth tự động apply 4-bit quantization + Triton kernels
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# 2. Add LoRA adapters — Unsloth optimized
model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    lora_alpha=16,
    lora_dropout=0,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    use_gradient_checkpointing="unsloth",  # 70% less VRAM
)

# 3. Train with TRL SFTTrainer
from trl import SFTTrainer, SFTConfig

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    args=SFTConfig(
        output_dir="./output",
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        num_train_epochs=3,
        learning_rate=2e-4,
        bf16=True,
        max_seq_length=2048,
        packing=True,
    ),
)
trainer.train()
```

**Validate:** `trainer.train()` completes without OOM. Training speed should show ~2x improvement vs standard. Nếu OOM → giảm `max_seq_length` hoặc `per_device_train_batch_size`.

## Quick Start: GRPO (Reasoning Models, ~5 GB VRAM)

```python
from unsloth import FastLanguageModel
from trl import GRPOTrainer, GRPOConfig

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=1024,
    load_in_4bit=True,
)
model = FastLanguageModel.get_peft_model(model, r=16, lora_alpha=16,
    target_modules=["q_proj","k_proj","v_proj","o_proj",
                    "gate_proj","up_proj","down_proj"],
    use_gradient_checkpointing="unsloth",
)

def reward_fn(completions, **kwargs):
    return [1.0 if "<answer>" in c else 0.0 for c in completions]

trainer = GRPOTrainer(
    model=model,
    args=GRPOConfig(
        output_dir="./output-grpo",
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        num_generations=4,
        max_completion_length=512,
        learning_rate=5e-6,
        bf16=True,
    ),
    train_dataset=prompt_dataset,
    reward_funcs=reward_fn,
)
trainer.train()
```

**Validate:** `reward/mean` tăng dần qua training steps. Nếu reward flat → kiểm tra reward function logic.

## Export Patterns

### Save LoRA Adapter

```python
model.save_pretrained("./lora-adapter")
tokenizer.save_pretrained("./lora-adapter")
```

### Export to GGUF

```python
# Quantize và export trực tiếp — không cần llama.cpp
model.save_pretrained_gguf("./model-gguf", tokenizer, quantization_method="q4_k_m")
# Options: q4_k_m, q5_k_m, q8_0, f16, q3_k_m
```

### Export Merged Model (16-bit)

```python
model.save_pretrained_merged("./model-merged", tokenizer, save_method="merged_16bit")
# Options: merged_16bit, merged_4bit, lora
```

### Push to HuggingFace Hub

```python
model.push_to_hub_gguf("username/model-gguf", tokenizer, quantization_method="q4_k_m")
model.push_to_hub_merged("username/model-merged", tokenizer, save_method="merged_16bit")
```

> For detailed export workflows, vLLM serving, and Ollama integration, see [Export & Serving reference](references/export-and-serving.md)

## VRAM Comparison: Unsloth vs Standard

| Model | Standard QLoRA | Unsloth QLoRA | Savings | Max Seq Length (Unsloth) |
|---|---|---|---|---|
| 7B-8B | ~6 GB | ~3.5 GB | ~42% | 4096+ |
| 13B | ~10 GB | ~5.5 GB | ~45% | 4096+ |
| 34B | ~24 GB | ~12 GB | ~50% | 2048+ |
| 70B | ~40 GB | ~20 GB | ~50% | 2048+ |

*Unsloth savings come from optimized Triton kernels + `use_gradient_checkpointing="unsloth"`.*

## Troubleshooting

```
Unsloth issues?
├─ Import error: "No module named 'unsloth'"
│   ├─ Check CUDA version: nvcc --version (cần ≥11.8)
│   ├─ Check PyTorch CUDA: python -c "import torch; print(torch.version.cuda)"
│   └─ Reinstall: pip install unsloth --upgrade
│
├─ "Model not supported" error
│   ├─ Check Supported Models table ở trên
│   ├─ Thử dùng pre-quantized: "unsloth/{model}-bnb-4bit"
│   └─ Fallback → hf-transformers-trainer cho unsupported models
│
├─ OOM even with Unsloth
│   ├─ Giảm max_seq_length (2048 → 1024)
│   ├─ Giảm per_device_train_batch_size (2 → 1)
│   ├─ Verify use_gradient_checkpointing="unsloth" (không phải True)
│   └─ Giảm r (16 → 8) nếu vẫn OOM
│
├─ GGUF export fails
│   ├─ Check disk space (GGUF cần ~model_size * 1.5x temp)
│   ├─ Thử quantization_method khác (q4_k_m → q8_0)
│   └─ Fallback: save merged → dùng model-quantization skill
│
└─ Training speed not 2x faster
    ├─ Verify đang dùng FastLanguageModel (không phải AutoModelForCausalLM)
    ├─ Check use_gradient_checkpointing="unsloth" (string, không phải bool)
    └─ Ensure model là pre-quantized "bnb-4bit" variant
```

## Anti-Patterns

| ID | Agent nghĩ | Thực tế | Detection | Fix |
|---|---|---|---|---|
| AP-01 | "Dùng `use_gradient_checkpointing=True`" | Phải dùng `="unsloth"` (string). `True` dùng standard HF checkpointing, mất lợi thế VRAM | Grep code cho `use_gradient_checkpointing=True` (bool thay vì string) | Thay bằng `use_gradient_checkpointing="unsloth"`. Verify VRAM giảm so với `True` |
| AP-02 | "Load model bằng AutoModelForCausalLM rồi wrap" | Phải dùng `FastLanguageModel.from_pretrained()` từ đầu. Unsloth cần control loading để apply Triton kernels | Check import: nếu dùng `AutoModelForCausalLM` thay vì `FastLanguageModel` → sai | Thay toàn bộ model loading bằng `FastLanguageModel.from_pretrained()` |
| AP-03 | "Unsloth hỗ trợ multi-GPU training" | Unsloth tối ưu cho single GPU | Check: `device_map` hoặc DeepSpeed config → Unsloth không hỗ trợ | Multi-GPU → dùng hf-transformers-trainer với DeepSpeed/FSDP |
| AP-04 | "Export GGUF cần cài llama.cpp riêng" | Unsloth có built-in `save_pretrained_gguf()` | Check: nếu đang cài llama.cpp chỉ để export → không cần | Dùng `model.save_pretrained_gguf()`. Chỉ cần llama.cpp cho custom quantization |
| AP-05 | "lora_dropout > 0 tốt hơn cho regularization" | Unsloth khuyến nghị `lora_dropout=0` vì Triton kernels optimize cho case này | Check LoRA config: `lora_dropout > 0` → có thể giảm speed | Set `lora_dropout=0`. Nếu cần regularization → giảm epochs hoặc tăng weight_decay |
| AP-06 | "Train xong, report best seed luôn" | Cherry-picking best seed là p-hacking. Cần mean±std over 3+ seeds | Check: chỉ report 1 seed? Không có std? | Chạy 3+ seeds, report mean±std. Dùng self-check protocol (→ experiment-tracking) |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Model không được Unsloth hỗ trợ, cần standard Trainer | hf-transformers-trainer | Covers standard HF Trainer, PEFT, multi-GPU training |
| Cần quantize model bằng llama.cpp, GPTQ, AWQ (không qua Unsloth) | model-quantization | Handles standalone quantization workflows |
| Cần serve model đã fine-tune qua vLLM hoặc TGI | vllm-tgi-inference | Covers vLLM serve, TGI Docker, tensor parallelism |
| Cần download model hoặc dataset từ HuggingFace Hub | hf-hub-datasets | Handles snapshot_download, load_dataset, private repos |
| Cần log training metrics vào MLflow hoặc W&B | experiment-tracking | Handles MLflow/W&B setup, metric logging |

## References

- [SFT/DPO/GRPO Workflows](references/sft-dpo-grpo-workflows.md) — Detailed training workflows for SFT, DPO, GRPO with Unsloth; dataset preparation, chat templates, hyperparameter recommendations
  **Load when:** setting up SFT with chat templates, DPO with preference data, GRPO with custom reward functions, or tuning hyperparameters per model size
- [Export & Serving](references/export-and-serving.md) — GGUF export options, merged model saving, HuggingFace Hub push, vLLM/Ollama integration
  **Load when:** exporting fine-tuned model to GGUF, merging LoRA adapters, pushing to Hub, or preparing model for Ollama/vLLM serving
