---
name: ultralytics-yolo
description: "Train, predict, export, and deploy YOLO models with Ultralytics. Use when running yolo train/predict/val/export, building custom object detection/segmentation/classification/pose/OBB pipelines, preparing data.yaml datasets, or deploying YOLO to ONNX/TensorRT/CoreML/edge devices."
---

# Ultralytics YOLO

Train, validate, predict, and export YOLO models (YOLOv8, YOLO11, YOLO26) for detection, segmentation, classification, pose estimation, and oriented bounding boxes (OBB). Covers CLI and Python API, custom dataset preparation, model export, and built-in solutions (counting, tracking, heatmaps).

## Scope

This skill handles:
- Training YOLO models on custom datasets with data.yaml configuration
- Running inference (predict) on images, videos, streams, and directories
- Validating model accuracy with val mode and interpreting metrics (mAP, precision, recall)
- Exporting models to ONNX, TensorRT, CoreML, TFLite, OpenVINO, and 15+ formats
- Using built-in solutions: object counting, speed estimation, heatmaps, queue management
- Multi-GPU and Apple Silicon (MPS) training
- Object tracking with BoT-SORT and ByteTrack

Does NOT handle:
- Building custom YOLO architectures from scratch (use Ultralytics docs directly)
- Deploying models on Triton Inference Server (→ triton-deployment)
- Building GPU Docker containers for YOLO (→ docker-gpu-setup)
- Resolving CUDA/cuDNN version conflicts (→ python-ml-deps)
- Serving YOLO behind an API server like vLLM/TGI (→ vllm-tgi-inference)

## When to Use

- Training a YOLO model on a custom dataset (detection, segmentation, pose, classify, OBB)
- Running object detection/segmentation inference on images or video
- Exporting a trained YOLO model to ONNX, TensorRT, or edge formats
- Setting up a data.yaml file for custom dataset training
- Choosing the right YOLO model size (n/s/m/l/x) for speed vs accuracy
- Using YOLO solutions like object counting, heatmaps, or speed estimation
- Tracking objects across video frames with YOLO + BoT-SORT/ByteTrack
- Validating model performance and interpreting mAP metrics

## Model Selection Table

| Model | Params | mAP50-95 (COCO) | Speed (ms) | Best For |
|---|---|---|---|---|
| yolo26n / yolo11n | ~2.6M | ~39-41 | ~1.5 | Edge devices, real-time, mobile |
| yolo26s / yolo11s | ~9.4M | ~46-47 | ~2.5 | Balanced speed/accuracy |
| yolo26m / yolo11m | ~20M | ~51-52 | ~5 | General production use |
| yolo26l / yolo11l | ~25M | ~53 | ~6 | High accuracy requirements |
| yolo26x / yolo11x | ~57M | ~54-55 | ~12 | Maximum accuracy, server-side |

**Suffix convention**: no suffix = detect, `-seg` = segment, `-cls` = classify, `-pose` = pose, `-obb` = OBB.
Example: `yolo26n-seg.pt`, `yolo11m-pose.pt`, `yolo26s-cls.pt`

## Task Decision Table

| Task | Suffix | Output | data.yaml Key | Use Case |
|---|---|---|---|---|
| Detection | (none) | Bounding boxes + class + conf | `names: {0: cat, 1: dog}` | Object localization |
| Segmentation | `-seg` | Boxes + pixel masks | Same as detect | Precise object boundaries |
| Classification | `-cls` | Class probabilities | Folder structure (ImageNet-style) | Image-level classification |
| Pose Estimation | `-pose` | Boxes + keypoints | `kpt_shape: [17, 3]` | Body/hand/face keypoints |
| Oriented BBox | `-obb` | Rotated bounding boxes | DOTA format labels | Aerial/satellite imagery |

## Quick Start: Python API

### Install

```bash
pip install ultralytics
```

### Train on Custom Dataset

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")  # load pretrained model
results = model.train(
    data="path/to/data.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    device=0,  # GPU 0, or [0,1] for multi-GPU, or "mps" for Apple Silicon
)
```

**Validate:** Check `runs/detect/train/results.csv` exists and loss is decreasing. If training fails with OOM → reduce `batch` or `imgsz`.

### Predict

```python
from ultralytics import YOLO

model = YOLO("path/to/best.pt")
results = model("image.jpg")  # or video, directory, URL, stream

for r in results:
    print(r.boxes.xyxy)   # bounding boxes [x1, y1, x2, y2]
    print(r.boxes.conf)   # confidence scores
    print(r.boxes.cls)    # class indices
    r.save(filename="result.jpg")
```

### Export

```python
from ultralytics import YOLO

model = YOLO("best.pt")
model.export(format="onnx")       # ONNX
model.export(format="engine")     # TensorRT
model.export(format="coreml")     # CoreML
model.export(format="tflite")     # TFLite for mobile
```

**Validate:** Exported file exists in same directory. Test with `YOLO("best.onnx")("image.jpg")`.

## Quick Start: CLI

```bash
# Train
yolo detect train data=data.yaml model=yolo26n.pt epochs=100 imgsz=640

# Predict
yolo detect predict model=best.pt source="path/to/images/"

# Validate
yolo detect val model=best.pt data=data.yaml

# Export
yolo export model=best.pt format=onnx

# Track
yolo detect track model=best.pt source="video.mp4" tracker=botsort.yaml

# Solutions
yolo solutions count source="video.mp4" show=True
```

**CLI syntax**: `yolo [TASK] [MODE] [ARGS]` where TASK = detect|segment|classify|pose|obb, MODE = train|val|predict|export|track|benchmark.

## data.yaml Format

```yaml
# data.yaml for custom detection dataset
path: /path/to/dataset    # dataset root
train: images/train        # train images (relative to path)
val: images/val            # val images (relative to path)
test: images/test          # test images (optional)

# Classes
names:
  0: person
  1: car
  2: bicycle
```

**Dataset directory structure:**
```
dataset/
├── images/
│   ├── train/
│   │   ├── img001.jpg
│   │   └── img002.jpg
│   └── val/
│       ├── img003.jpg
│       └── img004.jpg
├── labels/
│   ├── train/
│   │   ├── img001.txt    # class x_center y_center width height (normalized)
│   │   └── img002.txt
│   └── val/
│       ├── img003.txt
│       └── img004.txt
└── data.yaml
```

**Label format** (per line): `class_id x_center y_center width height` — all values normalized 0-1.

## Diagnostic Checklist

```
Training fails or poor results?
├─ OOM error?
│   ├─ Reduce batch size: batch=8 or batch=-1 (auto)
│   ├─ Reduce imgsz: imgsz=416 or imgsz=320
│   └─ Use smaller model: yolo26n instead of yolo26l
│
├─ Low mAP after training?
│   ├─ Check dataset: labels match images? Class IDs correct?
│   ├─ Increase epochs (at least 100 for small datasets)
│   ├─ Check class balance — use plots=True to visualize
│   ├─ Try larger model or increase imgsz
│   └─ Verify augmentation settings (mosaic, mixup)
│
├─ Training loss not decreasing?
│   ├─ Check data.yaml paths — images and labels must align
│   ├─ Verify label format: normalized coordinates, correct class IDs
│   ├─ Lower lr0 if loss oscillates
│   └─ Check for corrupted images
│
├─ Export fails?
│   ├─ ONNX: pip install onnx onnxruntime
│   ├─ TensorRT: requires tensorrt package + compatible CUDA
│   ├─ CoreML: macOS only, pip install coremltools
│   └─ Check model compatibility with target format
│
└─ Prediction gives wrong results?
    ├─ Check conf threshold: conf=0.25 (default), lower for more detections
    ├─ Check iou threshold: iou=0.7 (default NMS)
    ├─ Verify model was trained on similar data distribution
    └─ Check imgsz matches training imgsz
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "yolo26x gives best results, always use it" | Larger models need more VRAM, train slower, and may overfit on small datasets. Match model size to dataset size and deployment target. yolo26n/s is often sufficient. |
| "Default augmentation is fine for all datasets" | Mosaic + mixup can hurt on small datasets (<500 images). Consider `mosaic=0.0` for very small datasets. Always check augmented samples with `plots=True`. |
| "I'll train for 300 epochs to be safe" | Use `patience=50` (early stopping). If val loss plateaus for 50 epochs, more training won't help. Check learning curves in `results.csv`. |
| "Export to TensorRT always gives speedup" | TensorRT requires matching CUDA version and GPU architecture. FP16 export needs GPU with FP16 support. Always benchmark exported model vs PyTorch baseline. |
| "Labels don't need to be normalized" | YOLO format requires normalized coordinates (0-1). Absolute pixel coordinates will cause silent training failures with garbage predictions. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need GPU Docker container for YOLO training | docker-gpu-setup | NGC base images, docker-compose GPU passthrough |
| CUDA/PyTorch version conflicts when installing ultralytics | python-ml-deps | Resolves CUDA index URLs, driver compatibility |
| Want to deploy exported ONNX/TensorRT model on Triton | triton-deployment | config.pbtxt, model repository, ensemble pipelines |
| Need to track experiments (loss, mAP) across runs | experiment-tracking | MLflow/W&B setup for YOLO training runs |
| Working in Jupyter notebook with YOLO | notebook-workflows | .ipynb creation, cell management, Colab GPU |

## References

- [Dataset Preparation](references/dataset-preparation.md) — End-to-end dataset pipeline: class design, data collection, annotation tools (Roboflow/CVAT/Label Studio), folder structure, label formats, COCO-to-YOLO conversion, auto-annotation with SAM
  **Load when:** building a custom dataset from scratch, choosing annotation tools, structuring folders, or converting from other formats
- [Training Guide](references/training-guide.md) — data.yaml templates for all 5 tasks, training arguments, multi-GPU/MPS, resume, freeze layers, augmentation tuning by dataset size, experiment logging
  **Load when:** configuring training runs, writing data.yaml, setting up augmentation, or multi-GPU training
- [Best Practices & Config](references/best-practices-config.md) — YOLO26 official training recipe, fine-tuning strategies by dataset size, hyperparameter tuning with model.tune(), training performance optimization, monitoring metrics, diagnosing convergence issues
  **Load when:** optimizing training performance, tuning hyperparameters, diagnosing training issues, or following official YOLO26 recipes
- [Export & Deployment](references/export-deployment.md) — All export formats with flags, TensorRT optimization, ONNX simplification, edge deployment (TFLite, CoreML, OpenVINO), benchmarking
  **Load when:** exporting models or deploying to edge/mobile/server
- [Solutions & Analytics](references/solutions-analytics.md) — Object counting, heatmaps, speed estimation, queue management, workout monitoring, tracking configuration
  **Load when:** using YOLO built-in solutions or setting up object tracking
- [Results API](references/results-api.md) — Results object structure, accessing boxes/masks/keypoints/probs/obb, plotting, saving, converting to numpy/pandas
  **Load when:** processing prediction results programmatically or building custom post-processing pipelines
