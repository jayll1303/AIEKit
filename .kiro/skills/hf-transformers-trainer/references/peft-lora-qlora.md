# PEFT LoRA/QLoRA Configuration

Detailed LoRA and QLoRA configuration templates per model size, recommended hyperparameters, target module selection, and adapter merging workflows.

## LoRA Config Templates by Model Size

### 7B-8B Models (Llama 3.1 8B, Mistral 7B, Qwen2 7B)

```python
from peft import LoraConfig, TaskType

lora_config_7b = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    bias="none",
)
# Trainable params: ~13.6M (0.17% of 8B)
# Additional VRAM: ~4 GB over base model
```

### 13B Models (Llama 2 13B, CodeLlama 13B)

```python
lora_config_13b = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=32,                        # Higher rank for larger model capacity
    lora_alpha=64,
    lora_dropout=0.05,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    bias="none",
)
# Trainable params: ~52M (0.4% of 13B)
# Additional VRAM: ~6 GB over base model
```

### 70B Models (Llama 3.1 70B, Qwen2 72B)

```python
lora_config_70b = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,                        # Keep rank lower to manage VRAM
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        # Skip MLP layers for 70B to save VRAM
    ],
    bias="none",
)
# Trainable params: ~27M (0.04% of 70B)
# Additional VRAM: ~2 GB over base model
# Note: 70B requires multi-GPU even with QLoRA
```

## QLoRA Templates by Model Size

### 7B QLoRA (Fits on single 8 GB GPU)

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
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
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    bias="none", task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_config)
# Total VRAM: ~6 GB
```

### 13B QLoRA (Fits on single 16 GB GPU)

```python
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-13b-hf",
    quantization_config=bnb_config,
    device_map="auto",
)
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=32, lora_alpha=64, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    bias="none", task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_config)
# Total VRAM: ~10 GB
```

### 70B QLoRA (Requires multi-GPU or 48+ GB GPU)

```python
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-70B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",  # Spreads across available GPUs
)
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    bias="none", task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_config)
# Total VRAM: ~40 GB (spread across GPUs)
```

## Hyperparameter Recommendations

| Parameter | 7B | 13B | 70B | Notes |
|---|---|---|---|---|
| `r` (rank) | 16 | 16-32 | 8-16 | Higher = more capacity, more VRAM |
| `lora_alpha` | 32 | 32-64 | 16-32 | Typically 2× rank |
| `lora_dropout` | 0.05 | 0.05 | 0.05 | 0.0 for inference-only adapters |
| Learning rate | 2e-4 | 1e-4 | 1e-4 | Lower for larger models |
| Batch size (QLoRA) | 4 | 2-4 | 1-2 | Constrained by VRAM |
| Grad accumulation | 4 | 4-8 | 8-16 | Compensate for small batch |
| Epochs | 1-3 | 1-3 | 1 | Fewer epochs for larger models |

## Target Module Selection

### Finding Target Modules

```python
from transformers import AutoModelForCausalLM

model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# List all named modules
for name, module in model.named_modules():
    if "Linear" in type(module).__name__:
        print(f"{name}: {type(module).__name__} ({module.in_features} → {module.out_features})")
```

### Common Target Modules by Architecture

| Architecture | Attention Modules | MLP Modules | All Linear |
|---|---|---|---|
| Llama / Llama 2/3 | q_proj, k_proj, v_proj, o_proj | gate_proj, up_proj, down_proj | All 7 |
| Mistral | q_proj, k_proj, v_proj, o_proj | gate_proj, up_proj, down_proj | All 7 |
| Qwen2 | q_proj, k_proj, v_proj, o_proj | gate_proj, up_proj, down_proj | All 7 |
| Phi-3 | qkv_proj, o_proj | gate_up_proj, down_proj | All 4 |
| Gemma | q_proj, k_proj, v_proj, o_proj | gate_proj, up_proj, down_proj | All 7 |

**Guidance**:
- **All linear layers**: Best quality, more VRAM. Recommended for 7B-13B.
- **Attention only**: Lower VRAM, good for 70B or when VRAM is tight.
- **MLP only**: Rarely used alone. MLP layers have more parameters.

## Adapter Merging

After training, merge the LoRA adapter back into the base model for deployment.

### Merge and Save

```python
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load base model (full precision)
base_model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    torch_dtype="auto",
    device_map="auto",
)

# Load adapter
model = PeftModel.from_pretrained(base_model, "./output/final-adapter")

# Merge adapter into base model
merged_model = model.merge_and_unload()

# Save merged model
merged_model.save_pretrained("./merged-model")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
tokenizer.save_pretrained("./merged-model")
```

### Merge QLoRA Adapter

QLoRA adapters require dequantizing the base model first:

```python
from transformers import AutoModelForCausalLM
from peft import PeftModel

# Load base model in FULL precision (not quantized) for merging
base_model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    torch_dtype=torch.float16,
    device_map="auto",
)

# Load QLoRA adapter
model = PeftModel.from_pretrained(base_model, "./output/qlora-adapter")

# Merge and save
merged_model = model.merge_and_unload()
merged_model.save_pretrained("./merged-model")
```

**Important**: When merging QLoRA adapters, load the base model in FP16 (not 4-bit). The adapter weights are stored in full precision and need a full-precision base for correct merging.

### Upload Merged Model to Hub

```python
merged_model.push_to_hub("my-org/llama-3.1-8b-finetuned")
tokenizer.push_to_hub("my-org/llama-3.1-8b-finetuned")
```

> **See also**: [hf-hub-datasets](../hf-hub-datasets/SKILL.md) for detailed upload patterns and model card generation

## Advanced LoRA Patterns

### Multiple Adapters

```python
from peft import PeftModel

# Load base + first adapter
model = PeftModel.from_pretrained(base_model, "./adapter-task-a", adapter_name="task_a")

# Load second adapter
model.load_adapter("./adapter-task-b", adapter_name="task_b")

# Switch between adapters
model.set_adapter("task_a")
output_a = model.generate(**inputs)

model.set_adapter("task_b")
output_b = model.generate(**inputs)
```

### LoRA+ (Different Learning Rates for A and B)

```python
from peft import LoraConfig

# LoRA+ uses higher LR for matrix B
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    bias="none",
    task_type="CAUSAL_LM",
    use_rslora=True,  # Rank-stabilized LoRA — scales alpha by sqrt(r)
)
```
