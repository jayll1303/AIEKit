# Results API

Working with YOLO prediction results: accessing detections, masks, keypoints, and post-processing.

## Results Object Structure

Every prediction returns a list of `Results` objects (one per image):

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")
results = model("image.jpg")

r = results[0]  # first image result
r.boxes          # Boxes object — bounding boxes
r.masks          # Masks object — segmentation masks (seg models)
r.keypoints      # Keypoints object — pose keypoints (pose models)
r.probs          # Probs object — classification probabilities (cls models)
r.obb            # OBB object — oriented bounding boxes (obb models)
r.orig_img       # Original image as numpy array
r.orig_shape     # Original image shape (h, w)
r.path           # Path to image file
r.speed          # Dict with preprocess, inference, postprocess times (ms)
r.names          # Dict of class names {0: 'person', 1: 'car', ...}
```

## Boxes (Detection)

```python
boxes = r.boxes

boxes.xyxy       # [N, 4] tensor — x1, y1, x2, y2 (absolute pixels)
boxes.xywh       # [N, 4] tensor — x_center, y_center, width, height
boxes.xyxyn      # [N, 4] tensor — normalized xyxy (0-1)
boxes.xywhn      # [N, 4] tensor — normalized xywh (0-1)
boxes.conf       # [N] tensor — confidence scores
boxes.cls        # [N] tensor — class indices
boxes.id         # [N] tensor — track IDs (only with tracking)
boxes.data       # [N, 6+] tensor — raw data (xyxy, conf, cls, [track_id])
```

### Common Patterns

```python
# Filter by confidence
high_conf = [b for b in r.boxes if b.conf > 0.5]

# Filter by class
persons = r.boxes[r.boxes.cls == 0]

# Convert to numpy
boxes_np = r.boxes.xyxy.cpu().numpy()

# Get class names
for box in r.boxes:
    cls_id = int(box.cls)
    name = r.names[cls_id]
    conf = float(box.conf)
    print(f"{name}: {conf:.2f}")
```

## Masks (Segmentation)

```python
masks = r.masks

masks.data       # [N, H, W] tensor — binary masks (model resolution)
masks.xy         # List of [Mi, 2] arrays — polygon contours (pixel coords)
masks.xyn        # List of [Mi, 2] arrays — normalized polygon contours
```

### Extract Mask for Specific Object

```python
import numpy as np

for i, mask in enumerate(r.masks.data):
    binary_mask = mask.cpu().numpy().astype(np.uint8) * 255
    # binary_mask is H×W, resize to original image if needed
```

## Keypoints (Pose)

```python
kpts = r.keypoints

kpts.xy          # [N, K, 2] tensor — keypoint x,y coordinates (pixels)
kpts.xyn         # [N, K, 2] tensor — normalized keypoint coordinates
kpts.conf        # [N, K] tensor — keypoint confidence scores
kpts.data        # [N, K, 3] tensor — x, y, confidence
```

### COCO Keypoint Order (17 points)

```
0: nose, 1: left_eye, 2: right_eye, 3: left_ear, 4: right_ear,
5: left_shoulder, 6: right_shoulder, 7: left_elbow, 8: right_elbow,
9: left_wrist, 10: right_wrist, 11: left_hip, 12: right_hip,
13: left_knee, 14: right_knee, 15: left_ankle, 16: right_ankle
```

## Probs (Classification)

```python
probs = r.probs

probs.data       # [C] tensor — probabilities for each class
probs.top1       # int — top-1 class index
probs.top5       # list[int] — top-5 class indices
probs.top1conf   # float — top-1 confidence
probs.top5conf   # tensor — top-5 confidences
```

## OBB (Oriented Bounding Boxes)

```python
obb = r.obb

obb.xyxyxyxy     # [N, 4, 2] tensor — 4 corner points
obb.xyxyxyxyn    # [N, 4, 2] tensor — normalized corner points
obb.xywhr        # [N, 5] tensor — x_center, y_center, width, height, rotation
obb.conf         # [N] tensor — confidence scores
obb.cls          # [N] tensor — class indices
```

## Visualization & Saving

```python
# Display result
r.show()

# Save annotated image
r.save(filename="result.jpg")

# Plot and get numpy array
annotated = r.plot()  # returns BGR numpy array
# Options: r.plot(conf=True, labels=True, boxes=True, masks=True, probs=True)

# Save cropped detections
r.save_crop(save_dir="crops/")
```

## Export Results

```python
# To JSON
json_str = r.tojson()

# To pandas DataFrame (detection)
import json
data = json.loads(r.tojson())

# To numpy
boxes_np = r.boxes.xyxy.cpu().numpy()
confs_np = r.boxes.conf.cpu().numpy()

# Summary string
print(r.verbose())  # e.g., "2 persons, 1 car"
```

## Batch Processing Pattern

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")

# Process directory with streaming (memory efficient)
results = model("path/to/images/", stream=True)

all_detections = []
for r in results:
    for box in r.boxes:
        all_detections.append({
            "image": r.path,
            "class": r.names[int(box.cls)],
            "confidence": float(box.conf),
            "bbox": box.xyxy[0].tolist(),
        })
```

## Inference Arguments

| Argument | Default | Description |
|---|---|---|
| `conf` | 0.25 | Minimum confidence threshold |
| `iou` | 0.7 | NMS IoU threshold |
| `imgsz` | 640 | Inference image size |
| `classes` | None | Filter by class: `classes=[0, 2]` |
| `max_det` | 300 | Maximum detections per image |
| `stream` | False | Memory-efficient generator mode |
| `save` | False | Save annotated results |
| `save_txt` | False | Save results as .txt files |
| `save_crop` | False | Save cropped detections |
| `show` | False | Display results |
| `vid_stride` | 1 | Video frame stride (skip frames) |
| `agnostic_nms` | False | Class-agnostic NMS |
| `retina_masks` | False | High-resolution segmentation masks |
| `verbose` | True | Print results to console |
