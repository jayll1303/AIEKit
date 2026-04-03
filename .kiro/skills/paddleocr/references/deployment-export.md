# Deployment & Model Export

## Export Trained Model to Inference Format

Training saves checkpoints (`.pdparams`). For deployment, export to inference model (`.pdmodel` + `.pdiparams`):

```bash
# Detection model export
export FLAGS_enable_pir_api=0
python3 tools/export_model.py \
  -c configs/det/PP-OCRv3_mobile_det.yml \
  -o Global.pretrained_model=./output/det_custom/best_accuracy \
     Global.save_inference_dir=./inference/det_custom/

# Recognition model export
python3 tools/export_model.py \
  -c configs/rec/PP-OCRv3/en_PP-OCRv3_mobile_rec.yml \
  -o Global.pretrained_model=./output/rec_custom/best_accuracy \
     Global.save_inference_dir=./inference/rec_custom/
```

Output structure:
```
inference/det_custom/
├── inference.pdiparams
├── inference.pdiparams.info
└── inference.pdmodel

inference/rec_custom/
├── inference.pdiparams
├── inference.pdiparams.info
└── inference.pdmodel
```

**HARD GATE:** If you trained with a custom dictionary, you MUST specify `--rec_char_dict_path` when running inference.

## Inference with Exported Models

```bash
# Detection inference
python3 tools/infer/predict_det.py \
  --det_algorithm="DB" \
  --det_model_dir="./inference/det_custom/" \
  --image_dir="./test_images/" \
  --use_gpu=True

# Recognition inference
python3 tools/infer/predict_rec.py \
  --image_dir="./test_images/" \
  --rec_model_dir="./inference/rec_custom/" \
  --rec_image_shape="3,48,320" \
  --rec_char_dict_path="path/to/your_dict.txt"

# Full pipeline (det + rec)
python3 tools/infer/predict_system.py \
  --det_model_dir="./inference/det_custom/" \
  --rec_model_dir="./inference/rec_custom/" \
  --image_dir="./test_images/" \
  --rec_char_dict_path="path/to/your_dict.txt"
```

## PaddleOCR 3.x Python API

```python
from paddleocr import PaddleOCR

# Using default PP-OCRv5
ocr = PaddleOCR()
result = ocr.predict(input="test.png")

# Using custom models
ocr = PaddleOCR(
    det_model_dir="./inference/det_custom/",
    rec_model_dir="./inference/rec_custom/",
    rec_char_dict_path="path/to/your_dict.txt",
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False
)
result = ocr.predict(input="test.png")

for res in result:
    res.print()
    res.save_to_img("output")
    res.save_to_json("output")
```

CLI:
```bash
paddleocr ocr -i test.png \
  --use_doc_orientation_classify False \
  --use_doc_unwarping False
```

## PP-StructureV3 (Document Parsing)

```python
from paddleocr import PPStructureV3

pipeline = PPStructureV3(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False
)
output = pipeline.predict(input="document.png")

for res in output:
    res.print()
    res.save_to_json(save_path="output")
    res.save_to_markdown(save_path="output")
```

CLI:
```bash
paddleocr pp_structurev3 -i document.png
```

## High-Performance Inference

Enable HPI for acceleration (auto-selects TensorRT/ONNX Runtime/OpenVINO):

```python
ocr = PaddleOCR(enable_hpi=True)
```

Performance gains (NVIDIA T4):
- PP-OCRv5_mobile_rec: 73% latency reduction
- PP-OCRv5_mobile_det: 40% latency reduction

## Serving

### Basic Serving (FastAPI)

```bash
paddleocr serving ocr --host 0.0.0.0 --port 8080
```

Client examples available in Python, C++, Java, Go, C#, Node.js, PHP.

### High-Stability Serving (Triton)

For production with multi-GPU, high concurrency → use Triton Inference Server.
See → triton-deployment skill.

## MCP Server

PaddleOCR provides MCP server for LLM integration:

```json
{
  "mcpServers": {
    "paddleocr-ocr": {
      "command": "paddleocr_mcp",
      "args": ["--device", "gpu:0"],
      "env": {
        "PADDLEOCR_MCP_PIPELINE": "OCR",
        "PADDLEOCR_MCP_PPOCR_SOURCE": "local"
      }
    }
  }
}
```

Modes: `local` (Python lib), `aistudio` (cloud), `self_hosted` (custom service).

## ONNX Export (for non-Paddle runtimes)

```bash
# Install paddle2onnx
pip install paddle2onnx

# Convert
paddle2onnx \
  --model_dir ./inference/det_custom/ \
  --model_filename inference.pdmodel \
  --params_filename inference.pdiparams \
  --save_file ./onnx/det_custom.onnx \
  --opset_version 11
```

## Deployment Checklist

- [ ] Model exported to inference format (`.pdmodel` + `.pdiparams`)
- [ ] Custom dict path specified if dict was changed
- [ ] `image_shape` matches between training config and inference
- [ ] Pre/post-processing params consistent (det_db_thresh, unclip_ratio, etc.)
- [ ] Health check: inference produces correct results on known test images
- [ ] For production: enable HPI or use Triton serving
