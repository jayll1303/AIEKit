# Build & Backends Guide

Building llama.cpp from source, GPU backend configuration (CUDA, Metal, Vulkan), llama-cpp-python installation with GPU support, pre-built binaries, and CPU performance flags.

## Building from Source (CMake)

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y \
  build-essential cmake git

# macOS (Xcode command line tools)
xcode-select --install
```

### Basic CPU Build

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)
```

**Validate:** `./build/bin/llama-cli --version` prints version info. Nếu không → check CMake output cho errors.

Binaries nằm trong `build/bin/`:
- `llama-server` — OpenAI-compatible API server
- `llama-cli` — Interactive chat / batch inference
- `llama-quantize` — Quantize GGUF models
- `llama-perplexity` — Perplexity benchmarking

## CUDA Backend (NVIDIA GPU)

### Prerequisites

- NVIDIA driver ≥ 525.60
- CUDA Toolkit ≥ 11.7 (khuyến nghị 12.x)
- Verify: `nvidia-smi` shows GPU, `nvcc --version` shows CUDA

### Build with CUDA

```bash
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j$(nproc)
```

**Validate:** Server log hiển thị `ggml_cuda_init: found N CUDA devices` khi launch. Nếu không → verify CUDA toolkit installed và `nvcc` trong PATH.

### CUDA Build Options

| CMake Flag | Default | Description |
|---|---|---|
| `-DGGML_CUDA=ON` | OFF | Enable CUDA backend |
| `-DGGML_CUDA_F16=ON` | OFF | FP16 arithmetic trên GPU (nhanh hơn trên Ampere+) |
| `-DGGML_CUDA_PEER_MAX_BATCH_SIZE=128` | 128 | Max batch size cho peer-to-peer GPU transfer |
| `-DCMAKE_CUDA_ARCHITECTURES="86;89"` | auto | Target CUDA compute capabilities |

### Target GPU Architecture

```bash
# Build cho specific GPU (faster compile)
# Ampere=86, Ada=89, Hopper=90, Turing=75, Volta=70
cmake -B build -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES="86"
cmake --build build --config Release -j$(nproc)
```

## Metal Backend (macOS)

Metal được auto-detect trên macOS. Không cần flag đặc biệt.

### Build

```bash
cmake -B build -DGGML_METAL=ON
cmake --build build --config Release -j$(sysctl -n hw.ncpu)
```

⚠️ Trên Apple Silicon (M1/M2/M3/M4), Metal là default backend. `-DGGML_METAL=ON` thường đã enabled tự động.

**Validate:** Server log hiển thị `ggml_metal_init: found device` khi launch.

### Metal Notes

- Apple Silicon share RAM giữa CPU và GPU — `-ngl 99` dùng chung memory pool
- Max "VRAM" = total system RAM (M2 Max 96GB = 96GB cho model)
- M1 Pro/Max/Ultra competitive với mid-range NVIDIA GPUs cho inference

```bash
# macOS Apple Silicon — full GPU offload
llama-server -m model.Q4_K_M.gguf \
  -ngl 99 -c 8192 -fa \
  --host 0.0.0.0 --port 8080
```

## Vulkan Backend

Cross-platform GPU backend — NVIDIA, AMD, Intel GPUs.

```bash
# Ubuntu: install Vulkan SDK
sudo apt-get install -y libvulkan-dev vulkan-tools
vulkaninfo --summary  # Verify

# Build
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j$(nproc)
```

**When to use:** AMD GPU (Linux/Windows), Intel Arc GPU, hoặc cross-platform build. NVIDIA nên dùng CUDA (faster).

## llama-cpp-python Installation

### CPU Only

```bash
pip install llama-cpp-python
```

### With CUDA (NVIDIA GPU)

```bash
CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python --force-reinstall --no-cache-dir
```

⚠️ **HARD GATE:** Verify CUDA toolkit installed trước (`nvcc --version`). Nếu không có → install CUDA toolkit trước hoặc dùng pre-built wheel.

**Validate:**

```python
from llama_cpp import Llama
llm = Llama(model_path="model.gguf", n_gpu_layers=1, verbose=True)
# Log phải hiển thị "offloading 1 layers to GPU"
```

### With Metal (macOS)

```bash
CMAKE_ARGS="-DGGML_METAL=on" pip install llama-cpp-python --force-reinstall --no-cache-dir
```

Trên Apple Silicon, Metal thường auto-detected. Force reinstall nếu GPU không hoạt động.

### With Vulkan

```bash
CMAKE_ARGS="-DGGML_VULKAN=on" pip install llama-cpp-python --force-reinstall --no-cache-dir
```

### Pre-built Wheels (No Build Required)

```bash
# CUDA 12.x pre-built (nếu available)
pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
```

Check available pre-built wheels tại: https://github.com/abetlen/llama-cpp-python/releases

### Server Dependencies

```bash
# Install with server support
pip install "llama-cpp-python[server]"

# Launch server
python -m llama_cpp.server \
  --model ./models/model.Q4_K_M.gguf \
  --n_gpu_layers -1 \
  --host 0.0.0.0 --port 8080
```

## CPU Performance Flags

```bash
# Check CPU features
lscpu | grep -i avx

# Build with CPU optimizations (usually auto-detected)
cmake -B build -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON
cmake --build build --config Release -j$(nproc)
```

| Flag | Description |
|---|---|
| `-DGGML_AVX2=ON` | AVX2 instructions (~2x vs baseline, most modern CPUs) |
| `-DGGML_AVX512=ON` | AVX512 (~1.3x vs AVX2, server CPUs) |
| `-DGGML_FMA=ON` | Fused multiply-add (included with AVX2) |
| `-DGGML_F16C=ON` | FP16 conversion instructions |

⚠️ AVX2/FMA thường enabled by default. Chỉ cần explicit set khi cross-compiling.

### BLAS Backends (CPU)

```bash
# OpenBLAS — tăng tốc matrix ops cho CPU-only inference
sudo apt-get install -y libopenblas-dev
cmake -B build -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS
cmake --build build --config Release -j$(nproc)
```

## Build Troubleshooting

```
Build fails?
├─ CMake not found → sudo apt-get install cmake / brew install cmake
├─ CUDA not found → export CUDA_HOME=/usr/local/cuda && export PATH=$CUDA_HOME/bin:$PATH
├─ Metal errors → xcode-select --install, macOS ≥ 13.0
├─ llama-cpp-python fails → pip install --force-reinstall --no-cache-dir, try pre-built wheel
└─ Slow after build → check lscpu | grep avx2, verify GPU offload in server log
```

## Backend Comparison

| Backend | Platform | GPU Support | Performance | Setup Complexity |
|---|---|---|---|---|
| CUDA | Linux, Windows | NVIDIA only | Best (NVIDIA) | Medium (need CUDA toolkit) |
| Metal | macOS | Apple Silicon | Very good | Low (auto-detected) |
| Vulkan | All platforms | NVIDIA, AMD, Intel | Good | Medium (need Vulkan SDK) |
| CPU (AVX2) | All platforms | None | Baseline | Low (default) |
| OpenBLAS | All platforms | None | Better than baseline | Low |

| Scenario | Recommendation |
|---|---|
| NVIDIA GPU | CUDA (best perf) |
| Apple Silicon | Metal (auto-detected) |
| AMD GPU | Vulkan |
| CPU only | AVX2 + OpenBLAS |
