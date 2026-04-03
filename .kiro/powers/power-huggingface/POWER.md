---
name: "huggingface"
displayName: "HuggingFace Hub"
description: "Search models, datasets, papers, spaces on HuggingFace Hub. Compare models, check configs, find trending papers and discover HF Spaces."
keywords: ["huggingface", "hub", "model", "dataset", "spaces", "papers", "hf", "transformers", "pretrained", "model card", "model search"]
author: "AIE-Skills"
---

# HuggingFace Hub Power

Connect agent trực tiếp với HuggingFace Hub API — search models, datasets, papers, spaces mà không cần web search.

## Onboarding

### 1. Setup HF Token (optional nhưng recommended)

```bash
# Tạo token tại https://huggingface.co/settings/tokens
# Thêm vào environment
export HF_TOKEN="hf_xxxxxxxxxxxxx"
```

Token cho phép:
- Higher API rate limits
- Access private repos
- Access gated models (Llama, Gemma...)

### 2. MCP Server

Power này dùng official HuggingFace remote MCP server:
- URL: `https://huggingface.co/mcp`
- Transport: Streamable HTTP (stateless, direct response)
- Không cần install gì — chỉ cần internet connection
- Customize tools tại: https://huggingface.co/settings/mcp

Nếu muốn chạy local (offline):
```bash
npx @llmindset/hf-mcp-server       # STDIO mode
npx @llmindset/hf-mcp-server-http  # HTTP mode
```

### 3. Verify Connection

Sau khi cài power, test bằng cách hỏi agent:
- "Search for Vietnamese embedding models on HuggingFace"
- "What are today's trending papers on HF?"

## Available Tools

### Model Tools
- `search-models` — Search models by query, author, tags, limit
- `get-model-info` — Get model card, config, tags, downloads

### Dataset Tools
- `search-datasets` — Search datasets with filters
- `get-dataset-info` — Get dataset card, size, features

### Space Tools
- `search-spaces` — Search Spaces by SDK type, author
- `get-space-info` — Get Space details, runtime status

### Paper Tools
- `get-paper-info` — Get paper metadata + implementations
- `get-daily-papers` — Get curated daily papers list

### Collection Tools
- `search-collections` — Search curated collections
- `get-collection-info` — Get collection details

### Prompts
- `compare-models` — Compare multiple models side-by-side
- `summarize-paper` — Summarize arXiv paper with HF context

## Workflow: Model Discovery

```
User cần model → search-models (query + filters)
    → get-model-info (check config, size, license)
    → compare-models (nếu nhiều candidates)
    → Quyết định → chain sang skill phù hợp:
        - Fine-tune: → hf-transformers-trainer / unsloth-training
        - Quantize: → model-quantization
        - Serve: → vllm-tgi-inference / sglang-serving / ollama-local-llm
        - Download: → hf-hub-datasets (snapshot_download)
```

## Workflow: Dataset Discovery

```
User cần data → search-datasets (query + filters)
    → get-dataset-info (check size, features, license)
    → Chain sang: hf-hub-datasets (load_dataset, streaming)
```

## Workflow: Research

```
User cần paper → get-daily-papers (trending)
    hoặc get-paper-info (specific arXiv ID)
    → summarize-paper (brief/detailed)
    → Chain sang: arxiv-reader (đọc full paper)
```

## Connected Skills

| Situation | Skill | Why |
|-----------|-------|-----|
| Download model/dataset | hf-hub-datasets | snapshot_download, load_dataset |
| Fine-tune model | hf-transformers-trainer | Trainer, TRL, PEFT |
| Fast fine-tune | unsloth-training | 2x faster, 70% less VRAM |
| Quantize model | model-quantization | GGUF, GPTQ, AWQ |
| Serve model | vllm-tgi-inference | vLLM, TGI |
| Read full paper | arxiv-reader | HTML parsing |

## MCP Config Placeholders

Trước khi dùng power này, set environment variable `HF_TOKEN`:

- **`HF_TOKEN`**: HuggingFace API token để tăng rate limit và access private/gated models.
  - **Cách lấy:**
    1. Đăng nhập https://huggingface.co/settings/tokens
    2. Click "New token" → chọn "Read" permission
    3. Copy token (bắt đầu bằng `hf_...`)
    4. Set env: `export HF_TOKEN="hf_xxxxxxxxxxxxx"`

Token là optional nhưng recommended — không có token vẫn search được nhưng bị rate limit và không access được gated models (Llama, Gemma...).

## Anti-Patterns

| Agent nghĩ | Thực tế |
|-------------|---------|
| "Dùng web search để tìm model" | Dùng search-models — structured, faster, có metadata |
| "Không cần check model info" | LUÔN check model card trước khi download — license, size, requirements |
| "Model nhiều downloads = tốt nhất" | Downloads ≠ quality. Check benchmarks, model card, recent activity |
