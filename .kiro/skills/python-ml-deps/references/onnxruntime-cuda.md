# ONNX Runtime ↔ CUDA Integration

## Install Patterns

```bash
# CUDA 12 (default since ORT 1.19)
pip install onnxruntime-gpu

# CUDA 11.8 (not on PyPI since ORT 1.19)
pip install onnxruntime-gpu --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-11/pypi/simple/

# With bundled CUDA/cuDNN (ORT 1.21+)
pip install onnxruntime-gpu[cuda,cudnn]

# CRITICAL: "onnxruntime" (no -gpu) does NOT include CUDA support
```

## CUDAExecutionProvider Not Available — Diagnosis

```python
import onnxruntime as ort
print(ort.get_available_providers())
# Should include 'CUDAExecutionProvider'
# If only 'CPUExecutionProvider': wrong package or CUDA not found
```

Fixes in order:
1. Install `onnxruntime-gpu`, not `onnxruntime`
2. Check CUDA toolkit installed: `nvcc --version`
3. If PyTorch installed, import it first: `import torch` then `import onnxruntime`
4. Use `onnxruntime.preload_dlls()` (ORT 1.21+)
5. Check CUDA major version match (ORT built with 11 vs system has 12)

## PyTorch + ONNX RT DLL Loading

When both PyTorch and ONNX RT are in the same environment, CUDA/cuDNN DLLs can conflict.

```python
# Method 1: Import torch first (it preloads its CUDA/cuDNN)
import torch
import onnxruntime as ort
session = ort.InferenceSession("model.onnx", providers=["CUDAExecutionProvider"])

# Method 2: Explicit preload (ORT 1.21+)
import onnxruntime as ort
ort.preload_dlls()
session = ort.InferenceSession("model.onnx", providers=["CUDAExecutionProvider"])

# Method 3: Load from specific directory
import onnxruntime as ort
ort.preload_dlls(directory="")  # Search NVIDIA site-packages
```

## CUDA EP Configuration Options

```python
providers = [
    ("CUDAExecutionProvider", {
        "device_id": 0,
        "arena_extend_strategy": "kNextPowerOfTwo",
        "gpu_mem_limit": 2 * 1024 * 1024 * 1024,  # 2GB
        "cudnn_conv_algo_search": "EXHAUSTIVE",
        "do_copy_in_default_stream": True,
        "cudnn_conv_use_max_workspace": 1,
        "use_tf32": 1,  # TF32 on Ampere+ (default enabled)
    }),
    "CPUExecutionProvider",  # Fallback
]
session = ort.InferenceSession("model.onnx", providers=providers)
```

## TensorRT EP (Optional Acceleration)

```python
providers = [
    ("TensorrtExecutionProvider", {
        "trt_max_workspace_size": 1 << 30,  # 1GB
        "trt_fp16_enable": True,
    }),
    ("CUDAExecutionProvider", {}),
    "CPUExecutionProvider",
]
```

TRT EP builds engine on first run (slow), then caches. Engine NOT portable across GPU architectures.

## ONNX Opset Support

| ONNX RT | Max Opset |
|---|---|
| 1.21 | 21 |
| 1.20 | 20 |
| 1.19 | 20 |
| 1.18 | 20 |
| 1.17 | 19 |
| 1.16 | 19 |
| 1.15 | 18 |

If model uses higher opset than ORT supports → load error. Fix: downgrade opset or upgrade ORT.
