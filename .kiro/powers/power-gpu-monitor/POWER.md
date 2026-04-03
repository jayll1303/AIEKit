---
name: "power-gpu-monitor"
displayName: "GPU Monitor & VRAM Planner"
description: "Monitor GPU status, VRAM usage, estimate memory requirements for ML models. Use when checking GPU availability, diagnosing OOM errors, planning model deployment, estimating VRAM for training or inference."
keywords: ["gpu", "vram", "nvidia", "cuda", "memory", "oom", "nvidia-smi", "gpu-monitor", "out of memory", "gpu utilization", "memory estimation"]
---

# GPU Monitor & VRAM Planner Power

Real-time GPU monitoring + VRAM estimation logic — giải quyết pain point #1 của AI Engineer: OOM errors.

## Onboarding

### 1. Prerequisites

```bash
# Check NVIDIA driver
nvidia-smi

# Check Python + uv
python --version  # 3.10+
uv --version
```

Yêu cầu:
- NVIDIA GPU với driver installed (cho full GPU metrics)
- Python 3.10+ và uv
- Hoạt động trên Linux, Windows, macOS (Apple Silicon có limited GPU metrics)

### 2. MCP Server Setup

Power này dùng [mcp-system-monitor](https://github.com/huhabla/mcp-system-monitor).

Option A — Clone và chạy trực tiếp (recommended):
```bash
git clone https://github.com/huhabla/mcp-system-monitor.git
cd mcp-system-monitor
uv pip install -e .

# Test
python mcp_system_monitor_server.py
```

Sau đó update mcp.json command thành path tuyệt đối:
```json
{
  "command": "python",
  "args": ["/path/to/mcp-system-monitor/mcp_system_monitor_server.py"]
}
```

Option B — Dùng pip install (nếu package trên PyPI):
```bash
pip install mcp-system-monitor
# Windows: pip install mcp-system-monitor[win32]
```

### 3. Verify

Sau khi cài, test bằng cách hỏi agent:
- "Check GPU status"
- "How much VRAM is available?"

## Available Tools

### GPU Monitoring
- `get_gpu_info` — GPU name, VRAM used/total, temperature, power, utilization %
- `get_system_snapshot` — Complete system state: CPU + GPU + RAM + disk in one call

### Memory Monitoring
- `get_memory_info` — RAM + swap usage
- `get_enhanced_memory_info` — Detailed: buffers, cache, active/inactive, page faults

### CPU Monitoring
- `get_cpu_info` — CPU usage, per-core stats, frequency, temperature
- `monitor_cpu_usage` — Monitor CPU over duration (trend analysis)

### Process Monitoring
- `get_top_processes` — Top processes by CPU or memory usage

### Performance
- `get_io_performance` — Disk I/O metrics, read/write rates
- `get_system_load` — Load averages, context switches
- `get_performance_snapshot` — Complete performance snapshot

## Core Workflow: Pre-deployment VRAM Check

```
User muốn deploy/train model
    → get_gpu_info (check available VRAM)
    → Estimate VRAM needed (xem steering/workflow-vram-estimation.md)
    → So sánh: available vs needed
    ├─ Đủ VRAM → Proceed
    ├─ Thiếu ít → Suggest: quantization, lower batch size, gradient checkpointing
    └─ Thiếu nhiều → Suggest: smaller model, multi-GPU, cloud GPU
```

<HARD-GATE>
LUÔN check GPU status TRƯỚC KHI suggest model config hoặc launch server.
KHÔNG BAO GIỜ skip VRAM estimation — OOM waste nhiều thời gian hơn estimation.
</HARD-GATE>

## Core Workflow: OOM Diagnosis

```
User gặp OOM error
    → get_gpu_info (current VRAM state)
    → get_top_processes (ai đang dùng GPU?)
    → get_memory_info (RAM cũng hết?)
    → Diagnose:
        ├─ GPU VRAM full → Suggest: kill process, reduce batch, quantize
        ├─ RAM full → Suggest: reduce dataset size, streaming, offload
        └─ Cả hai → Suggest: smaller model, gradient checkpointing + offload
```

## Core Workflow: Training Monitoring

```
Training đang chạy
    → get_gpu_info (GPU utilization %)
    ├─ Utilization <30% → Bottleneck ở data loading (→ increase num_workers)
    ├─ Utilization 30-80% → Có thể tăng batch size
    └─ Utilization >90% → Optimal, monitor temperature
    → get_gpu_info (temperature)
    ├─ <80°C → OK
    ├─ 80-90°C → Warning, monitor closely
    └─ >90°C → Throttling risk, reduce load
```

## Connected Skills

| Situation | Skill | Why |
|-----------|-------|-----|
| VRAM không đủ, cần quantize | model-quantization | GGUF/GPTQ/AWQ giảm VRAM |
| Cần optimize training memory | hf-transformers-trainer | Gradient checkpointing, DeepSpeed |
| Cần optimize inference memory | vllm-tgi-inference | gpu-memory-utilization flag |
| Cần Docker GPU setup | docker-gpu-setup | NVIDIA Container Toolkit |
| Cần estimate trước khi serve | sglang-serving, tensorrt-llm | Serving config |
| Fast training, less VRAM | unsloth-training | 70% less VRAM |

## Anti-Patterns

| Agent nghĩ | Thực tế |
|-------------|---------|
| "Model nhỏ, không cần check VRAM" | Mọi model đều cần check. 7B FP16 = 14GB, nhiều GPU chỉ có 8-12GB |
| "nvidia-smi shows 0% = GPU free" | Check VRAM used, không chỉ utilization. Process có thể allocate VRAM mà không compute |
| "OOM = cần GPU lớn hơn" | Thường fix được bằng: quantize, reduce batch, gradient checkpointing |
| "Default config là đủ" | Default batch_size, max_model_len thường quá lớn cho GPU available |
