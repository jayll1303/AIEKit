# SFT / DPO / GRPO Workflows with Unsloth

Chi tiết training workflows cho SFT, DPO, GRPO sử dụng Unsloth FastLanguageModel + TRL trainers.

## SFT Workflow (Supervised Fine-Tuning)

### 1. Dataset Preparation

Unsloth hỗ trợ các format dataset phổ biến:

```python
from datasets import load_dataset

# Format 1: Instruction format (ShareGPT-style)
# Columns: conversations (list of {"from": "human"/"gpt", "value": "..."})
dataset = load_dataset("philschmid/dolly-15k-oai-style", split="train")

# Format 2: Chat messages format (recommended)
# Columns: messages (list of {"role": "user"/"assistant", "content": "..."})
dataset = load_dataset("HuggingFaceH4/ultrachat_200k", split="train_sft")

# Format 3: Simple text format
# Column: text (pre-formatted string)
dataset = load_dataset("tatsu-lab/alpaca", split="train")
```

### 2. Chat Template Setup

```python
from unsloth import FastLanguageModel
from unsloth.chat_templates import get_chat_template

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Apply chat template — Unsloth tự detect template phù hợp
tokenizer = get_chat_template(
    tokenizer,
    chat_template="llama-3.1",  # hoặc "chatml", "mistral", "gemma", "phi-3", "qwen-2.5"
)
```

**Supported chat templates:** `llama-3.1`, `llama-3`, `chatml`, `mistral`, `gemma`, `phi-3`, `phi-4`, `qwen-2.5`, `deepseek`, `zephyr`, `alpaca`.

### 3. Format Dataset with Chat Template

```python
def format_chat(example):
    """Convert messages to chat template format."""
    text = tokenizer.apply_chat_template(
        example["messages"],
        tokenize=False,
        add_generation_prompt=False,
    )
    return {"text": text}

dataset = dataset.map(format_chat, batched=False)
```

### 4. Full SFT Training

```python
from trl import SFTTrainer, SFTConfig

model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    lora_alpha=16,
    lora_dropout=0,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    use_gradient_checkpointing="unsloth",
    random_state=42,
)

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    eval_dataset=eval_dataset,  # optional
    args=SFTConfig(
        output_dir="./output-sft",
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        num_train_epochs=3,
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        weight_decay=0.01,
        bf16=True,
        logging_steps=10,
        save_strategy="steps",
        save_steps=100,
        save_total_limit=3,
        max_seq_length=2048,
        packing=True,           # Pack short examples → tăng throughput
        dataset_text_field="text",
        report_to="mlflow",     # hoặc "wandb"
    ),
)

trainer.train()
model.save_pretrained("./output-sft/final-adapter")
tokenizer.save_pretrained("./output-sft/final-adapter")
```

**Validate:** `train_loss` giảm dần. Nếu loss flat → check `dataset_text_field` khớp column name. Nếu loss spike → giảm `learning_rate`.

## DPO Workflow (Direct Preference Optimization)

### 1. Preference Dataset Format

DPO cần dataset với cặp chosen/rejected:

```python
# Required columns: prompt, chosen, rejected
# Mỗi row là 1 prompt với 2 responses: chosen (tốt) và rejected (xấu)
dpo_dataset = load_dataset("argilla/ultrafeedback-binarized-preferences", split="train")

# Hoặc tạo custom dataset
import pandas as pd
data = {
    "prompt": ["Explain quantum computing"],
    "chosen": ["Quantum computing uses qubits that can exist in superposition..."],
    "rejected": ["Quantum computing is just faster computers..."],
}
dpo_dataset = Dataset.from_pandas(pd.DataFrame(data))
```

### 2. Format cho DPO với Chat Template

```python
def format_dpo(example):
    """Format prompt/chosen/rejected thành chat messages."""
    prompt_msg = [{"role": "user", "content": example["prompt"]}]
    chosen_msg = prompt_msg + [{"role": "assistant", "content": example["chosen"]}]
    rejected_msg = prompt_msg + [{"role": "assistant", "content": example["rejected"]}]

    return {
        "prompt": tokenizer.apply_chat_template(prompt_msg, tokenize=False),
        "chosen": tokenizer.apply_chat_template(chosen_msg, tokenize=False),
        "rejected": tokenizer.apply_chat_template(rejected_msg, tokenize=False),
    }

dpo_dataset = dpo_dataset.map(format_dpo, batched=False)
```

### 3. DPO Training

```python
from trl import DPOTrainer, DPOConfig

# Load SFT-trained model (hoặc base model)
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="./output-sft/final-adapter",  # từ SFT step
    max_seq_length=2048,
    load_in_4bit=True,
)
model = FastLanguageModel.get_peft_model(model, r=16, lora_alpha=16,
    target_modules=["q_proj","k_proj","v_proj","o_proj",
                    "gate_proj","up_proj","down_proj"],
    use_gradient_checkpointing="unsloth",
)

trainer = DPOTrainer(
    model=model,
    args=DPOConfig(
        output_dir="./output-dpo",
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        num_train_epochs=1,
        learning_rate=5e-6,       # DPO cần lr thấp hơn SFT
        beta=0.1,                 # KL penalty — cao hơn = conservative hơn
        bf16=True,
        max_length=1024,
        max_prompt_length=512,
        logging_steps=10,
        save_strategy="steps",
        save_steps=50,
    ),
    train_dataset=dpo_dataset,
    tokenizer=tokenizer,
)

trainer.train()
```

**Validate:** `rewards/chosen` > `rewards/rejected` sau vài steps. `rewards/accuracies` > 0.5 và tăng dần. Nếu accuracy ~0.5 → tăng `beta` hoặc check data quality.

## GRPO Workflow (Group Relative Policy Optimization)

GRPO dùng để train reasoning models — model tự generate nhiều responses, reward function đánh giá, model học từ responses tốt nhất.

### 1. Prompt Dataset

```python
# GRPO chỉ cần prompts, không cần responses
# Column: prompt (string)
grpo_dataset = load_dataset("openai/gsm8k", split="train")

def format_grpo(example):
    return {
        "prompt": f"Solve this math problem step by step:\n{example['question']}\n"
    }

grpo_dataset = grpo_dataset.map(format_grpo, batched=False)
```

### 2. Reward Functions

```python
import re

def correctness_reward(completions, answer, **kwargs):
    """Reward based on correct final answer."""
    rewards = []
    for completion, expected in zip(completions, answer):
        # Extract number from completion
        match = re.search(r"#### (\d+)", completion)
        if match and match.group(1) == expected:
            rewards.append(2.0)
        else:
            rewards.append(0.0)
    return rewards

def format_reward(completions, **kwargs):
    """Reward for using proper reasoning format."""
    rewards = []
    for completion in completions:
        score = 0.0
        if "<think>" in completion and "</think>" in completion:
            score += 0.5
        if "<answer>" in completion:
            score += 0.5
        rewards.append(score)
    return rewards

# Combine multiple reward functions
reward_funcs = [correctness_reward, format_reward]
```

### 3. GRPO Training

```python
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

trainer = GRPOTrainer(
    model=model,
    args=GRPOConfig(
        output_dir="./output-grpo",
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        num_train_epochs=1,
        learning_rate=5e-6,
        bf16=True,
        num_generations=4,          # Số responses per prompt
        max_completion_length=512,
        max_prompt_length=256,
        logging_steps=5,
        save_strategy="steps",
        save_steps=50,
    ),
    train_dataset=grpo_dataset,
    reward_funcs=reward_funcs,
)

trainer.train()
```

**Validate:** `reward/mean` tăng dần. Nếu flat → check reward function trả về scores có variance. Nếu OOM → giảm `num_generations` (4 → 2) hoặc `max_completion_length`.

## Hyperparameter Recommendations

### Per Model Size

| Model Size | r | lora_alpha | lr (SFT) | lr (DPO) | lr (GRPO) | batch × accum | max_seq_length |
|---|---|---|---|---|---|---|---|
| 1B-3B | 8 | 8 | 3e-4 | 1e-5 | 1e-5 | 4 × 4 | 2048 |
| 7B-8B | 16 | 16 | 2e-4 | 5e-6 | 5e-6 | 2 × 4 | 2048 |
| 13B | 16 | 16 | 1e-4 | 5e-6 | 5e-6 | 1 × 8 | 1024 |
| 34B | 8-16 | 16 | 5e-5 | 1e-6 | 1e-6 | 1 × 8 | 1024 |
| 70B | 8 | 16 | 5e-5 | 1e-6 | 1e-6 | 1 × 16 | 512 |

### Per Training Method

| Method | Epochs | Warmup | Weight Decay | Scheduler | Notes |
|---|---|---|---|---|---|
| SFT | 1-3 | 0.03 | 0.01 | cosine | Dùng packing=True cho short examples |
| DPO | 1 | 0.1 | 0.0 | linear | beta=0.1 default, tăng nếu quá aggressive |
| GRPO | 1 | 0.03 | 0.01 | cosine | num_generations=4-8, giảm nếu OOM |

## Continued Training from Checkpoints

### Resume từ LoRA Checkpoint

```python
from unsloth import FastLanguageModel

# Load base model + existing LoRA adapter
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Load existing adapter
from peft import PeftModel
model = PeftModel.from_pretrained(model, "./output-sft/checkpoint-500")

# Continue training — KHÔNG gọi get_peft_model lại
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=new_dataset,
    args=SFTConfig(
        output_dir="./output-sft-continued",
        learning_rate=1e-4,  # Giảm lr khi continue training
        # ... other args
    ),
)
trainer.train()
```

### SFT → DPO Pipeline

Workflow phổ biến: SFT trước để model học format, sau đó DPO để align preferences.

```
1. SFT: Train trên instruction dataset (2-3 epochs)
   → Save adapter: ./output-sft/final-adapter
2. Merge adapter (optional): save_pretrained_merged()
3. DPO: Load SFT model, train trên preference dataset (1 epoch)
   → Save adapter: ./output-dpo/final-adapter
4. Export: save_pretrained_gguf() hoặc save_pretrained_merged()
```

⚠️ **Lưu ý:** Khi chuyển từ SFT sang DPO, giảm learning rate (2e-4 → 5e-6). DPO rất sensitive với lr cao — có thể làm model "quên" SFT training.
