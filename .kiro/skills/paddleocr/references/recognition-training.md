# Text Recognition Fine-tuning

## Pretrained Model Selection

| Model | Config | Pretrained Weights | Notes |
|-------|--------|-------------------|-------|
| PP-OCRv3 rec (recommended) | `PP-OCRv3_mobile_rec_distillation.yml` | `ch_PP-OCRv3_rec_train.tar` | Best for Chinese fine-tune |
| PP-OCRv3 en rec | `en_PP-OCRv3_mobile_rec.yml` | `en_PP-OCRv3_rec_train.tar` | English fine-tune |
| PP-OCRv5 server rec | — | HuggingFace `PaddlePaddle/PP-OCRv5_server_rec` | Highest accuracy, harder to fine-tune |

## Download & Extract

```bash
cd PaddleOCR/

# Chinese PP-OCRv3 recognition
wget https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_rec_train.tar
tar xf ch_PP-OCRv3_rec_train.tar

# English PP-OCRv3 recognition
wget -P ./pretrain_models/ https://paddleocr.bj.bcebos.com/PP-OCRv3/english/en_PP-OCRv3_rec_train.tar
tar xf pretrain_models/en_PP-OCRv3_rec_train.tar -C pretrain_models/
```

## Architecture Modification for Fine-tuning

PP-OCRv3 uses GTC strategy (SAR branch + CTC branch). For fine-tuning on simple/small datasets, the SAR branch causes overfitting. Remove GTC and use CTC only:

```yaml
Architecture:
  model_type: rec
  algorithm: SVTR
  Transform:
  Backbone:
    name: MobileNetV1Enhance
    scale: 0.5
    last_conv_stride: [1, 2]
    last_pool_type: avg
  Neck:
    name: SequenceEncoder
    encoder_type: svtr
    dims: 64
    depth: 2
    hidden_dims: 120
    use_guide: False
  Head:
    name: CTCHead
    fc_decay: 0.00001

Loss:
  name: CTCLoss

Train:
  dataset:
    transforms:
      # REMOVE RecConAug augmentation
      - RecAug:
      - CTCLabelEncode:    # Changed from MultiLabelEncode
      - KeepKeys:
          keep_keys: [image, label, length]

Eval:
  dataset:
    transforms:
      - CTCLabelEncode:    # Changed from MultiLabelEncode
      - KeepKeys:
          keep_keys: [image, label, length]
```

## YAML Config Key Parameters

```yaml
Global:
  pretrained_model: ./ch_PP-OCRv3_rec_train/best_accuracy
  save_model_dir: ./output/rec_custom/
  character_dict_path: ppocr/utils/ppocr_keys_v1.txt  # or custom dict
  use_space_char: True
  epoch_num: 200
  eval_batch_step: [0, 500]

Optimizer:
  lr:
    name: Piecewise
    decay_epochs: [700, 800]
    values: [0.001, 0.0001]    # MUST scale
    warmup_epoch: 5
  regularizer:
    name: L2
    factor: 0

Train:
  dataset:
    name: SimpleDataSet
    data_dir: ./train_data/rec/
    label_file_list: [./train_data/rec/rec_gt_train.txt]
    ratio_list: [1.0]
  loader:
    shuffle: True
    batch_size_per_card: 128
    num_workers: 8

Eval:
  dataset:
    name: SimpleDataSet
    data_dir: ./train_data/rec/
    label_file_list: [./train_data/rec/rec_gt_test.txt]
  loader:
    batch_size_per_card: 256
```

## Learning Rate Scaling

Default config: 8 GPUs × batch_size 128 = total 1024. Scale linearly:

| Setup | batch_size_per_card | Total batch | lr values |
|-------|-------------------|-------------|-----------|
| 1 GPU | 128 | 128 | [1e-4, 2e-5] |
| 1 GPU (low VRAM) | 64 | 64 | [5e-5, 1e-5] |
| 4 GPUs | 128 | 512 | [5e-4, 1e-4] |
| 8 GPUs (default) | 128 | 1024 | [1e-3, 1e-4] |

## Mixing Domain + General Data

To prevent overfitting, mix domain-specific data with general real data at ~1:1 ratio:

```yaml
Train:
  dataset:
    name: SimpleDataSet
    data_dir: ./train_data/rec/
    label_file_list:
      - ./train_data/rec/domain_train.txt      # 10K domain images
      - ./train_data/rec/general_train.txt      # 100K general images
    ratio_list: [1.0, 0.1]  # Sample 100% domain, 10% general → ~1:1
```

General datasets to add: LSVT, RCTW, MTWI (Chinese); SynthText, MJSynth (English).

## Training Commands

```bash
# Single GPU
python3 tools/train.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.pretrained_model=./pretrain_models/en_PP-OCRv3_rec_train/best_accuracy

# Multi-GPU
python3 -m paddle.distributed.launch --gpus '0,1,2,3' tools/train.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.pretrained_model=./pretrain_models/en_PP-OCRv3_rec_train/best_accuracy

# Mixed precision
python3 tools/train.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.pretrained_model=./pretrain_models/en_PP-OCRv3_rec_train/best_accuracy \
     Global.use_amp=True Global.scale_loss=1024.0 Global.use_dynamic_loss_scaling=True
```

## Evaluation & Prediction

```bash
# Evaluate
python3 tools/eval.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.checkpoints=./output/rec_custom/best_accuracy

# Predict single image
python3 tools/infer_rec.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.pretrained_model=./output/rec_custom/best_accuracy \
     Global.infer_img=./doc/imgs_words/en/word_1.png
```

Training log fields:
| Field | Meaning |
|-------|---------|
| loss | Current loss |
| acc | Current batch accuracy |
| norm_edit_dis | Normalized edit distance (higher = better) |
| lr | Current learning rate |

## Iterative Training Strategy

1. Train initial model on domain data + general data
2. Run inference on real-world test images
3. Collect badcases (wrong predictions)
4. Generate targeted synthetic data for error characters
5. Add to training set with ratio original:new = 10:1 to 5:1
6. Fine-tune again with smaller learning rate
7. Repeat until satisfactory

## Tips

- Keep `image_shape` consistent between training and inference (default: [3, 48, 320])
- For long text: increase width in `image_shape`, e.g., [3, 48, 480]
- Balance character frequency in training data — rare chars need more samples
- If changing dict: acc=0 initially is normal, model will converge
- Use `eval_batch_step` to control evaluation frequency (reduce for large eval sets)
