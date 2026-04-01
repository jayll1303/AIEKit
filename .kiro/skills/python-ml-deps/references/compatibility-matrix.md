# Compatibility Matrix — Full Version Tables

Sources:
- https://docs.nvidia.com/deeplearning/frameworks/support-matrix/
- https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html
- https://github.com/pytorch/pytorch/wiki/PyTorch-Versions

## Triton Container → Component Versions

| Container Tag | CUDA | cuDNN | PyTorch | ONNX RT | TensorRT | Min Driver |
|---|---|---|---|---|---|---|
| 26.02 | 13.1.1 | 9.17 | 2.11.0a0 | 1.21.0 | 10.15.1 | 575+ |
| 26.01 | 13.1.1 | 9.17 | 2.10.0a0 | 1.21.0 | 10.14.1 | 575+ |
| 25.12 | 13.1.0 | 9.17 | 2.10.0a0 | 1.21.0 | 10.13.3 | 575+ |
| 25.10 | 13.0.2 | 9.14 | 2.9.0a0 | 1.21.0 | 10.13.3 | 575+ |
| 25.08 | 13.0.0 | 9.12 | 2.8.0a0 | 1.21.0 | 10.13.2 | 575+ |
| 25.06 | 12.9.1 | 9.10 | 2.8.0a0 | 1.21.0 | 10.11.0 | 575+ |
| 25.03 | 12.8.1 | 9.8 | 2.7.0a0 | 1.21.0 | 10.9.0 | 570+ |
| 25.01 | 12.8.0 | 9.7 | 2.6.0a0 | 1.20.1 | 10.8.0 | 570+ |
| 24.12 | 12.6.3 | 9.6 | 2.6.0a0 | 1.20.1 | 10.6.0 | 560+ |
| 24.10 | 12.6.2 | 9.5 | 2.5.0a0 | 1.19.2 | 10.5.0 | 560+ |
| 24.08 | 12.6 | 9.3 | 2.5.0a0 | 1.18.1 | 10.3.0 | 560+ |
| 24.07 | 12.5.1 | 9.2 | 2.4.0a0 | 1.18.1 | 10.2.0 | 555+ |
| 24.05 | 12.4.1 | 9.1 | 2.4.0a0 | 1.18.0 | 10.0.1 | 545+ |
| 24.01 | 12.3.2 | 8.9 | 2.2.0a0 | 1.16.3 | 8.6.1 | 545+ |

## ONNX Runtime ↔ CUDA ↔ cuDNN

| ONNX RT | CUDA | cuDNN | Notes |
|---|---|---|---|
| 1.20–1.21 | 12.x | 9.x | Default on PyPI. Works with PyTorch >= 2.4 |
| 1.20–1.21 | 11.8 | 8.x | Not on PyPI, separate install |
| 1.19 | 12.x | 9.x | CUDA 12 became PyPI default |
| 1.18.1 | 12.x | 9.x | cuDNN 9 required |
| 1.18.0 | 12.x | 8.x | Last cuDNN 8 + CUDA 12 |
| 1.17 | 12.x | 8.x | C++/C#/Python only |
| 1.14–1.16 | 11.8 | 8.2–8.9 | |
| 1.12–1.13 | 11.4 | 8.2 | |

Key: ORT built with CUDA 11.8 compatible with any 11.x. ORT built with CUDA 12.x compatible with any 12.x. cuDNN 8↔9 NOT compatible.

## PyTorch ↔ CUDA ↔ cuDNN

| PyTorch | CUDA | cuDNN | Python |
|---|---|---|---|
| 2.7 | 11.8, 12.1, 12.4 | 9.1 | 3.9–3.12 |
| 2.6 | 11.8, 12.1, 12.4 | 9.1 | 3.9–3.12 |
| 2.5 | 11.8, 12.1, 12.4 | 8.9/9.x | 3.9–3.12 |
| 2.4 | 11.8, 12.1, 12.4 | 8.9/9.x | 3.8–3.12 |
| 2.3 | 11.8, 12.1 | 8.9 | 3.8–3.11 |
| 2.2 | 11.8, 12.1 | 8.7 | 3.8–3.11 |
| 2.1 | 11.8, 12.1 | 8.7 | 3.8–3.11 |
| 2.0 | 11.7, 11.8 | 8.5 | 3.8–3.11 |

## PyTorch + ONNX RT Coexistence Rules

Both must share same CUDA major AND cuDNN major:
- PyTorch >= 2.4 (cuDNN 9) → ONNX RT >= 1.18.1 (cuDNN 9 build)
- PyTorch <= 2.3 (cuDNN 8) → ONNX RT with cuDNN 8 build
- Preload: `import torch` before `onnxruntime.InferenceSession()` or use `onnxruntime.preload_dlls()`
