# TRL Workflows: SFT, DPO, GRPO

Detailed workflow templates for Transformer Reinforcement Learning (TRL) library covering Supervised Fine-Tuning (SFT), Direct Preference Optimization (DPO), and Group Relative Policy Optimization (GRPO).

## SFT (Supervised Fine-Tuning)

### Dataset Format

SFTTrainer accepts multiple dataset formats:

**Format 1: Text column (simplest)**
```python
# Dataset with a "text" column containing formatted conversations
dataset = Dataset.from_dict({
    "text": [
        "<|user|>\nWhat is Python?\n<|assistant|>\nPython is a programming language...",
        "<|user|>\nExplain ML\n<|assistant|>\nMachine learning is...",
    ]
})
```

**Format 2: Conversational format (recommended)**
```python
# Dataset with "messages" column (list of dicts)
dataset = Dataset.from_dict({
    "messages": [
        [
            {"role": "user", "content": "What is Python?"},
            {"role": "assistant", "content": "Python is a programming language..."},
        ],
        [
            {"role": "user", "content": "Explain ML"},
            {"role": "assistant", "content": "Machine learning is..."},
        ],
    ]
})
```

**Format 3: Instruction format**
```python
dataset = Dataset.from_dict({
    "prompt": ["What is Python?", "Explain ML"],
    "completion": ["Python is a programming language...", "Machine learning is..."],
})
```

### Full SFT Workflow

```python
from trl import SFTTrainer, SFTConfig
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from datasets import load_dataset
import torch

# Load model (QLoRA for VRAM efficiency)
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
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
tokenizer.pad_token = tokenizer.eos_token

# LoRA config
lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    bias="none", task_type="CAUSAL_LM",
)

# Load dataset
dataset = load_dataset("your-org/instruction-dataset", split="train")

# SFT config
sft_config = SFTConfig(
    output_dir="./output-sft",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    bf16=True,
    gradient_checkpointing=True,
    max_seq_length=2048,
    packing=True,                    # Pack short examples for efficiency
    logging_steps=10,
    save_strategy="steps",
    save_steps=200,
    save_total_limit=3,
    report_to="mlflow",
)

# Train
trainer = SFTTrainer(
    model=model,
    args=sft_config,
    train_dataset=dataset,
    peft_config=lora_config,
    tokenizer=tokenizer,
)

trainer.train()
trainer.save_model("./output-sft/final")
```

### SFT Key Parameters

| Parameter | Default | Recommended | Notes |
|---|---|---|---|
| `max_seq_length` | 1024 | 2048 | Match model's training context |
| `packing` | False | True | Pack short examples, improves throughput |
| `dataset_text_field` | None | "text" | Column name for text format |
| `num_of_sequences` | 1024 | 1024 | Number of sequences for packing buffer |

## DPO (Direct Preference Optimization)

### Dataset Format

DPO requires preference pairs: a chosen (preferred) and rejected response for each prompt.

```python
# Required columns: prompt, chosen, rejected
dpo_dataset = Dataset.from_dict({
    "prompt": [
        "Explain quantum computing",
        "Write a haiku about coding",
    ],
    "chosen": [
        "Quantum computing uses quantum bits (qubits) that can exist in superposition...",
        "Lines of code cascade\nBugs emerge from the shadows\nCoffee fuels the fix",
    ],
    "rejected": [
        "Quantum computing is just faster computers.",
        "Coding is fun and cool.",
    ],
})
```

**Conversational format (recommended for chat models)**:
```python
dpo_dataset = Dataset.from_dict({
    "prompt": [
        [{"role": "user", "content": "Explain quantum computing"}],
    ],
    "chosen": [
        [{"role": "assistant", "content": "Quantum computing uses qubits..."}],
    ],
    "rejected": [
        [{"role": "assistant", "content": "Quantum computing is just faster computers."}],
    ],
})
```

### Full DPO Workflow

```python
from trl import DPOTrainer, DPOConfig
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from datasets import load_dataset
import torch

# Load SFT-trained model (or base model)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "./output-sft/final",  # Use SFT model as starting point
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("./output-sft/final")
tokenizer.pad_token = tokenizer.eos_token

# LoRA config for DPO
lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    bias="none", task_type="CAUSAL_LM",
)

# Load preference dataset
dpo_dataset = load_dataset("your-org/preference-dataset", split="train")

# DPO config
dpo_config = DPOConfig(
    output_dir="./output-dpo",
    num_train_epochs=1,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    learning_rate=5e-5,
    beta=0.1,                        # KL penalty — higher = more conservative
    loss_type="sigmoid",             # "sigmoid" (default), "hinge", "ipo"
    bf16=True,
    gradient_checkpointing=True,
    max_length=1024,
    max_prompt_length=512,
    logging_steps=10,
    save_strategy="steps",
    save_steps=100,
    report_to="mlflow",
)

trainer = DPOTrainer(
    model=model,
    args=dpo_config,
    train_dataset=dpo_dataset,
    tokenizer=tokenizer,
    peft_config=lora_config,
)

trainer.train()
trainer.save_model("./output-dpo/final")
```

### DPO Key Parameters

| Parameter | Default | Recommended | Notes |
|---|---|---|---|
| `beta` | 0.1 | 0.1-0.5 | KL penalty. Higher = closer to reference model |
| `loss_type` | "sigmoid" | "sigmoid" | "ipo" for identity preference optimization |
| `max_length` | 512 | 1024 | Total sequence length (prompt + response) |
| `max_prompt_length` | 128 | 512 | Max tokens for prompt portion |
| `learning_rate` | 1e-6 | 5e-6 to 5e-5 | Very low LR for alignment stability |

### DPO Tips

- **Always start from an SFT model** — DPO on a base model gives poor results
- **beta tuning**: Start with 0.1, increase if model diverges too much from reference
- **Data quality matters more than quantity** — 1K high-quality pairs > 10K noisy pairs
- **Reference model**: DPOTrainer automatically uses the initial model as reference

## GRPO (Group Relative Policy Optimization)

### Dataset Format

GRPO requires prompts and a reward function (no pre-computed preferences needed).

```python
# Simple prompt dataset
grpo_dataset = Dataset.from_dict({
    "prompt": [
        "Write a Python function to sort a list",
        "Explain the theory of relativity simply",
        "Create a SQL query to find duplicate records",
    ],
})
```

### Reward Functions

```python
# Option 1: Simple rule-based reward
def length_reward(completions, **kwargs):
    """Reward longer, more detailed responses."""
    return [min(len(c.split()) / 100, 1.0) for c in completions]

# Option 2: Format-checking reward
def code_format_reward(completions, **kwargs):
    """Reward responses that contain code blocks."""
    rewards = []
    for c in completions:
        if "```" in c and "def " in c:
            rewards.append(1.0)
        elif "```" in c:
            rewards.append(0.5)
        else:
            rewards.append(0.0)
    return rewards

# Option 3: Multiple reward functions (combined)
def correctness_reward(completions, **kwargs):
    """Check if code is syntactically valid."""
    rewards = []
    for c in completions:
        try:
            compile(c, "<string>", "exec")
            rewards.append(1.0)
        except SyntaxError:
            rewards.append(0.0)
    return rewards
```

### Full GRPO Workflow

```python
from trl import GRPOTrainer, GRPOConfig
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from datasets import load_dataset
import torch

# Load SFT model
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "./output-sft/final",
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("./output-sft/final")
tokenizer.pad_token = tokenizer.eos_token

lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    bias="none", task_type="CAUSAL_LM",
)

# Prompt dataset
prompt_dataset = load_dataset("your-org/prompts", split="train")

# GRPO config
grpo_config = GRPOConfig(
    output_dir="./output-grpo",
    num_train_epochs=1,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    learning_rate=1e-5,
    bf16=True,
    gradient_checkpointing=True,
    num_generations=4,               # Generate 4 completions per prompt
    max_completion_length=512,
    max_prompt_length=256,
    logging_steps=10,
    save_strategy="steps",
    save_steps=100,
    report_to="mlflow",
)

# Define reward functions
def quality_reward(completions, **kwargs):
    return [min(len(c.split()) / 50, 1.0) for c in completions]

trainer = GRPOTrainer(
    model=model,
    args=grpo_config,
    train_dataset=prompt_dataset,
    reward_funcs=quality_reward,
    peft_config=lora_config,
)

trainer.train()
trainer.save_model("./output-grpo/final")
```

### GRPO Key Parameters

| Parameter | Default | Recommended | Notes |
|---|---|---|---|
| `num_generations` | 4 | 4-8 | Group size for reward comparison |
| `max_completion_length` | 256 | 512 | Max tokens for generated completions |
| `max_prompt_length` | 256 | 256 | Max tokens for input prompts |
| `temperature` | 0.7 | 0.7-1.0 | Sampling temperature for generations |
| `learning_rate` | 1e-6 | 1e-6 to 1e-5 | Very conservative for policy optimization |

### GRPO vs DPO

| Aspect | DPO | GRPO |
|---|---|---|
| Data requirement | Pre-collected preference pairs | Only prompts + reward function |
| Reward model | Implicit (from preferences) | Explicit reward function |
| VRAM usage | Lower (no generation during training) | Higher (generates completions on-the-fly) |
| Flexibility | Fixed to collected preferences | Can iterate reward function |
| Best for | When you have human preference data | When you can define reward programmatically |

## Typical Training Pipeline

```
1. Prepare dataset (instruction format or chat format)
   └─ See dataset-preparation.md

2. SFT: Fine-tune on instruction/chat data
   └─ SFTTrainer + QLoRA for VRAM efficiency

3. (Optional) DPO: Align with human preferences
   └─ DPOTrainer on chosen/rejected pairs

4. (Optional) GRPO: Optimize with reward function
   └─ GRPOTrainer with custom reward

5. Merge adapter and deploy
   └─ See peft-lora-qlora.md for merging
   └─ See vllm-tgi-inference for serving
```
