---
inclusion: fileMatch
fileMatchPattern: ["**/*.ipynb"]
description: Conventions for Jupyter/Colab notebooks (.ipynb). Applies when creating, editing, or parsing notebook files.
---

# Notebook File Conventions

When working with `.ipynb` (Jupyter/Colab notebook) files, follow these rules.

## .ipynb is JSON

`.ipynb` files are JSON with a fixed structure. Do NOT edit via string manipulation — always parse JSON, modify, then serialize back.

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

## Cell Editing Rules

- `source` is an array of strings, each ending with `\n` (except the last line)
- When adding a new cell, always include an `"id"` field (uuid, nbformat >= 4.5)
- Code cells must have `"outputs": []` and `"execution_count": null`
- Markdown cells do NOT have `outputs` or `execution_count`

## Before Committing

- Clear ALL outputs: set `"outputs": []`, `"execution_count": null` for every code cell
- Remove unnecessary metadata (widget state, execution timing)
- Keep `kernelspec` and `language_info` in notebook metadata
- Do NOT commit files with outputs containing sensitive data (API keys, paths, PII)

## When Creating New Notebooks

- Always start with a markdown cell describing the purpose
- Group code cells into logical sections separated by markdown headers
- First cell: imports and setup
- Last cell: cleanup/summary if needed

## Colab-specific

- If notebook targets Colab, add metadata: `"colab": {"name": "...", "provenance": []}`
- Mount Drive: `from google.colab import drive; drive.mount('/content/drive')`
- GPU check: `!nvidia-smi` in a separate cell
- Pip install: use `!pip install -q package` (quiet mode)
