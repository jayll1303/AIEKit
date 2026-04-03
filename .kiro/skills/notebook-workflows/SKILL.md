---
name: notebook-workflows
description: "Create, edit, and manage Jupyter/Colab .ipynb notebooks programmatically. Use when creating notebooks, adding/editing cells, parsing notebook output, handling Colab features (GPU, Drive mount), or converting notebook formats."
---

# Notebook Workflows

Create and manipulate `.ipynb` notebook files programmatically. Handle Jupyter and Google Colab notebooks.

## Scope

This skill handles:
- Creating new `.ipynb` notebooks from scratch
- Adding, editing, removing cells (code, markdown, raw)
- Parsing and extracting cell outputs
- Colab-specific features (Drive mount, GPU runtime, forms)
- Notebook format conversion (nbconvert)
- Pre-commit cleanup (clear outputs, strip metadata)

Does NOT handle:
- Running a Jupyter server (→ user runs manually)
- ML model training logic inside notebooks (→ hf-transformers-trainer)
- Python project setup around notebooks (→ python-project-setup)

## When to Use

- User asks to create a new Jupyter or Colab notebook
- Need to programmatically add/edit cells in an existing .ipynb
- Parsing notebook to extract code, outputs, or markdown content
- Setting up a Colab notebook with GPU, Drive mount, or pip installs
- Converting notebooks to Python scripts or HTML
- Cleaning notebooks before git commit

## Notebook JSON Quick Reference

```json
{
  "nbformat": 4, "nbformat_minor": 5,
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    },
    "language_info": {
      "name": "python", "version": "3.11.0",
      "mimetype": "text/x-python",
      "file_extension": ".py"
    }
  },
  "cells": []
}
```

## Cell Type Decision Table

| Need | cell_type | Required fields | Optional |
|------|-----------|----------------|----------|
| Executable Python code | `code` | source, outputs, execution_count, metadata | id |
| Documentation/headers | `markdown` | source, metadata | id, attachments |
| Raw text (no render) | `raw` | source, metadata | id |

## Core Workflow: Create New Notebook

### Step 1: Build notebook skeleton

```json
{
  "nbformat": 4,
  "nbformat_minor": 5,
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    },
    "language_info": {
      "name": "python",
      "version": "3.11.0"
    }
  },
  "cells": []
}
```

**Validate:** JSON is valid and has `nbformat`, `metadata`, `cells` keys.

### Step 2: Add cells

Code cell template:
```json
{
  "cell_type": "code",
  "metadata": {},
  "source": ["import numpy as np\n", "import pandas as pd"],
  "outputs": [],
  "execution_count": null
}
```

Markdown cell template:
```json
{
  "cell_type": "markdown",
  "metadata": {},
  "source": ["# Section Title\n", "\n", "Description of this section."]
}
```

**Validate:** Each code cell has `outputs` and `execution_count`. Markdown cells do NOT have these fields.

### Step 3: Write file

Write the complete JSON with `indent=1` to keep file size reasonable.

**Validate:** File is valid JSON. Open and verify structure with `python -c "import json; json.load(open('notebook.ipynb'))"`.

## Core Workflow: Edit Existing Notebook

### Step 1: Read and parse

Read the `.ipynb` file as JSON. Identify target cells by index or by searching `source` content.

### Step 2: Modify cells

- To edit: update `source` array (remember `\n` at end of each line except last)
- To insert: splice into `cells` array at desired index
- To delete: remove from `cells` array
- Always preserve `cell_type`-specific fields

### Step 3: Write back

Serialize with same `indent` as original (usually 1 or 2). Preserve `nbformat` and `metadata`.

**Validate:** Diff shows only intended changes. No metadata corruption.

## Core Workflow: Colab Notebook Setup

### Step 1: Add Colab metadata

```json
{
  "metadata": {
    "colab": {
      "name": "my-notebook.ipynb",
      "provenance": [],
      "gpuType": "T4"
    },
    "accelerator": "GPU"
  }
}
```

### Step 2: Standard Colab cells

Cell 1 — Setup:
```python
# @title Setup
!pip install -q torch transformers datasets
```

Cell 2 — GPU check:
```python
# @title GPU Check
!nvidia-smi
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"Device: {torch.cuda.get_device_name(0)}")
```

Cell 3 — Drive mount (if needed):
```python
# @title Mount Google Drive
from google.colab import drive
drive.mount('/content/drive')
```

**Validate:** Notebook opens in Colab without errors. GPU cell shows device info.

## Source Array Formatting Rules

```
"source": ["line1\n", "line2\n", "last line"]
                 ↑ \n          ↑ \n       ↑ NO \n on last
```

- Each element = one line of source code
- All lines end with `\n` EXCEPT the last line
- Empty line = `"\n"`
- Single-line cell = `["content"]` (no `\n`)

## Pre-commit Cleanup

To clean a notebook before committing:

```python
import json

with open("notebook.ipynb") as f:
    nb = json.load(f)

for cell in nb["cells"]:
    if cell["cell_type"] == "code":
        cell["outputs"] = []
        cell["execution_count"] = None
    # Strip cell metadata (keep empty dict)
    cell["metadata"] = {}

# Strip notebook-level widget state
nb["metadata"].pop("widgets", None)

with open("notebook.ipynb", "w") as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)
```

**Validate:** `git diff` shows only output/metadata removal, no source changes.

## Troubleshooting

```
Notebook won't open in Jupyter?
├─ Invalid JSON → python -c "import json; json.load(open('file.ipynb'))"
├─ Missing nbformat → Add "nbformat": 4, "nbformat_minor": 5
└─ Missing kernelspec → Add metadata.kernelspec with display_name + name

Cell not rendering?
├─ Markdown shows raw text → Check cell_type is "markdown" not "code"
├─ Code cell has no run button → Check cell_type is "code"
└─ Output missing after run → Check outputs array structure

Colab-specific issues?
├─ GPU not available → Runtime > Change runtime type > GPU
├─ Drive not mounting → Check Google account permissions
└─ Package install fails → Try !pip install --upgrade package
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Edit .ipynb như text file bình thường" | LUÔN parse JSON, modify object, serialize lại. String manipulation sẽ corrupt file |
| "Không cần clear output trước commit" | Output chứa data lớn, paths, có thể có secrets. LUÔN clear trước commit |
| "Dùng indent=4 cho đẹp" | indent=1 hoặc 2 giữ file size nhỏ. Notebook 1000 cells với indent=4 rất nặng |
| "Copy cell structure từ memory" | LUÔN check nbformat version. v4 vs v5 có khác biệt (id field bắt buộc từ v4.5) |

## References

- [ipynb Structure](references/ipynb-structure.md) — Chi tiết JSON schema, output types, metadata fields
  **Load when:** cần hiểu sâu về notebook format hoặc xử lý output phức tạp
- [Colab Features](references/colab-features.md) — Forms, secrets, widgets, TPU, Colab-specific APIs
  **Load when:** tạo notebook cho Google Colab với features nâng cao
- [Notebook Best Practices](references/notebook-best-practices.md) — Linting, testing, nbconvert, CI/CD
  **Load when:** setup notebook workflow chuyên nghiệp với testing và automation
