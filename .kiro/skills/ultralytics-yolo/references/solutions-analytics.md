# Solutions & Analytics

Built-in Ultralytics solutions for common computer vision applications and object tracking.

## Available Solutions

| Solution | CLI Command | Description |
|---|---|---|
| Object Counting | `yolo solutions count` | Count objects crossing a line/region |
| Speed Estimation | `yolo solutions speed` | Estimate object speed in video |
| Queue Management | `yolo solutions queue` | Count objects in a queue region |
| Workout Monitoring | `yolo solutions workout` | Monitor exercise reps using pose |
| Heatmaps | `yolo solutions heatmap` | Generate activity heatmaps |
| Streamlit Inference | `yolo solutions inference` | Web-based inference UI |

## Object Counting

### CLI

```bash
# Count objects in video
yolo solutions count source="video.mp4" show=True

# Count with custom region
yolo solutions count source="video.mp4" \
  region="[(100,300),(500,300),(500,250),(100,250)]"
```

### Python API

```python
from ultralytics import solutions

counter = solutions.ObjectCounter(
    model="yolo26n.pt",
    region=[(100, 300), (500, 300), (500, 250), (100, 250)],
    show=True,
)
counter.count(source="video.mp4")
```

## Speed Estimation

```bash
yolo solutions speed source="traffic.mp4" show=True
```

```python
from ultralytics import solutions

speed = solutions.SpeedEstimator(
    model="yolo26n.pt",
    region=[(0, 360), (1280, 360)],
    show=True,
)
speed.estimate(source="traffic.mp4")
```

## Heatmaps

```bash
yolo solutions heatmap source="video.mp4" show=True
```

```python
from ultralytics import solutions

heatmap = solutions.Heatmap(
    model="yolo26n.pt",
    show=True,
    colormap=cv2.COLORMAP_JET,
)
heatmap.generate(source="video.mp4")
```

## Object Tracking

YOLO supports multi-object tracking with BoT-SORT (default) and ByteTrack.

### CLI

```bash
# Track with default BoT-SORT
yolo detect track model=yolo26n.pt source="video.mp4"

# Track with ByteTrack
yolo detect track model=yolo26n.pt source="video.mp4" tracker=bytetrack.yaml

# Track specific classes only
yolo detect track model=yolo26n.pt source="video.mp4" classes=[0,2]
```

### Python API

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")

# Track with streaming results
results = model.track(
    source="video.mp4",
    stream=True,
    tracker="botsort.yaml",  # or "bytetrack.yaml"
    persist=True,             # persist tracks across frames
)

for r in results:
    boxes = r.boxes
    if boxes.id is not None:
        track_ids = boxes.id.int().tolist()
        for box, track_id in zip(boxes.xyxy, track_ids):
            print(f"Track {track_id}: {box}")
```

### Tracker Decision Table

| Tracker | Strengths | Weaknesses | Best For |
|---|---|---|---|
| BoT-SORT | Re-ID features, handles occlusion well | Slightly slower | Crowded scenes, frequent occlusion |
| ByteTrack | Fast, simple, low-confidence detection recovery | No Re-ID | High FPS requirements, sparse scenes |

### Custom Tracker Config

Create `custom_tracker.yaml`:
```yaml
tracker_type: botsort  # or bytetrack
track_high_thresh: 0.5
track_low_thresh: 0.1
new_track_thresh: 0.6
track_buffer: 30
match_thresh: 0.8
# BoT-SORT specific
gmc_method: sparseOptFlow
proximity_thresh: 0.5
appearance_thresh: 0.25
with_reid: False
```

```bash
yolo track model=yolo26n.pt source="video.mp4" tracker=custom_tracker.yaml
```

## Queue Management

```bash
yolo solutions queue source="video.mp4" \
  region="[(20,400),(1080,400),(1080,360),(20,360)]" \
  show=True
```

## Workout Monitoring

```bash
# Monitor with pose model
yolo solutions workout show=True

# Custom keypoints for specific exercises
yolo solutions workout kpts=[5,11,13]   # left side
yolo solutions workout kpts=[6,12,14]   # right side
```

## Solutions Troubleshooting

```
Solution not working?
├─ No detections in video?
│   ├─ Lower conf threshold: conf=0.15
│   ├─ Check model matches task (detect model for counting)
│   └─ Verify video source is readable
│
├─ Tracking IDs keep changing?
│   ├─ Increase track_buffer in tracker config
│   ├─ Try BoT-SORT with with_reid=True
│   └─ Ensure consistent frame rate
│
├─ Counting inaccurate?
│   ├─ Adjust region coordinates to match scene
│   ├─ Use line region for directional counting
│   └─ Increase model size for better detection
│
└─ Speed estimation inaccurate?
    └─ Calibrate meters-per-pixel scale for your camera setup
```
