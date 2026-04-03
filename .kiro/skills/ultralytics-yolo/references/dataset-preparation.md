# Dataset Preparation

End-to-end guide for collecting, annotating, structuring, and validating datasets for YOLO training.

## Dataset Pipeline Overview

```
1. Define classes → 2. Collect images → 3. Annotate → 4. Structure folders → 5. Create data.yaml → 6. Validate
```

## Step 1: Define Classes

### Class Design Decision Table

| Approach | Example | When to Use |
|---|---|---|
| Coarse classes | "vehicle", "person" | Quick prototyping, binary detection |
| Fine classes | "sedan", "SUV", "truck", "motorcycle" | Production systems needing granularity |
| Hierarchical | "vehicle/sedan", "vehicle/truck" | Complex taxonomies (flatten for YOLO) |

**Rules:**
- Start with fine-grained classes — easier to merge later than to split
- YOLO class IDs are 0-indexed: first class = 0, second = 1, etc.
- Keep class count reasonable: 1-80 classes typical, >200 gets challenging
- Ensure every class has sufficient examples (minimum ~100 images per class)

### Minimum Dataset Size Guidelines

| Dataset Size | Expected Performance | Notes |
|---|---|---|
| 50-100 images/class | Proof of concept | Use pretrained weights + freeze backbone |
| 100-500 images/class | Decent for simple tasks | Transfer learning recommended |
| 500-2000 images/class | Good production quality | Default augmentation works well |
| 2000-10000 images/class | High accuracy | Can train from scratch if needed |
| 10000+ images/class | State-of-the-art | Match COCO-level training recipes |

## Step 2: Collect Images

### Data Sources

| Source | Pros | Cons |
|---|---|---|
| Roboflow Universe | Pre-annotated, YOLO export ready | May not match your domain |
| COCO, VOC, ImageNet | Standard benchmarks, high quality | Generic, may need filtering |
| Custom capture (camera/drone) | Exact domain match | Requires annotation effort |
| Web scraping | Large volume, diverse | Noisy, needs cleaning |
| Synthetic data (Unity, Blender) | Unlimited volume, perfect labels | Domain gap with real data |

### Avoiding Bias Checklist

- [ ] Images from multiple locations/environments
- [ ] Varied lighting conditions (day, night, indoor, outdoor)
- [ ] Different camera angles and distances
- [ ] Balanced class representation (no class >10x another)
- [ ] Include edge cases (occlusion, truncation, small objects)
- [ ] Diverse backgrounds (not all same scene)

## Step 3: Annotate

### Annotation Tools Decision Table

| Tool | Best For | Export YOLO? | Free? |
|---|---|---|---|
| Roboflow | Full pipeline (annotate → augment → export) | ✅ native | Free tier |
| CVAT | Complex projects, team collaboration | ✅ native | ✅ open-source |
| Label Studio | Multi-task annotation, ML-assisted | ✅ with plugin | ✅ open-source |
| LabelImg | Simple bbox annotation | ✅ native YOLO | ✅ open-source |
| Labelme | Polygon/mask annotation | Needs conversion | ✅ open-source |
| Ultralytics Platform | Cloud annotation + SAM auto-label | ✅ native | Free tier |

### Auto-Annotation with YOLO + SAM

To speed up annotation, use a pretrained YOLO model to generate initial labels:

```python
from ultralytics.data.annotator import auto_annotate

# Auto-annotate using YOLO detection + SAM segmentation
auto_annotate(
    data="path/to/images",
    det_model="yolo26n.pt",
    sam_model="sam_b.pt",
    output_dir="path/to/labels",
)
```

Then review and correct in your annotation tool.

### Annotation Quality Rules

- Every object of interest MUST be labeled — missing labels teach the model to ignore objects
- Bounding boxes should be tight around the object (no excessive padding)
- For segmentation: polygon should follow object boundary closely
- Empty images (no objects) should have empty `.txt` label files, not missing files
- Consistent labeling across annotators — use clear guidelines with visual examples

## Step 4: Structure Dataset

### Detection / Segmentation / OBB

```
my-dataset/
├── images/
│   ├── train/          # 70-80% of images
│   │   ├── img001.jpg
│   │   └── img002.jpg
│   ├── val/            # 15-20% of images
│   │   └── img003.jpg
│   └── test/           # 5-10% (optional)
│       └── img004.jpg
├── labels/
│   ├── train/          # matching .txt files
│   │   ├── img001.txt
│   │   └── img002.txt
│   ├── val/
│   │   └── img003.txt
│   └── test/
│       └── img004.txt
└── data.yaml
```

**Critical:** `images/` and `labels/` must mirror each other. `img001.jpg` → `img001.txt`.

### Classification

```
my-cls-dataset/
├── train/
│   ├── cat/
│   │   ├── img001.jpg
│   │   └── img002.jpg
│   └── dog/
│       └── img003.jpg
└── val/
    ├── cat/
    └── dog/
```

No data.yaml needed — folder names = class names.

### Train/Val/Test Split Guidelines

| Split | Percentage | Purpose |
|---|---|---|
| Train | 70-80% | Model learning |
| Val | 15-20% | Hyperparameter tuning, early stopping |
| Test | 5-10% | Final unbiased evaluation (optional) |

**Rules:**
- Never leak val/test images into train
- Stratify by class if dataset is imbalanced
- If images are from video, keep all frames from same video in same split
- Shuffle before splitting to avoid temporal/spatial bias

## Step 5: Label Format Reference

### Detection (one line per object)

```
# class_id x_center y_center width height
# All values normalized 0.0 - 1.0
0 0.481719 0.634028 0.690625 0.713278
1 0.741094 0.524306 0.314750 0.933389
```

**Conversion from absolute pixels:**
```python
x_center = (x_min + x_max) / 2 / img_width
y_center = (y_min + y_max) / 2 / img_height
width = (x_max - x_min) / img_width
height = (y_max - y_min) / img_height
```

### Segmentation (polygon points)

```
# class_id x1 y1 x2 y2 x3 y3 ... xn yn
0 0.681 0.242 0.773 0.258 0.831 0.396 0.776 0.523 0.623 0.453
```

### Pose (keypoints)

```
# class_id x_center y_center w h kp1_x kp1_y kp1_vis kp2_x kp2_y kp2_vis ...
# visibility: 0=not labeled, 1=occluded, 2=visible
0 0.48 0.63 0.69 0.71 0.52 0.28 2 0.54 0.29 2 0.49 0.30 1
```

### OBB (4 corner points)

```
# class_id x1 y1 x2 y2 x3 y3 x4 y4
0 0.78 0.23 0.92 0.28 0.89 0.45 0.75 0.40
```

## Step 6: Validate Dataset

### Quick Validation Script

```python
from ultralytics import YOLO

# Dry-run training to validate dataset
model = YOLO("yolo26n.pt")
model.train(data="data.yaml", epochs=1, imgsz=640, plots=True)
# Check runs/detect/train/ for:
# - labels.jpg (class distribution)
# - train_batch0.jpg (augmented samples with labels overlaid)
```

### Common Dataset Errors

```
Dataset validation fails?
├─ "No labels found"
│   ├─ Check labels/ directory exists and mirrors images/
│   ├─ Label files must be .txt with same name as image
│   └─ Empty images need empty .txt files (not missing files)
│
├─ "Image not found"
│   ├─ Check paths in data.yaml (absolute or relative to yaml location)
│   ├─ Verify image extensions match (jpg vs jpeg vs png)
│   └─ No spaces in file paths
│
├─ "Class X not in data.yaml"
│   ├─ Class IDs in labels must match names dict in data.yaml
│   └─ IDs are 0-indexed: if 3 classes, valid IDs are 0, 1, 2
│
├─ Bounding boxes look wrong after training
│   ├─ Coordinates must be normalized (0.0-1.0), not absolute pixels
│   ├─ Format is x_center y_center width height, NOT x_min y_min x_max y_max
│   └─ Verify with plots=True — check train_batch0.jpg
│
├─ Very low mAP despite correct labels
│   ├─ Check class balance — severely imbalanced classes hurt performance
│   ├─ Verify annotation quality — inconsistent labels confuse the model
│   ├─ Check for duplicate images across train/val splits
│   └─ Ensure sufficient images per class (minimum ~100)
│
└─ Corrupted images
    ├─ Run: from PIL import Image; Image.open("img.jpg").verify()
    └─ Remove or replace corrupted files before training
```

### COCO JSON to YOLO Conversion

If your annotations are in COCO JSON format:

```python
from ultralytics.data.converter import convert_coco

convert_coco(
    labels_dir="path/to/coco/annotations/",
    save_dir="path/to/yolo/labels/",
    use_segments=False,  # True for segmentation
    use_keypoints=False,  # True for pose
)
```

### Roboflow Export

To export from Roboflow directly into training:

```python
from roboflow import Roboflow

rf = Roboflow(api_key="YOUR_API_KEY")
project = rf.workspace("workspace").project("project")
dataset = project.version(1).download("yolov8")
# Creates data.yaml + images/ + labels/ ready for training
```
