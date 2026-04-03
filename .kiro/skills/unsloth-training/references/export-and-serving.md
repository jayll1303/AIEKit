# Export & Serving with Unsloth

Chi tiết các phương pháp export model sau khi fine-tune với Unsloth: GGUF, merged model, HuggingFace Hub, vLLM, Ollama.

## Save LoRA Adapter Only

Cách nhẹ nhất — chỉ save adapter weights (~50-200 MB):

```python
# Save adapter locally
model.save_pretrained("./lora-adapter")
tokenizer.save_pretrained("./lora-adapter")

# Push adapter to HuggingFace Hub
model.push_to_hub("username/my-model-lora")
tokenizer.push_to_hub("username/my-model-lora")
```

**Khi nào dùng:** Muốn share adapter nhẹ, người dùng tự load base model + adapter. Tiết kiệm storage và bandwidth.

**Load lại adapter:**

```python
from unsloth import FastLanguageModel

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

from peft import PeftModel
model = PeftModel.from_pretrained(model, "./lora-adapter")
```

## Export to GGUF

Unsloth có built-in GGUF export — không cần cài llama.cpp riêng.

### save_pretrained_gguf()

```python
# Q4_K_M — balanced quality/size (recommended default)
model.save_pretrained_gguf(
    "./model-gguf",
    tokenizer,
    quantization_method="q4_k_m",
)

# Q8_0 — higher quality, larger file
model.save_pretrained_gguf(
    "./model-gguf-q8",
    tokenizer,
    quantization_method="q8_0",
)

# F16 — full precision GGUF (base for custom quantization)
model.save_pretrained_gguf(
    "./model-gguf-f16",
    tokenizer,
    quantization_method="f16",
)
```

### Quantization Methods

| Method | Bits | Quality | Size (7B) | Use Case |
|---|---|---|---|---|
| `q3_k_m` | 3-bit | Acceptable | ~3.3 GB | Extreme compression, edge devices |
| `q4_k_m` | 4-bit | Good | ~4.1 GB | Default choice, balanced |
| `q5_k_m` | 5-bit | Very good | ~4.8 GB | Better quality, slightly larger |
| `q6_k` | 6-bit | Very good | ~5.5 GB | High quality |
| `q8_0` | 8-bit | Excellent | ~7.2 GB | Near-lossless |
| `f16` | 16-bit | Lossless | ~13.5 GB | Base for further quantization |

### Push GGUF to HuggingFace Hub

```python
# Push single quantization
model.push_to_hub_gguf(
    "username/my-model-gguf",
    tokenizer,
    quantization_method="q4_k_m",
)

# Push multiple quantizations to same repo
for method in ["q4_k_m", "q5_k_m", "q8_0"]:
    model.push_to_hub_gguf(
        "username/my-model-gguf",
        tokenizer,
        quantization_method=method,
    )
```

**Validate:** Check Hub repo có file `.gguf` với size phù hợp. Nếu upload fails → check `huggingface-cli whoami` và repo permissions.

## Export Merged Model

Merge LoRA adapter vào base model → full standalone model.

### save_pretrained_merged()

```python
# Merged 16-bit — full precision, dùng cho vLLM/TGI serving
model.save_pretrained_merged(
    "./model-merged-16bit",
    tokenizer,
    save_method="merged_16bit",
)

# Merged 4-bit — quantized merged model
model.save_pretrained_merged(
    "./model-merged-4bit",
    tokenizer,
    save_method="merged_4bit",
)

# LoRA only — same as save_pretrained() nhưng qua merged API
model.save_pretrained_merged(
    "./model-lora-only",
    tokenizer,
    save_method="lora",
)
```

### Push Merged to HuggingFace Hub

```python
# Push merged 16-bit model
model.push_to_hub_merged(
    "username/my-model-merged",
    tokenizer,
    save_method="merged_16bit",
)
```

### Khi nào dùng method nào

| Save Method | Output Size (7B) | Use Case |
|---|---|---|
| `lora` (adapter only) | ~50-200 MB | Share adapter, tiết kiệm storage |
| `merged_4bit` | ~4-5 GB | Quick inference, limited disk |
| `merged_16bit` | ~14 GB | vLLM/TGI serving, highest quality |
| GGUF `q4_k_m` | ~4.1 GB | llama.cpp, Ollama, edge |
| GGUF `q8_0` | ~7.2 GB | High quality local inference |

## Export for vLLM Serving

vLLM cần merged model (không load LoRA adapter trực tiếp từ Unsloth).

### Workflow

```python
# 1. Save merged 16-bit model
model.save_pretrained_merged(
    "./model-for-vllm",
    tokenizer,
    save_method="merged_16bit",
)
```

```bash
# 2. Serve with vLLM
vllm serve ./model-for-vllm \
    --dtype auto \
    --max-model-len 2048 \
    --gpu-memory-utilization 0.9
```

### vLLM với AWQ Quantization

Nếu muốn serve quantized model qua vLLM:

```python
# 1. Save merged 16-bit
model.save_pretrained_merged("./model-merged", tokenizer, save_method="merged_16bit")
```

```bash
# 2. Quantize với AutoAWQ (→ xem model-quantization skill)
# 3. Serve quantized model
vllm serve ./model-awq --quantization awq --dtype auto
```

> Để cấu hình vLLM chi tiết (tensor parallelism, batching, etc.) → activate skill **vllm-tgi-inference**.

## Export for Ollama

Ollama dùng GGUF format. Workflow: export GGUF → tạo Modelfile → ollama create.

### Workflow

```python
# 1. Export GGUF
model.save_pretrained_gguf("./model-ollama", tokenizer, quantization_method="q4_k_m")
```

```dockerfile
# 2. Tạo Modelfile
# File: Modelfile
FROM ./model-ollama/unsloth.Q4_K_M.gguf

TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>
{{ .System }}<|eot_id|>{{ end }}<|start_header_id|>user<|end_header_id|>
{{ .Prompt }}<|eot_id|><|start_header_id|>assistant<|end_header_id|>
{{ .Response }}<|eot_id|>"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER stop "<|eot_id|>"
```

```bash
# 3. Create và run
ollama create my-model -f Modelfile
ollama run my-model "Hello, how are you?"
```

### Chat Templates cho Modelfile

| Model Family | Template Style |
|---|---|
| Llama 3.x | `<\|start_header_id\|>role<\|end_header_id\|>...<\|eot_id\|>` |
| Mistral | `[INST] ... [/INST]` |
| ChatML (Qwen, etc.) | `<\|im_start\|>role\n...<\|im_end\|>` |
| Gemma | `<start_of_turn>role\n...<end_of_turn>` |
| Phi-3 | `<\|user\|>\n...<\|end\|>\n<\|assistant\|>` |

**Validate:** `ollama run my-model "test"` trả về response hợp lý. Nếu output garbled → check TEMPLATE trong Modelfile khớp với model family.

## Export Checklist

```
Sau khi fine-tune xong, chọn export path:
│
├─ Dùng với Ollama?
│   └─ save_pretrained_gguf() → Modelfile → ollama create
│
├─ Dùng với vLLM/TGI?
│   └─ save_pretrained_merged(save_method="merged_16bit")
│      → vllm serve hoặc TGI Docker
│
├─ Share trên HuggingFace Hub?
│   ├─ Adapter only: push_to_hub() (~50-200 MB)
│   ├─ GGUF: push_to_hub_gguf() (multiple quant levels)
│   └─ Full model: push_to_hub_merged() (~14 GB for 7B)
│
├─ Dùng với llama.cpp trực tiếp?
│   └─ save_pretrained_gguf(quantization_method="q4_k_m")
│
└─ Tiếp tục training sau?
    └─ save_pretrained() (adapter only)
       → Load lại bằng PeftModel.from_pretrained()
```

## Troubleshooting Export

| Issue | Nguyên nhân | Fix |
|---|---|---|
| GGUF export OOM | Model quá lớn, cần dequantize | Dùng `merged_16bit` trước, rồi quantize riêng bằng llama.cpp |
| GGUF file corrupt | Disk space không đủ | Check `df -h`, cần ~1.5x model size free space |
| Ollama output garbled | Template sai | Verify TEMPLATE khớp model family (xem bảng trên) |
| vLLM không load được | Saved as 4-bit, vLLM cần 16-bit | Dùng `save_method="merged_16bit"` |
| Push to Hub timeout | File quá lớn | Dùng `huggingface-cli upload` với `--resume` flag |
| Merged model quality khác adapter | Normal — merged model không dùng 4-bit base | So sánh trên cùng precision; merged_16bit nên match adapter quality |
