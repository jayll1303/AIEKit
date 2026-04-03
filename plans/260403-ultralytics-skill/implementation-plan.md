# Ultralytics YOLO Skill — Implementation Plan

## Mục tiêu
Tạo Kiro Skill hướng dẫn agent sử dụng Ultralytics YOLO (YOLOv8/YOLO11/YOLO26) cho các task computer vision: detect, segment, classify, pose, OBB.

## Cấu trúc

```
.kiro/skills/ultralytics-yolo/
├── SKILL.md                          # Entry point (<300 lines)
├── references/
│   ├── dataset-preparation.md        # Data collection, annotation tools, folder structure, label formats
│   ├── training-guide.md             # data.yaml templates, training args, multi-GPU, augmentation
│   ├── best-practices-config.md      # YOLO26 recipes, fine-tuning strategies, hyperparameter tuning
│   ├── export-deployment.md          # Export formats, edge deployment, TensorRT/ONNX
│   ├── solutions-analytics.md        # Object counting, heatmaps, speed estimation, tracking
│   └── results-api.md               # Results objects, boxes/masks/keypoints, post-processing
```

## TODO

- [x] Research Ultralytics docs (CLI, Python API, models, tasks, export, solutions)
- [x] Write SKILL.md — model selection, task decision table, quick start, troubleshooting
- [x] Write references/training-guide.md — custom dataset, data.yaml, augmentation, multi-GPU
- [x] Write references/export-deployment.md — export formats, TensorRT, ONNX, edge
- [x] Write references/solutions-analytics.md — counting, heatmaps, speed, tracking
- [x] Write references/results-api.md — Results objects, post-processing patterns
- [x] Update README.md
