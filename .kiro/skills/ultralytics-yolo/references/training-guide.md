# Training Guide

Custom dataset preparation, training configuration, and optimization for all YOLO tasks.

## data.yaml Templates

### Detection

```yaml
path: /path/to/dataset
train: images/train
val: images/val
names:
  0: person
  1: car
  2: bicycle
```

Label format (one `.txt` per image, one line per object):
```
class_id x_center y_center width height
# Example: 0 0.5 0.5 0.3 0.4
```

### Segmentation

Same data.yaml as detection. Label format includes polygon points:
```
class_id x1 y1 x2 y2 x3 y3 ... xn yn
# All coordinates normalized 0-1
```

### Pose Estimation

```yaml
path: /path/to/dataset
train: images/train
val: images/val
kpt_shape: [17, 3]  # [num_keypoints, dims] — 3 = x,y,visibility
names:
  0: person
```

Label format:
```
class_id x_center y_center w h kp1_x kp1_y kp1_v kp2_x kp2_y kp2_v ...
# visibility: 0=not labeled, 1=labeled but occluded, 2=labeled and visible
```

### Classification

No data.yaml needed. Use ImageNet-style folder structure:
```
dataset/
├── train/
│   ├── class_a/
│   │   ├── img1.jpg
│   │   └── img2.jpg
│   └── class_b/
│       └── img3.jpg
└── val/
    ├── class_a/
    └── class_b/
```

### OBB (Oriented Bounding Boxes)

```yaml
path: /path/to/dataset
train: images/train
val: images/val
names:
  0: plane
  1: ship
```

Label format (DOTA format — 4 corner points):
```
class_id x1 y1 x2 y2 x3 y3 x4 y4
# All coordinates normalized 0-1
```

## Training Configuration

### Key Training Arguments

| Argument | Default | Description |
|---|---|---|
| `epochs` | 100 | Total training epochs |
| `batch` | 16 | Batch size. `-1` = auto 60% GPU, `0.7` = auto 70% GPU |
| `imgsz` | 640 | Input image size (square) |
| `patience` | 100 | Early stopping patience (epochs without improvement) |
| `lr0` | 0.01 | Initial learning rate |
| `lrf` | 0.01 | Final LR as fraction of lr0 |
| `optimizer` | auto | SGD, MuSGD, Adam, AdamW, NAdam, RAdam, RMSProp, auto |
| `device` | None | `0`, `[0,1]`, `cpu`, `mps`, `-1` (auto idle GPU) |
| `freeze` | None | Freeze first N layers (for transfer learning) |
| `resume` | False | Resume from last checkpoint |
| `amp` | True | Automatic Mixed Precision |
| `cache` | False | Cache images: `True`/`ram`, `disk`, `False` |
| `fraction` | 1.0 | Fraction of dataset to use |
| `cos_lr` | False | Cosine learning rate scheduler |
| `close_mosaic` | 10 | Disable mosaic in last N epochs |

### Multi-GPU Training

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")
# Explicit GPU selection
results = model.train(data="data.yaml", epochs=100, device=[0, 1])

# Auto-select most idle GPUs
results = model.train(data="data.yaml", epochs=100, device=[-1, -1])
```

```bash
# CLI
yolo train data=data.yaml model=yolo26n.pt device=0,1
yolo train data=data.yaml model=yolo26n.pt device=-1,-1
```

⚠️ Custom trainers/datasets with multi-GPU require manual DDP launch:
```bash
python -m torch.distributed.run --nproc_per_node 2 train_script.py
```

### Resume Training

```python
model = YOLO("path/to/last.pt")
results = model.train(resume=True)
```

```bash
yolo train resume model=path/to/last.pt
```

### Transfer Learning (Freeze Layers)

```python
model = YOLO("yolo26n.pt")
# Freeze backbone (first 10 layers)
results = model.train(data="data.yaml", epochs=50, freeze=10)
```

Useful when: small dataset, want to keep pretrained features, only fine-tune head.

## Augmentation Tuning

### Key Augmentation Arguments

| Argument | Default | Effect |
|---|---|---|
| `mosaic` | 1.0 | Combine 4 images. Reduce for small datasets |
| `mixup` | 0.0 | Blend 2 images. Good for regularization |
| `copy_paste` | 0.0 | Copy objects between images (segment only) |
| `hsv_h` | 0.015 | Hue variation |
| `hsv_s` | 0.7 | Saturation variation |
| `hsv_v` | 0.4 | Brightness variation |
| `degrees` | 0.0 | Rotation range |
| `translate` | 0.1 | Translation fraction |
| `scale` | 0.5 | Scale variation |
| `fliplr` | 0.5 | Horizontal flip probability |
| `flipud` | 0.0 | Vertical flip probability |
| `erasing` | 0.4 | Random erasing (classify only) |

### Augmentation Strategy by Dataset Size

| Dataset Size | Recommended Settings |
|---|---|
| < 500 images | `mosaic=0.0, mixup=0.0, close_mosaic=0` — augmentation can hurt |
| 500-5000 images | Default settings, consider `mosaic=0.5` |
| 5000-50000 images | Default settings work well |
| > 50000 images | Can increase `mixup=0.1`, `copy_paste=0.1` |

### Custom Albumentations

```python
from ultralytics import YOLO
import albumentations as A

model = YOLO("yolo26n.pt")
results = model.train(
    data="data.yaml",
    epochs=100,
    augmentations=[
        A.CLAHE(p=0.5),
        A.RandomBrightnessContrast(p=0.5),
        A.GaussNoise(p=0.3),
    ],
)
```

## Dataset Validation Checklist

```
Dataset issues?
├─ Images and labels count mismatch?
│   └─ Each image MUST have a corresponding .txt label file (empty file = no objects)
│
├─ Label coordinates out of range?
│   └─ All values must be 0.0-1.0 (normalized). Check for absolute pixel values.
│
├─ Class IDs don't match data.yaml?
│   └─ Class IDs in labels must be 0-indexed and match names dict in data.yaml
│
├─ Images in wrong format?
│   └─ Supported: jpg, jpeg, png, bmp, tif, tiff, dng, webp, mpo, pfm
│
├─ Path issues in data.yaml?
│   ├─ Use absolute paths or paths relative to data.yaml location
│   └─ Verify: images/train and images/val directories exist
│
└─ Corrupted images?
    └─ Run: yolo checks to verify dataset integrity
```

## Logging & Experiment Tracking

Ultralytics supports automatic logging to:

| Platform | Setup |
|---|---|
| TensorBoard | `tensorboard --logdir runs/` (auto-enabled) |
| Comet | `pip install comet_ml; comet_ml.init()` |
| ClearML | `pip install clearml; clearml.browser_login()` |
| W&B | `pip install wandb; wandb.init()` |

Training outputs are saved to `runs/<task>/train/` by default:
- `weights/best.pt` — best model by val mAP
- `weights/last.pt` — last epoch checkpoint
- `results.csv` — per-epoch metrics
- `results.png` — training curves plot
- `confusion_matrix.png` — validation confusion matrix
