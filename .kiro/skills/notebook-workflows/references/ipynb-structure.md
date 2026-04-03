# ipynb JSON Structure Reference

**Load when:** cần hiểu sâu về notebook format, xử lý output phức tạp, hoặc debug notebook corruption.

## Top-level Structure

```json
{
  "nbformat": 4,
  "nbformat_minor": 5,
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3 (ipykernel)",
      "language": "python",
      "name": "python3"
    },
    "language_info": {
      "codemirror_mode": { "name": "ipython", "version": 3 },
      "file_extension": ".py",
      "mimetype": "text/x-python",
      "name": "python",
      "nbconvert_exporter": "python",
      "pygments_lexer": "ipython3",
      "version": "3.11.0"
    }
  },
  "cells": []
}
```

## Cell ID (nbformat >= 4.5)

Từ nbformat 4.5+, mỗi cell PHẢI có `id` field — UUID string, unique trong notebook.

```json
{
  "id": "a1b2c3d4",
  "cell_type": "code",
  "source": ["print('hello')"],
  "metadata": {},
  "outputs": [],
  "execution_count": null
}
```

To generate: `import uuid; str(uuid.uuid4())[:8]`

## Output Types

Code cells có thể chứa nhiều loại output trong `outputs` array:

### stream (stdout/stderr)

```json
{
  "output_type": "stream",
  "name": "stdout",
  "text": ["Hello World\n"]
}
```

### execute_result (return value)

```json
{
  "output_type": "execute_result",
  "execution_count": 1,
  "data": {
    "text/plain": ["42"]
  },
  "metadata": {}
}
```

### display_data (rich output)

```json
{
  "output_type": "display_data",
  "data": {
    "text/plain": ["<Figure>"],
    "image/png": "base64-encoded-string..."
  },
  "metadata": {}
}
```

### error

```json
{
  "output_type": "error",
  "ename": "ValueError",
  "evalue": "invalid literal",
  "traceback": [
    "\u001b[0;31m---------------------------------------------------------------------------\u001b[0m",
    "\u001b[0;31mValueError\u001b[0m: invalid literal"
  ]
}
```

## Output Data MIME Types

| MIME type | Dùng cho |
|-----------|---------|
| `text/plain` | Fallback text representation |
| `text/html` | DataFrame, rich HTML output |
| `image/png` | Matplotlib plots, images (base64) |
| `image/svg+xml` | Vector graphics |
| `application/json` | Structured data |
| `text/latex` | Math equations |

## Markdown Cell Attachments

Markdown cells có thể embed images qua `attachments`:

```json
{
  "cell_type": "markdown",
  "metadata": {},
  "source": ["![image](attachment:image.png)"],
  "attachments": {
    "image.png": {
      "image/png": "base64-encoded-string..."
    }
  }
}
```

## Metadata Fields Phổ Biến

### Cell-level metadata

```json
{
  "metadata": {
    "tags": ["hide-input", "parameters"],
    "scrolled": true,
    "collapsed": false,
    "jupyter": {
      "source_hidden": false,
      "outputs_hidden": false
    }
  }
}
```

### Notebook-level metadata (ngoài kernelspec)

```json
{
  "metadata": {
    "title": "My Notebook",
    "authors": [{"name": "Author"}],
    "widgets": {
      "application/vnd.jupyter.widget-state+json": { "state": {} }
    }
  }
}
```

## nbformat Version Differences

| Feature | v4.0-4.4 | v4.5+ |
|---------|----------|-------|
| Cell `id` | Optional | Required (unique UUID) |
| `nbformat_minor` | 0-4 | 5 |
| Backward compat | Full | Full (id ignored by old readers) |

Khi tạo notebook mới, luôn dùng `nbformat_minor: 5` và include cell `id`.
