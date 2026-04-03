# Text Detection Fine-tuning

## Pretrained Model Selection

| Model | Config | Pretrained Weights | Notes |
|-------|--------|-------------------|-------|
| PP-OCRv3 det (recommended for fine-tune) | `PP-OCRv3_mobile_det.yml` | `ch_PP-OCRv3_det_distill_train.tar` | Best balance accuracy/generalization |
| PP-OCRv3 det (ResNet50) | `det_r50_vd_db.yml` | `ResNet50_vd_ssld_pretrained` | Higher accuracy, slower |
| MobileNetV3 DB | `det_mv3_db.yml` | `MobileNetV3_large_x0_5_pretrained` | Lightweight |

**Important:** When using `ch_PP-OCRv3_det_distill_train`, use the `student.pdparams` file inside the extracted folder as pretrained model (student model only).

## Download & Extract

```bash
cd PaddleOCR/

# PP-OCRv3 detection pretrained (recommended)
wget https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_det_distill_train.tar
tar xf ch_PP-OCRv3_det_distill_train.tar
```

## YAML Config Key Parameters

```yaml
Global:
  pretrained_model: ./ch_PP-OCRv3_det_distill_train/student.pdparams
  save_model_dir: ./output/det_custom/
  epoch_num: 500
  eval_batch_step: [0, 100]  # evaluate every 100 iterations

Optimizer:
  lr:
    name: Cosine
    learning_rate: 0.001    # MUST scale — see table below
    warmup_epoch: 2
  regularizer:
    name: L2
    factor: 0

Train:
  dataset:
    name: SimpleDataSet
    data_dir: ./train_data/det/
    label_file_list: [./train_data/det/det_gt_train.txt]
  loader:
    shuffle: True
    drop_last: False
    batch_size_per_card: 8
    num_workers: 4

Eval:
  dataset:
    name: SimpleDataSet
    data_dir: ./train_data/det/
    label_file_list: [./train_data/det/det_gt_test.txt]
  loader:
    batch_size_per_card: 1
    num_workers: 2
```

## Learning Rate Scaling

Default config: 8 GPUs × batch_size 8 = total 64. Scale linearly:

| Setup | batch_size_per_card | Total batch | learning_rate |
|-------|-------------------|-------------|---------------|
| 1 GPU | 8 | 8 | 1e-4 |
| 1 GPU (low VRAM) | 4 | 4 | 5e-5 |
| 2 GPUs | 8 | 16 | 2.5e-4 |
| 4 GPUs | 8 | 32 | 5e-4 |
| 8 GPUs (default) | 8 | 64 | 1e-3 |

## Training Commands

```bash
# Single GPU
python3 tools/train.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.pretrained_model=./ch_PP-OCRv3_det_distill_train/student.pdparams \
     Optimizer.lr.learning_rate=0.0001 \
     Train.loader.batch_size_per_card=8

# Multi-GPU (4 GPUs)
python3 -m paddle.distributed.launch --gpus '0,1,2,3' tools/train.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.pretrained_model=./ch_PP-OCRv3_det_distill_train/student.pdparams \
     Optimizer.lr.learning_rate=0.0005

# Mixed precision (faster)
python3 tools/train.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.pretrained_model=./ch_PP-OCRv3_det_distill_train/student.pdparams \
     Global.use_amp=True Global.scale_loss=1024.0 Global.use_dynamic_loss_scaling=True

# Resume from checkpoint
python3 tools/train.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.checkpoints=./output/det_custom/latest
```

## Evaluation

```bash
python3 tools/eval.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.checkpoints=./output/det_custom/best_accuracy
```

Metrics: Precision, Recall, Hmean (F-Score).

## Inference Post-processing Tuning

| Parameter | Default | Effect |
|-----------|---------|--------|
| `det_db_thresh` | 0.3 | Pixel score threshold — higher = fewer detections |
| `det_db_box_thresh` | 0.6 | Box average score threshold — higher = stricter |
| `det_db_unclip_ratio` | 1.5 | Box expansion ratio — higher = larger boxes |
| `max_batch_size` | 10 | Prediction batch size |
| `det_db_score_mode` | "fast" | "slow" = more accurate scoring but slower |

```bash
python3 tools/infer_det.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.pretrained_model=./output/det_custom/best_accuracy \
     Global.infer_img=./test_images/ \
     PostProcess.box_thresh=0.5 \
     PostProcess.unclip_ratio=2.0
```

## Tips

- Annotate detection boxes aligned with semantic content (e.g., full name as one box, not split)
- For small text: increase `det_limit_side_len` (default 960) during inference
- Add general scene data alongside domain data to improve generalization
- If training diverges with AMP, try without it first
