# Dataset Preparation

Patterns for preparing datasets for instruction tuning, chat format (ChatML, Llama), and preference data (chosen/rejected pairs) for DPO/GRPO alignment.

## Instruction Tuning Format

### Alpaca-Style Format

```python
from datasets import Dataset

# Standard instruction format
dataset = Dataset.from_dict({
    "instruction": [
        "Summarize the following text.",
        "Translate to French.",
    ],
    "input": [
        "Machine learning is a subset of AI that enables systems to learn...",
        "Hello, how are you?",
    ],
    "output": [
        "ML is an AI subset enabling automated learning from data.",
        "Bonjour, comment allez-vous ?",
    ],
})
```

### Formatting Function for Trainer

```python
def format_alpaca(example):
    """Convert Alpaca format to text for SFTTrainer."""
    if example.get("input"):
        text = (
            f"### Instruction:\n{example['instruction']}\n\n"
            f"### Input:\n{example['input']}\n\n"
            f"### Response:\n{example['output']}"
        )
    else:
        text = (
            f"### Instruction:\n{example['instruction']}\n\n"
            f"### Response:\n{example['output']}"
        )
    return {"text": text}

dataset = dataset.map(format_alpaca)
```

## Chat Format Templates

### ChatML Format (Qwen, Phi, many models)

```
<|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
What is Python?<|im_end|>
<|im_start|>assistant
Python is a high-level programming language...<|im_end|>
```

```python
def format_chatml(example):
    """Convert messages to ChatML format."""
    messages = example["messages"]
    text = ""
    for msg in messages:
        text += f"<|im_start|>{msg['role']}\n{msg['content']}<|im_end|>\n"
    return {"text": text}
```

### Llama 3 Chat Format

```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a helpful assistant.<|eot_id|><|start_header_id|>user<|end_header_id|>

What is Python?<|eot_id|><|start_header_id|>assistant<|end_header_id|>

Python is a high-level programming language...<|eot_id|>
```

```python
def format_llama3(example):
    """Convert messages to Llama 3 chat format."""
    messages = example["messages"]
    text = "<|begin_of_text|>"
    for msg in messages:
        text += f"<|start_header_id|>{msg['role']}<|end_header_id|>\n\n"
        text += f"{msg['content']}<|eot_id|>"
    return {"text": text}
```

### Using Tokenizer's Chat Template (Recommended)

The safest approach — use the tokenizer's built-in chat template:

```python
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

def format_with_template(example):
    """Use tokenizer's chat template for correct formatting."""
    messages = example["messages"]
    text = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=False,
    )
    return {"text": text}

dataset = dataset.map(format_with_template)
```

**Why use `apply_chat_template`?**
- Automatically handles model-specific special tokens
- Correct BOS/EOS token placement
- Works across model families without manual format changes

## Tokenization with Label Masking

For instruction tuning, you typically want to compute loss only on the response tokens (not the prompt).

### Mask Prompt Tokens in Labels

```python
def tokenize_with_label_masking(example, tokenizer, max_length=2048):
    """Tokenize and mask prompt tokens in labels."""
    messages = example["messages"]

    # Find where the assistant response starts
    prompt_messages = [m for m in messages if m["role"] != "assistant"]
    prompt_text = tokenizer.apply_chat_template(
        prompt_messages, tokenize=False, add_generation_prompt=True,
    )
    full_text = tokenizer.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=False,
    )

    # Tokenize
    prompt_ids = tokenizer(prompt_text, add_special_tokens=False)["input_ids"]
    full_ids = tokenizer(
        full_text, max_length=max_length, truncation=True, add_special_tokens=False,
    )["input_ids"]

    # Create labels: -100 for prompt tokens (ignored in loss)
    labels = [-100] * len(prompt_ids) + full_ids[len(prompt_ids):]

    return {
        "input_ids": full_ids,
        "labels": labels,
        "attention_mask": [1] * len(full_ids),
    }
```

## Preference Data (DPO/GRPO)

### Standard Preference Format

```python
from datasets import Dataset

# DPO requires: prompt, chosen, rejected
preference_dataset = Dataset.from_dict({
    "prompt": [
        "Explain quantum computing in simple terms.",
        "Write a Python function to reverse a string.",
    ],
    "chosen": [
        "Quantum computing uses quantum bits (qubits) that can be in multiple states simultaneously...",
        "def reverse_string(s):\n    return s[::-1]",
    ],
    "rejected": [
        "Quantum computing is complicated.",
        "You can use a loop to reverse it.",
    ],
})
```

### Conversational Preference Format

```python
# For chat models, use message lists
preference_dataset = Dataset.from_dict({
    "prompt": [
        [{"role": "user", "content": "Explain quantum computing"}],
    ],
    "chosen": [
        [{"role": "assistant", "content": "Quantum computing uses qubits..."}],
    ],
    "rejected": [
        [{"role": "assistant", "content": "It's complicated."}],
    ],
})
```

### Converting from Other Formats

```python
# From Anthropic HH-RLHF format
def convert_hh_rlhf(example):
    """Convert Anthropic HH format to DPO format."""
    return {
        "prompt": example["chosen"].split("\n\nAssistant:")[0] + "\n\nAssistant:",
        "chosen": example["chosen"].split("\n\nAssistant:")[-1].strip(),
        "rejected": example["rejected"].split("\n\nAssistant:")[-1].strip(),
    }

# From UltraFeedback format (scores → preference pairs)
def convert_ultrafeedback(example):
    """Convert scored responses to preference pairs."""
    responses = example["completions"]
    sorted_responses = sorted(responses, key=lambda x: x["overall_score"], reverse=True)
    return {
        "prompt": example["instruction"],
        "chosen": sorted_responses[0]["response"],
        "rejected": sorted_responses[-1]["response"],
    }
```

## Data Quality Checklist

```
Dataset quality issues?
├─ Duplicates
│   └─ dataset = dataset.filter(lambda x, idx: idx == dataset["text"].index(x["text"]), with_indices=True)
│
├─ Too short examples
│   └─ dataset = dataset.filter(lambda x: len(x["text"].split()) > 20)
│
├─ Inconsistent formatting
│   └─ Always use tokenizer.apply_chat_template() for consistency
│
├─ Imbalanced topics
│   └─ Stratify sampling or oversample underrepresented topics
│
├─ Preference data: chosen ≈ rejected quality
│   └─ Ensure clear quality gap between chosen and rejected
│   └─ Filter pairs where both are good or both are bad
│
└─ Train/eval split
    └─ dataset = dataset.train_test_split(test_size=0.05, seed=42)
```

## Loading Common Datasets

```python
from datasets import load_dataset

# Instruction tuning datasets
alpaca = load_dataset("tatsu-lab/alpaca", split="train")
dolly = load_dataset("databricks/databricks-dolly-15k", split="train")
oasst = load_dataset("OpenAssistant/oasst1", split="train")

# Preference datasets (for DPO)
hh_rlhf = load_dataset("Anthropic/hh-rlhf", split="train")
ultrafeedback = load_dataset("HuggingFaceH4/ultrafeedback_binarized", split="train_prefs")

# Code instruction datasets
code_alpaca = load_dataset("sahil2801/CodeAlpaca-20k", split="train")
```

> **See also**: [hf-hub-datasets](../hf-hub-datasets/SKILL.md) for loading, filtering, and streaming datasets from HuggingFace Hub
