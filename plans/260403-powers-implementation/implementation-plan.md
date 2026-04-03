# Implementation Plan: power-huggingface & power-gpu-monitor

## Date: 2026-04-03

## Power 1: power-huggingface

### MCP Server
- Dùng official HF MCP Server: `https://huggingface.co/mcp` (remote HTTP)
- Hoặc local: `npx @llmindset/hf-mcp-server` (STDIO)
- Hoặc community: `shreyaskarnik/huggingface-mcp-server` (Python, uvx)
- **Chọn**: Cung cấp cả 2 options (remote + local) trong mcp.json

### Steering
- `workflow-model-discovery.md`: Guide agent cách search, compare, chọn model
- `workflow-dataset-pipeline.md`: Guide agent cách tìm, load, validate datasets

### POWER.md
- Onboarding: setup HF_TOKEN
- Keywords: huggingface, hub, model, dataset, spaces, papers
- Kết nối skills: hf-hub-datasets, hf-transformers-trainer, model-quantization, unsloth-training

## Power 2: power-gpu-monitor

### MCP Server
- Dùng `mcp-system-monitor` (Python, FastMCP): `huhabla/mcp-system-monitor`
- Tools: get_gpu_info, get_memory_info, get_cpu_info, get_system_snapshot
- Hoặc tự build lightweight Python MCP server chỉ focus GPU + VRAM estimation

### Chọn approach
- **Option A**: Dùng `mcp-system-monitor` có sẵn — full system monitoring, GPU included
- **Option B**: Custom lightweight MCP server — chỉ GPU + VRAM estimation
- **Chọn Option A** (mcp-system-monitor) + thêm steering cho VRAM estimation logic

### Steering
- `workflow-vram-estimation.md`: VRAM estimation formulas, model size → VRAM mapping
- `workflow-gpu-allocation.md`: Multi-GPU strategies, memory budgeting

### POWER.md
- Onboarding: check nvidia-smi available, install dependencies
- Keywords: gpu, vram, nvidia, cuda, memory, oom, nvidia-smi
- Kết nối: mọi serving + training skills

## TODO Tasks

- [x] Research MCP servers
- [x] Create power-huggingface/POWER.md
- [x] Create power-huggingface/mcp.json
- [x] Create power-huggingface/steering/workflow-model-discovery.md
- [x] Create power-huggingface/steering/workflow-dataset-pipeline.md
- [x] Create power-gpu-monitor/POWER.md
- [x] Create power-gpu-monitor/mcp.json
- [x] Create power-gpu-monitor/steering/workflow-vram-estimation.md
- [x] Create power-gpu-monitor/steering/workflow-gpu-allocation.md
- [x] Update docs/skill-interconnection-map.md
- [x] Update README.md
