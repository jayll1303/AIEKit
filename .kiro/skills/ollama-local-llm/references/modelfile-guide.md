# Modelfile Guide

Complete reference for creating and customizing Ollama models via Modelfile. Covers syntax, all parameter options, templates for different use cases, GGUF import, and multi-stage patterns.

## Modelfile Syntax Overview

A Modelfile is a blueprint for creating custom Ollama models. It defines the base model, parameters, system prompt, and chat template.

```dockerfile
# Comments start with #
FROM <base-model>           # Required: base model or GGUF path
PARAMETER <key> <value>     # Optional: model parameters
SYSTEM """<text>"""         # Optional: system prompt
TEMPLATE """<template>"""   # Optional: chat template (Go template syntax)
ADAPTER <path>              # Optional: LoRA adapter path
LICENSE """<text>"""        # Optional: license text
MESSAGE <role> <content>    # Optional: pre-seed conversation history
```

### Build and Run

```bash
# Create model from Modelfile
ollama create my-model -f ./Modelfile

# Verify creation
ollama list | grep my-model

# Run
ollama run my-model

# Show model details (verify params applied)
ollama show my-model
```

## All PARAMETER Options

### Sampling Parameters

| Parameter | Default | Range | Description |
|---|---|---|---|
| `temperature` | 0.8 | 0.0 - 2.0 | Randomness. 0 = deterministic, higher = more creative |
| `top_p` | 0.9 | 0.0 - 1.0 | Nucleus sampling. Lower = more focused |
| `top_k` | 40 | 1 - 100+ | Top-K sampling. Lower = more focused |
| `min_p` | 0.0 | 0.0 - 1.0 | Minimum probability threshold |
| `typical_p` | 1.0 | 0.0 - 1.0 | Locally typical sampling |
| `repeat_penalty` | 1.1 | 0.0 - 2.0 | Penalize repeated tokens |
| `repeat_last_n` | 64 | 0 - num_ctx | Window for repeat penalty |
| `presence_penalty` | 0.0 | -2.0 - 2.0 | Penalize tokens already present |
| `frequency_penalty` | 0.0 | -2.0 - 2.0 | Penalize frequent tokens |

### Context and Generation

| Parameter | Default | Range | Description |
|---|---|---|---|
| `num_ctx` | 2048 | 512 - 131072 | Context window size (tokens) |
| `num_predict` | -1 | -2, -1, 1+ | Max tokens to generate. -1 = infinite, -2 = fill context |
| `stop` | none | string | Stop sequence (can specify multiple) |
| `seed` | 0 | integer | Random seed for reproducibility (0 = random) |

### Performance and Hardware

| Parameter | Default | Range | Description |
|---|---|---|---|
| `num_gpu` | auto | -1, 0, 1+ | GPU layers. -1 = auto, 0 = CPU only |
| `num_thread` | auto | 1+ | CPU threads for computation |
| `num_batch` | 512 | 1+ | Batch size for prompt processing |
| `num_keep` | 4 | integer | Tokens to keep from initial prompt |
| `low_vram` | false | bool | Reduce VRAM usage (slower) |
| `main_gpu` | 0 | integer | Primary GPU index for multi-GPU |
| `use_mmap` | true | bool | Memory-map model file |
| `use_mlock` | false | bool | Lock model in RAM (prevent swap) |

### Example: Tuned Parameters

```dockerfile
FROM llama3.1:8b

# Conservative, focused output
PARAMETER temperature 0.3
PARAMETER top_p 0.85
PARAMETER top_k 20
PARAMETER repeat_penalty 1.2

# Large context window
PARAMETER num_ctx 8192
PARAMETER num_predict 2048

# GPU config
PARAMETER num_gpu 99
PARAMETER num_batch 1024
```

## Templates for Different Use Cases

### Chat Assistant

```dockerfile
FROM llama3.1:8b

PARAMETER temperature 0.7
PARAMETER num_ctx 4096

SYSTEM """You are a friendly, helpful AI assistant. Be concise and accurate.
If you don't know something, say so honestly."""

# Pre-seed with example conversation
MESSAGE user "What can you help me with?"
MESSAGE assistant "I can help with coding, writing, analysis, math, and general questions. What do you need?"
```

### Code Assistant

```dockerfile
FROM codellama:13b

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
PARAMETER num_predict 4096
PARAMETER repeat_penalty 1.0
PARAMETER stop "<|end|>"

SYSTEM """You are an expert software engineer. Follow these rules:
1. Write clean, production-ready code
2. Include error handling
3. Add brief comments for complex logic
4. Use modern language features and best practices
5. If asked to fix code, explain the bug first, then provide the fix"""
```

### RAG Context Processor

```dockerfile
FROM llama3.1:8b

PARAMETER temperature 0.1
PARAMETER top_p 0.85
PARAMETER num_ctx 16384
PARAMETER num_predict 1024
PARAMETER repeat_penalty 1.0

SYSTEM """You are a precise information extraction assistant.
Answer ONLY based on the provided context. Rules:
1. If the context doesn't contain the answer, say "Not found in provided context"
2. Quote relevant passages when possible
3. Be concise and factual
4. Never make up information"""
```

### JSON Output Generator

```dockerfile
FROM llama3.1:8b

PARAMETER temperature 0.0
PARAMETER num_ctx 4096
PARAMETER num_predict 2048

SYSTEM """You are a structured data extraction assistant.
Always respond with valid JSON only. No markdown, no explanation, no extra text.
If you cannot extract the requested data, return {"error": "cannot extract"}."""
```

### Summarizer

```dockerfile
FROM llama3.1:8b

PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER num_ctx 16384
PARAMETER num_predict 512

SYSTEM """You are a concise summarizer. Rules:
1. Summarize in 3-5 bullet points
2. Capture key facts and conclusions
3. Preserve important numbers and names
4. Use simple, clear language"""
```

## Importing GGUF Models

Import any GGUF model file into Ollama for easy management.

### From Local GGUF File

```dockerfile
# Modelfile
FROM ./models/my-model.Q4_K_M.gguf

PARAMETER num_ctx 4096
PARAMETER temperature 0.7

SYSTEM """You are a helpful assistant."""
```

```bash
# Create from GGUF
ollama create my-gguf-model -f Modelfile

# Verify
ollama list | grep my-gguf-model
ollama show my-gguf-model
```

### From HuggingFace GGUF

```bash
# Step 1: Download GGUF from HuggingFace
pip install huggingface-hub
huggingface-cli download TheBloke/Llama-2-7B-GGUF \
  llama-2-7b.Q4_K_M.gguf \
  --local-dir ./models

# Step 2: Create Modelfile pointing to downloaded GGUF
cat > Modelfile << 'EOF'
FROM ./models/llama-2-7b.Q4_K_M.gguf
PARAMETER num_ctx 4096
SYSTEM """You are a helpful assistant."""
EOF

# Step 3: Import into Ollama
ollama create llama2-local -f Modelfile
```

**Validate:** `ollama run llama2-local "Hello"` produces a response. If fails → check GGUF file path is correct and file is not corrupted.

### With LoRA Adapter

```dockerfile
FROM llama3.1:8b
ADAPTER ./path/to/lora-adapter

PARAMETER temperature 0.7
SYSTEM """You are a domain-specific assistant fine-tuned for medical Q&A."""
```

> **Note:** Adapter must be in GGUF format. Convert safetensors LoRA to GGUF using llama.cpp's `convert_lora_to_gguf.py`.

## Multi-Stage Patterns

### Base + Specialized Variants

```bash
# Step 1: Create base model with shared config
cat > Modelfile.base << 'EOF'
FROM llama3.1:8b
PARAMETER temperature 0.3
PARAMETER num_ctx 8192
PARAMETER num_gpu 99
EOF

ollama create my-base -f Modelfile.base

# Step 2: Create specialized variants FROM the base
cat > Modelfile.coder << 'EOF'
FROM my-base
PARAMETER temperature 0.1
SYSTEM """You are an expert Python developer."""
EOF

cat > Modelfile.writer << 'EOF'
FROM my-base
PARAMETER temperature 0.8
SYSTEM """You are a creative writing assistant."""
EOF

ollama create my-coder -f Modelfile.coder
ollama create my-writer -f Modelfile.writer
```

### Version Management

```bash
# Tag versions
ollama cp my-coder my-coder:v1
ollama cp my-coder my-coder:v2

# List versions
ollama list | grep my-coder

# Rollback
ollama run my-coder:v1
```

## Template Syntax (Go Templates)

Ollama uses Go template syntax for chat formatting.

### Available Variables

| Variable | Description |
|---|---|
| `{{ .System }}` | System prompt content |
| `{{ .Prompt }}` | User message |
| `{{ .Response }}` | Assistant response (during generation) |
| `{{ if .System }}` | Conditional: system prompt exists |
| `{{ end }}` | End conditional block |

### ChatML Template

```dockerfile
TEMPLATE """{{- if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
{{ .Response }}<|im_end|>"""
```

### Llama 3 Template

```dockerfile
TEMPLATE """<|begin_of_text|>{{- if .System }}<|start_header_id|>system<|end_header_id|>

{{ .System }}<|eot_id|>{{ end }}<|start_header_id|>user<|end_header_id|>

{{ .Prompt }}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

{{ .Response }}<|eot_id|>"""
```

### Mistral Template

```dockerfile
TEMPLATE """[INST] {{- if .System }}{{ .System }}

{{ end }}{{ .Prompt }} [/INST] {{ .Response }}"""
```

## Troubleshooting Modelfile Issues

```
Model create fails?
├─ FROM model not found → ollama pull <base-model> first
├─ GGUF path wrong → use relative or absolute path, verify file exists
├─ Syntax error → check triple quotes for SYSTEM/TEMPLATE
└─ Adapter incompatible → ensure adapter matches base model architecture

Parameters not taking effect?
├─ Typo in parameter name → check exact spelling from table above
├─ Overridden at runtime → ollama run params override Modelfile
├─ num_ctx too large → may silently cap based on model's trained context
└─ Verify with: ollama show <model> --modelfile

Template issues?
├─ Missing {{ end }} → every {{ if }} needs {{ end }}
├─ Wrong variable name → use .System, .Prompt, .Response exactly
├─ Special chars in template → escape with {{- for trim whitespace
└─ Test: ollama show <model> --template
```
