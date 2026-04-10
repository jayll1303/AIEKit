---
inclusion: fileMatch
fileMatchPattern: ["**/*.ipynb"]
description: Conventions cho Jupyter/Colab notebook (.ipynb). Áp dụng khi tạo, edit, hoặc parse notebook files.
---

# Notebook File Conventions

Khi làm việc với file `.ipynb` (Jupyter/Colab notebook), tuân thủ các quy tắc sau.

## .ipynb là JSON

File `.ipynb` là JSON với structure cố định. KHÔNG edit bằng string manipulation — luôn parse JSON, modify, rồi serialize lại.

```json
{
  "nbformat": 4,
  "nbformat_minor": 5,
  "metadata": { "kernelspec": {...}, "language_info": {...} },
  "cells": [
    {
      "cell_type": "code|markdown|raw",
      "source": ["line1\n", "line2\n"],
      "metadata": {},
      "outputs": [],
      "execution_count": null
    }
  ]
}
```

## Quy tắc chỉnh sửa cells

- `source` là array of strings, mỗi string kết thúc bằng `\n` (trừ dòng cuối)
- Khi thêm cell mới, luôn include `"id"` field (uuid, nbformat >= 4.5)
- Code cells phải có `"outputs": []` và `"execution_count": null`
- Markdown cells KHÔNG có `outputs` hay `execution_count`

## Trước khi commit

- Clear ALL outputs: set `"outputs": []`, `"execution_count": null` cho mọi code cell
- Xóa metadata không cần thiết (widget state, execution timing)
- Giữ `kernelspec` và `language_info` trong notebook metadata
- KHÔNG commit file có output chứa data nhạy cảm (API keys, paths, PII)

## Khi tạo notebook mới

- Luôn bắt đầu bằng markdown cell mô tả purpose
- Nhóm code cells theo logical sections, ngăn cách bằng markdown headers
- Cell đầu tiên: imports và setup
- Cell cuối: cleanup/summary nếu cần

## Colab-specific

- Nếu notebook dùng cho Colab, thêm metadata: `"colab": {"name": "...", "provenance": []}`
- Mount Drive: `from google.colab import drive; drive.mount('/content/drive')`
- GPU check: `!nvidia-smi` trong cell riêng
- Pip install: dùng `!pip install -q package` (quiet mode)
