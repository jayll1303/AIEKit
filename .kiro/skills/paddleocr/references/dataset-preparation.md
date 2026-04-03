# Dataset Preparation for PaddleOCR

## Text Detection Dataset Format

Directory structure:
```
train_data/
├── det/
│   ├── train/
│   │   ├── img_001.jpg
│   │   ├── img_002.jpg
│   │   └── ...
│   ├── test/
│   │   ├── img_001.jpg
│   │   └── ...
│   ├── det_gt_train.txt
│   └── det_gt_test.txt
```

Label format (`det_gt_train.txt`): each line = image path + TAB + JSON list of polygons:
```
train/img_001.jpg	[{"transcription": "HELLO", "points": [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]}, {"transcription": "WORLD", "points": [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]}]
train/img_002.jpg	[{"transcription": "###", "points": [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]}]
```

Rules:
- `points`: 4 vertices of text bounding box (clockwise from top-left)
- `transcription`: text content. Use `"###"` to mark invalid/ignored regions
- Separator between path and JSON: TAB character (`\t`)
- Paths are relative to `data_dir` in config

## Text Recognition Dataset Format

Directory structure:
```
train_data/
├── rec/
│   ├── train/
│   │   ├── word_001.jpg
│   │   ├── word_002.jpg
│   │   └── ...
│   ├── test/
│   │   ├── word_001.jpg
│   │   └── ...
│   ├── rec_gt_train.txt
│   └── rec_gt_test.txt
```

Label format (`rec_gt_train.txt`): each line = image path + TAB + text label:
```
train/word_001.jpg	简单可依赖
train/word_002.jpg	用科技让复杂的世界更简单
train/word_003.jpg	PaddleOCR
```

Rules:
- One cropped text line image per entry
- Separator: TAB (`\t`)
- Images should be cropped text regions (not full page)
- For offline augmentation, multiple images with same label on one line:
  ```
  ["img_01.jpg", "img_02.jpg"]	同一标签文本
  ```

## Dictionary File

Recognition requires a dictionary file mapping characters to indices.

Built-in dictionaries:
| Dict | Path | Characters |
|------|------|-----------|
| Chinese | `ppocr/utils/ppocr_keys_v1.txt` | 6623 chars |
| English (full) | `ppocr/utils/en_dict.txt` | 96 chars |
| English (ICDAR) | `ppocr/utils/ic15_dict.txt` | 36 chars |
| Japanese | `ppocr/utils/dict/japan_dict.txt` | 4399 chars |
| Korean | `ppocr/utils/dict/korean_dict.txt` | 3636 chars |
| French | `ppocr/utils/dict/french_dict.txt` | 118 chars |

Custom dictionary format — one character per line, UTF-8:
```
a
b
c
...
```

To use custom dict, set in YAML config:
```yaml
Global:
  character_dict_path: path/to/your_dict.txt
  use_space_char: True  # set True to recognize spaces
```

**HARD GATE:** If you change the dictionary, the last FC layer weights cannot be loaded from pretrained model. Initial acc=0 is NORMAL. Keep training — it will converge.

## Annotation Tool: PPOCRLabel

PPOCRLabel is a semi-automatic annotation tool with built-in PP-OCR for auto-detection + recognition.

```bash
pip install PPOCRLabel
PPOCRLabel --lang en  # or --lang ch
```

Features:
- Auto-detect text regions using PP-OCR
- Manual correction of bounding boxes and text
- Export in PaddleOCR format (det + rec labels)
- Supports rectangular, table, and irregular text annotation

Workflow:
1. Open image folder in PPOCRLabel
2. Click "Auto Label" — PP-OCR detects and recognizes
3. Manually correct wrong boxes/text
4. Export labels → ready for training

## Data Augmentation Tips

Detection:
- PaddleOCR applies augmentation automatically in training pipeline
- For more diversity: rotate, blur, add noise, perspective transform

Recognition:
- Built-in augmentations: color space, blur, jitter, noise, random crop, perspective, color invert
- Each augmentation applied with 40% probability
- For specific character errors: generate synthetic data with [TextRenderer](https://github.com/Sanster/text_renderer)
- Mix synthetic + real data. Recommended ratio: real:synthetic = 1:1 to 1:5

## Data Volume Guidelines

| Task | Minimum | Recommended | Notes |
|------|---------|-------------|-------|
| Detection fine-tune | 500 images | 2000+ images | More diverse scenes = better |
| Recognition fine-tune (same dict) | 5000 images | 20000+ images | Include varied fonts, backgrounds |
| Recognition (new dict) | 10000+ images | 50000+ images | Need more data when changing charset |
| Add general data | — | 1:1 ratio with domain data | Prevents overfitting, improves generalization |

## ICDAR2015 Example (Quick Test)

```bash
# Download ICDAR2015 labels for PaddleOCR format
wget -P ./train_data/ic15_data https://paddleocr.bj.bcebos.com/dataset/rec_gt_train.txt
wget -P ./train_data/ic15_data https://paddleocr.bj.bcebos.com/dataset/rec_gt_test.txt

# Convert ICDAR official labels to PaddleOCR format
python ppocr/utils/gen_label.py --mode="rec" --input_path="path/to/icdar_label" --output_label="rec_gt_label.txt"
```
