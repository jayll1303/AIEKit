# Export & Deployment

Export trained YOLO models to production formats and deploy on edge/server/mobile.

## Export Format Decision Table

| Goal | Format | Flag | Speedup | Platform |
|---|---|---|---|---|
| General interop | ONNX | `format=onnx` | ~2-3x CPU | Cross-platform |
| NVIDIA GPU production | TensorRT | `format=engine` | ~3-5x GPU | NVIDIA GPUs |
| Apple devices | CoreML | `format=coreml` | Native | iOS, macOS |
| Mobile (Android/iOS) | TFLite | `format=tflite` | Native | Mobile devices |
| Intel hardware | OpenVINO | `format=openvino` | ~2-3x CPU | Intel CPUs/VPUs |
| Web browser | TF.js | `format=tfjs` | N/A | Browser |
| Edge TPU | Edge TPU | `format=edgetpu` | Native | Google Coral |
| Rockchip NPU | RKNN | `format=rknn` | Native | RK3588/RK3576 |
| Sony IMX500 | IMX | `format=imx` | Native | IMX500 sensor |
| Meta ExecuTorch | ExecuTorch | `format=executorch` | Native | Mobile/edge |

## Export Commands

### Python API

```python
from ultralytics import YOLO

model = YOLO("best.pt")

# ONNX with simplification
model.export(format="onnx", simplify=True, dynamic=True)

# TensorRT FP16
model.export(format="engine", half=True, device=0)

# TensorRT INT8 (requires calibration data)
model.export(format="engine", int8=True, data="data.yaml")

# CoreML with NMS
model.export(format="coreml", nms=True)

# TFLite INT8 quantized
model.export(format="tflite", int8=True, data="data.yaml")

# OpenVINO FP16
model.export(format="openvino", half=True)
```

### CLI

```bash
# ONNX
yolo export model=best.pt format=onnx simplify=True

# TensorRT FP16
yolo export model=best.pt format=engine half=True device=0

# TFLite INT8
yolo export model=best.pt format=tflite int8=True data=data.yaml

# Custom image size
yolo export model=best.pt format=onnx imgsz=320,320
```

## Key Export Arguments

| Argument | Default | Description |
|---|---|---|
| `format` | torchscript | Target export format |
| `imgsz` | 640 | Export image size |
| `half` | False | FP16 quantization |
| `int8` | False | INT8 quantization (needs `data` for calibration) |
| `dynamic` | False | Dynamic input shapes (ONNX) |
| `simplify` | True | Simplify ONNX graph |
| `nms` | False | Include NMS in exported model |
| `batch` | 1 | Export batch size |
| `workspace` | None | TensorRT workspace size (GB) |
| `data` | None | Dataset for INT8 calibration |
| `device` | None | Export device |

## Running Exported Models

Exported models work seamlessly with the same YOLO API:

```python
from ultralytics import YOLO

# Load and run any exported format
model = YOLO("best.onnx")          # ONNX
model = YOLO("best.engine")        # TensorRT
model = YOLO("best.mlpackage")     # CoreML
model = YOLO("best_openvino_model")  # OpenVINO

results = model("image.jpg")
```

## Benchmarking

```python
from ultralytics.utils.benchmarks import benchmark

# Benchmark all export formats
benchmark(model="best.pt", data="data.yaml", imgsz=640, half=True)
```

```bash
yolo benchmark model=best.pt data=data.yaml imgsz=640
```

**Validate:** Compare inference time (ms) and mAP across formats. TensorRT should show significant GPU speedup. ONNX should show CPU speedup over PyTorch.

## Deployment Patterns

### ONNX Runtime Inference (no ultralytics dependency)

```python
import onnxruntime as ort
import numpy as np
import cv2

session = ort.InferenceSession("best.onnx")
img = cv2.imread("image.jpg")
img = cv2.resize(img, (640, 640))
img = img.transpose(2, 0, 1).astype(np.float32) / 255.0
img = np.expand_dims(img, 0)

outputs = session.run(None, {session.get_inputs()[0].name: img})
# Post-process outputs (NMS, etc.)
```

### TensorRT with Dynamic Batching

```python
model = YOLO("best.pt")
model.export(format="engine", half=True, dynamic=True, batch=8)

# Inference with batch
model = YOLO("best.engine")
results = model(["img1.jpg", "img2.jpg", "img3.jpg"])
```

## Export Troubleshooting

```
Export fails?
├─ ONNX export error?
│   ├─ pip install onnx onnxruntime onnxsim
│   └─ Try simplify=False if graph simplification fails
│
├─ TensorRT export error?
│   ├─ Verify: python -c "import tensorrt; print(tensorrt.__version__)"
│   ├─ CUDA version must match TensorRT requirements
│   ├─ Try workspace=4 to limit GPU memory during build
│   └─ FP16 requires GPU with FP16 support (most modern GPUs)
│
├─ CoreML export error?
│   ├─ macOS only — cannot export on Linux/Windows
│   └─ pip install coremltools
│
├─ INT8 calibration fails?
│   ├─ data= must point to valid dataset for calibration
│   └─ fraction=0.5 to use subset for faster calibration
│
└─ Exported model gives different results?
    ├─ FP16/INT8 introduces small numerical differences — expected
    ├─ Check imgsz matches between training and export
    └─ Dynamic shapes may affect batch normalization — test with fixed batch
```
