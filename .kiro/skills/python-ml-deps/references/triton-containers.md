# Triton Inference Server — Container Selection Guide

## NGC Container Tags

```bash
# Format
nvcr.io/nvidia/tritonserver:<YY.MM>-py3              # Standard (all backends)
nvcr.io/nvidia/tritonserver:<YY.MM>-trtllm-python-py3 # With TensorRT-LLM + vLLM

# Examples
docker pull nvcr.io/nvidia/tritonserver:25.01-py3
docker pull nvcr.io/nvidia/tritonserver:24.07-py3
```

## How to Choose a Container

### By driver version
```bash
nvidia-smi  # Check "Driver Version" and "CUDA Version"
```
- Driver 575+ → any 25.xx or 26.xx container
- Driver 570+ → 25.01–25.03
- Driver 560+ → 24.08–24.12
- Driver 555+ → 24.07
- Driver 545+ → 24.01–24.06
- Older → 23.xx containers

### By ONNX Runtime version needed
- ORT 1.21.0 → 25.01+ containers
- ORT 1.20.1 → 24.12, 25.01
- ORT 1.19.2 → 24.09–24.11
- ORT 1.18.x → 24.06–24.08
- ORT 1.17.3 → 24.05
- ORT 1.16.3 → 23.12, 24.01

### By PyTorch version needed
- PyTorch 2.8+ → 25.06+
- PyTorch 2.7 → 25.03–25.04
- PyTorch 2.6 → 24.12–25.01
- PyTorch 2.5 → 24.08–24.10
- PyTorch 2.4 → 24.05–24.07

### By GPU architecture
- Blackwell (B200, GB200) → 25.01+ (CUDA 12.8+)
- Hopper (H100, H200) → 23.01+
- Ada Lovelace (L40, RTX 4090) → 22.09+
- Ampere (A100, A10) → 21.02+
- Turing (T4) → 20.01+

## Community / Custom Images

| Image | Base | Pre-installed extras |
|---|---|---|
| `soar97/triton-k2:24.07` | tritonserver:24.07-py3 | k2, kaldifeat, icefall, sentencepiece |

## Docker Run Template

```bash
docker run --gpus all --rm \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  --shm-size=1g --ulimit memlock=-1 \
  -v $(pwd)/model_repo:/models \
  nvcr.io/nvidia/tritonserver:24.07-py3 \
  tritonserver --model-repository=/models
```

## Tritonserver Key CLI Options

```
--model-repository=<path>           # Required
--http-port=<port>                  # Default 8000
--grpc-port=<port>                  # Default 8001
--metrics-port=<port>               # Default 8002
--log-verbose=<0-3>                 # Debug logging
--model-control-mode=<none|poll|explicit>
--strict-model-config=<bool>        # Require config.pbtxt
--pinned-memory-pool-byte-size=<N>
--cuda-memory-pool-byte-size=<gpu>:<N>
--exit-on-error=<bool>
```

## Health Checks

```bash
curl localhost:8000/v2/health/ready
curl localhost:8000/v2/models
curl localhost:8000/v2/models/<name>/ready
```
