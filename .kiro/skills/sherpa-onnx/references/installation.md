# sherpa-onnx Installation Guide

## Python Package (Recommended)

### CPU Only (All platforms)
```bash
pip install sherpa-onnx sherpa-onnx-bin
```

Supported: Linux (x64, aarch64, armv7l), macOS (x64, arm64), Windows (x64, x86).

### CUDA 11.8 (Linux/Windows x64)
```bash
# Check available versions: https://k2-fsa.github.io/sherpa/onnx/cuda.html
pip install sherpa-onnx=="1.12.34+cuda" --no-index -f https://k2-fsa.github.io/sherpa/onnx/cuda.html
```

### CUDA 12.8 + cuDNN 9 (Linux/Windows x64)
```bash
pip install sherpa-onnx==1.12.34+cuda12.cudnn9 -f https://k2-fsa.github.io/sherpa/onnx/cuda.html
```

### Chinese Mirror
```bash
pip install --verbose sherpa_onnx_bin sherpa_onnx_core sherpa_onnx --no-index -f https://k2-fsa.github.io/sherpa/onnx/cpu-cn.html
```

### Verify Installation
```bash
python3 -c "import sherpa_onnx; print(sherpa_onnx.__version__)"
which sherpa-onnx
sherpa-onnx --help
```

## Build from Source

### Quick Build
```bash
git clone https://github.com/k2-fsa/sherpa-onnx
cd sherpa-onnx
python3 setup.py install
```

### Developer Build (editable)
```bash
git clone https://github.com/k2-fsa/sherpa-onnx
cd sherpa-onnx
mkdir build && cd build

cmake \
  -DSHERPA_ONNX_ENABLE_PYTHON=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=OFF \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  ..

make -j
export PYTHONPATH=$PWD/../sherpa-onnx/python/:$PWD/lib:$PYTHONPATH
```

### Build with CUDA
```bash
cmake \
  -DSHERPA_ONNX_ENABLE_PYTHON=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DSHERPA_ONNX_ENABLE_GPU=ON \
  ..
```

## Other Languages

| Language | Package/Method |
|----------|---------------|
| C/C++ | Build from source with CMake |
| JavaScript/Node.js | `npm install sherpa-onnx` |
| C# | NuGet: `sherpa-onnx` |
| Java/Kotlin | Maven/Gradle from releases |
| Go | `go get github.com/k2-fsa/sherpa-onnx-go` |
| Swift | SPM or build from source |
| Dart/Flutter | pub.dev: `sherpa_onnx` |
| Rust | crates.io: `sherpa-rs` |
| WebAssembly | Build with Emscripten |

## Platform Support Matrix

| Platform | Arch | CPU | CUDA |
|----------|------|-----|------|
| Linux | x64 | ✔️ | ✔️ |
| Linux | arm64 | ✔️ | — |
| Linux | armv7l | ✔️ | — |
| Linux | riscv64 | ✔️ | — |
| macOS | x64 | ✔️ | — |
| macOS | arm64 | ✔️ | — |
| Windows | x64 | ✔️ | ✔️ |
| Windows | x86 | ✔️ | — |
| Android | arm64/arm32/x64 | ✔️ | — |
| iOS | arm64 | ✔️ | — |
| HarmonyOS | arm64/x64 | ✔️ | — |

## NPU Support

| NPU | Status |
|-----|--------|
| Rockchip RKNN | ✔️ |
| Qualcomm QNN | ✔️ |
| Ascend NPU | ✔️ |
| Axera NPU | ✔️ |

## Troubleshooting

```
pip install fails?
├─ "No matching distribution"
│   └─ Check Python version (≥3.6) and platform support
├─ CUDA wheel not found
│   └─ Use --no-index -f URL, check exact version string
└─ Permission denied
    └─ Use --user flag or virtual environment
```

## Useful Links

- Docs: https://k2-fsa.github.io/sherpa/onnx/
- GitHub: https://github.com/k2-fsa/sherpa-onnx
- PyPI: https://pypi.org/project/sherpa-onnx/
- Pre-built wheels: https://k2-fsa.github.io/sherpa/onnx/cpu.html
- CUDA wheels: https://k2-fsa.github.io/sherpa/onnx/cuda.html
