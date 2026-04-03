# Best Practices & Configuration

Production-tested training strategies, YOLO26 training recipes, hyperparameter tuning, and configuration patterns.

## YOLO26 Official Training Recipe

The official YOLO26 checkpoints were trained on COCO 640×640 with MuSGD optimizer, batch 128. Key insights for fine-tuning:

### Optimizer & LR by Model Size

| Setting | N | S | M | L | X |
|---|---|---|---|---|---|
| optimizer | MuSGD | MuSGD | MuSGD | MuSGD | MuSGD |
| lr0 | 0.0054 | 0.00038 | 0.00038 | 0.00038 | 0.00038 |
| lrf | 0.0495 | 0.882 | 0.882 | 0.882 | 0.882 |
| momentum | 0.947 | 0.948 | 0.948 | 0.948 | 0.948 |
| weight_decay | 0.00064 | 0.00027 | 0.00027 | 0.00027 | 0.00027 |
| epochs | 245 | 70 | 80 | 60 | 40 |

**Key insight:** N model uses higher LR with steep decay. S/M/L/X use lower LR with gentle decay. Smaller models need more aggressive updates; larger models converge faster.

### Loss Weights by Model Size

| Setting | N | S/M/L/X |
|---|---|---|
| box | 5.63 | 9.83 |
| cls | 0.56 | 0.65 |
| dfl | 9.04 | 0.96 |

N model prioritizes DFL loss; larger models shift emphasis to box regression.

### Augmentation by Model Size

| Setting | N | S/M/L/X |
|---|---|---|
| mosaic | 0.91 | 0.99 |
| mixup | 0.01 | 0.05-0.43 |
| copy_paste | 0.08 | 0.30-0.40 |
| scale | 0.56 | 0.90-0.95 |
| degrees | 1.1 | ~0 |
| fliplr | 0.61 | 0.30 |

Larger models use more aggressive augmentation (higher mixup, copy_paste, scale) because they have more capacity and benefit from stronger regularization.

### Inspect Any Checkpoint's Training Args

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")
print(model.ckpt["train_args"])

# Or with raw PyTorch
import torch
ckpt = torch.load("yolo26n.pt", map_location="cpu", weights_only=False)
for k, v in sorted(ckpt["train_args"].items()):
    print(f"{k}: {v}")
```

## Fine-Tuning Strategy by Dataset Size

### Small Dataset (< 1,000 images)

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")  # start small
results = model.train(
    data="data.yaml",
    epochs=50,
    patience=20,
    imgsz=640,
    batch=16,
    freeze=10,           # freeze backbone, only train head
    lr0=0.001,           # lower LR for fine-tuning
    mosaic=0.5,          # reduce mosaic — can hurt on small data
    mixup=0.0,           # disable mixup
    copy_paste=0.0,      # disable copy_paste
    close_mosaic=5,
    pretrained=True,
)
```

### Medium Dataset (1,000 - 10,000 images)

```python
model = YOLO("yolo26s.pt")  # can use larger model
results = model.train(
    data="data.yaml",
    epochs=100,
    patience=50,
    imgsz=640,
    batch=-1,            # auto batch size
    lr0=0.01,            # default LR
    cos_lr=True,         # cosine LR schedule
    pretrained=True,
)
```

### Large Dataset (> 10,000 images)

```python
model = YOLO("yolo26m.pt")  # or larger
results = model.train(
    data="data.yaml",
    epochs=100,
    patience=50,
    imgsz=640,
    batch=-1,
    optimizer="MuSGD",   # match official recipe
    mosaic=1.0,
    mixup=0.3,
    copy_paste=0.3,
    scale=0.9,
    cache=True,           # cache images in RAM for speed
    multi_scale=0.25,     # vary imgsz each batch for robustness
)
```

### Domain-Specific Adjustments

| Domain | Key Adjustments |
|---|---|
| Aerial/satellite | `flipud=0.5`, `degrees=90`, larger `scale` |
| Medical imaging | Lower augmentation, `mosaic=0.0`, careful `hsv_*` |
| Underwater | Increase `hsv_s=0.8`, `hsv_v=0.6` for color variation |
| Night/low-light | Increase `hsv_v=0.7`, consider `bgr=0.1` |
| Industrial inspection | `flipud=0.5`, `degrees=180` if orientation varies |
| Document/OCR | `degrees=5` (small rotation), `perspective=0.0005` |

## Hyperparameter Tuning

### Automated Tuning with model.tune()

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")

# Define search space (parameter: (min, max))
search_space = {
    "lr0": (1e-5, 1e-2),
    "mosaic": (0.0, 1.0),
    "mixup": (0.0, 0.5),
    "scale": (0.0, 0.9),
    "degrees": (0.0, 45.0),
    "copy_paste": (0.0, 0.5),
}

# Run tuning — genetic algorithm with mutation
model.tune(
    data="data.yaml",
    epochs=30,           # epochs per iteration
    iterations=300,      # total tuning iterations
    optimizer="AdamW",
    space=search_space,
    plots=False,
    save=False,
    val=False,           # only validate on final epoch
)
# Results in runs/detect/tune/best_hyperparameters.yaml
```

### Resume Interrupted Tuning

```python
model.tune(
    data="data.yaml",
    epochs=30,
    iterations=300,
    space=search_space,
    resume=True,
)
```

### Tuning Output Files

| File | Description |
|---|---|
| `best_hyperparameters.yaml` | Best hyperparameters found |
| `tune_results.csv` | Per-iteration metrics + hyperparameters |
| `best_fitness.png` | Fitness vs iteration plot |
| `tune_scatter_plots.png` | Hyperparameter vs performance scatter |

### Key Hyperparameter Search Ranges

| Parameter | Range | Impact |
|---|---|---|
| `lr0` | 1e-5 — 1e-2 | Learning speed. Too high = unstable, too low = slow |
| `lrf` | 0.01 — 1.0 | Final LR decay. Lower = more aggressive decay |
| `momentum` | 0.7 — 0.98 | Gradient smoothing. Higher = more stable |
| `weight_decay` | 0.0 — 0.001 | Regularization. Higher = less overfitting |
| `box` | 1.0 — 20.0 | Box loss weight. Higher = better localization |
| `cls` | 0.1 — 4.0 | Classification loss weight |
| `mosaic` | 0.0 — 1.0 | Mosaic probability. Lower for small datasets |
| `mixup` | 0.0 — 1.0 | Mixup probability. Good regularizer |
| `scale` | 0.0 — 0.95 | Scale augmentation range |

## Training Performance Optimization

### Speed Optimization Checklist

- [ ] Use `cache=True` (RAM) or `cache='disk'` to reduce I/O bottleneck
- [ ] Set `batch=-1` for auto-optimal batch size
- [ ] Enable `amp=True` (default) for mixed precision
- [ ] Use `workers=8` (or more) for data loading parallelism
- [ ] Use SSD/NVMe storage for dataset (not HDD)
- [ ] For multi-GPU: `device=[0,1]` or `device=[-1,-1]` (auto idle)
- [ ] Consider `fraction=0.1` for quick experiments before full training
- [ ] Use `compile=True` for PyTorch 2.x graph compilation (experimental)

### Memory Optimization

| Technique | How | VRAM Savings |
|---|---|---|
| Reduce batch size | `batch=8` | Proportional |
| Reduce image size | `imgsz=416` or `imgsz=320` | ~40-60% |
| Use smaller model | yolo26n instead of yolo26l | ~80% |
| Auto batch | `batch=-1` (targets 60% VRAM) | Auto |
| Freeze backbone | `freeze=10` | ~30-40% |
| Mixed precision | `amp=True` (default) | ~30% |

### OOM Auto-Retry

YOLO automatically retries with halved batch size on OOM (up to 3 times, single-GPU only). Multi-GPU (DDP) raises immediately.

## Configuration Patterns

### Project Organization

```python
model.train(
    data="data.yaml",
    project="experiments",     # top-level directory
    name="yolo26n-v1",         # run name
    exist_ok=False,            # don't overwrite
)
# Saves to: experiments/yolo26n-v1/
```

### Reproducible Training

```python
model.train(
    data="data.yaml",
    seed=42,                   # fixed random seed
    deterministic=True,        # deterministic algorithms
)
```

### Subset Training (Quick Experiments)

```python
# Train on 10% of data for quick iteration
model.train(data="data.yaml", fraction=0.1, epochs=10)
```

### Class-Specific Training

```python
# Train only on classes 0 and 2
model.train(data="data.yaml", classes=[0, 2])
```

### Single-Class Mode

```python
# Treat all classes as one (binary: object vs background)
model.train(data="data.yaml", single_cls=True)
```

## Monitoring & Interpreting Results

### Key Metrics to Watch

| Metric | Good Sign | Bad Sign |
|---|---|---|
| `train/box_loss` | Steadily decreasing | Flat or increasing |
| `train/cls_loss` | Steadily decreasing | Oscillating wildly |
| `val/box_loss` | Decreasing, close to train | Much higher than train (overfitting) |
| `metrics/mAP50` | Increasing toward 0.7+ | Stuck below 0.3 |
| `metrics/mAP50-95` | Increasing | Flat after many epochs |
| `metrics/precision` | > 0.8 | < 0.5 (many false positives) |
| `metrics/recall` | > 0.8 | < 0.5 (missing detections) |

### Diagnosing Training Issues

```
Training not converging?
├─ Loss oscillating wildly
│   ├─ Reduce lr0 (try 0.001 or 0.0001)
│   ├─ Increase warmup_epochs to 5
│   └─ Check for label errors (wrong class IDs, bad coordinates)
│
├─ Val loss increasing while train loss decreasing (overfitting)
│   ├─ Increase augmentation (mosaic, mixup, scale)
│   ├─ Add weight_decay (try 0.001)
│   ├─ Use smaller model or freeze backbone
│   ├─ Collect more training data
│   └─ Reduce epochs, use patience for early stopping
│
├─ Both losses plateau early
│   ├─ Increase lr0 (try 0.01)
│   ├─ Use larger model (n → s → m)
│   ├─ Increase imgsz (640 → 1280)
│   └─ Check dataset quality — may have hit data ceiling
│
├─ High precision, low recall
│   ├─ Model is too conservative — lower conf threshold at inference
│   ├─ May need more diverse training examples
│   └─ Check for missing annotations (unlabeled objects)
│
└─ Low precision, high recall
    ├─ Too many false positives — raise conf threshold
    ├─ May need negative examples (images with no objects)
    └─ Check for ambiguous/overlapping classes
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Just use default config for everything" | Defaults are tuned for COCO. Custom datasets need adjustment — especially augmentation, LR, and epochs. Always check training curves. |
| "More epochs = better model" | Without early stopping, more epochs = overfitting. Use `patience=50` and monitor val loss. |
| "I'll tune all hyperparameters at once" | Start with defaults, tune one group at a time: LR first, then augmentation, then loss weights. Tuning everything simultaneously is noisy. |
| "Batch size doesn't matter much" | Batch size affects gradient noise, learning dynamics, and BN statistics. Use `batch=-1` to auto-optimize, or match the official recipe's batch=128 if possible. |
| "I'll skip validation to train faster" | Validation is essential for early stopping and monitoring overfitting. Never set `val=False` in production training. |
| "Cache always helps" | `cache=True` loads all images into RAM. If dataset > available RAM, it will crash or swap. Use `cache='disk'` for large datasets. |
| "MuSGD is always better than AdamW" | MuSGD shines on longer runs (>10K iterations). For short fine-tuning, AdamW often converges faster. Use `optimizer=auto` to let YOLO decide. |
