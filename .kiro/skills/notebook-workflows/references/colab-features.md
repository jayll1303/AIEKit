# Google Colab Features Reference

**Load when:** tạo notebook cho Google Colab với features nâng cao (forms, secrets, TPU, widgets).

## Colab Metadata

```json
{
  "metadata": {
    "colab": {
      "name": "notebook-name.ipynb",
      "provenance": [],
      "collapsed_sections": [],
      "gpuType": "T4",
      "machine_shape": "hm"
    },
    "accelerator": "GPU",
    "gpuClass": "standard"
  }
}
```

| Field | Values |
|-------|--------|
| `accelerator` | `"GPU"`, `"TPU"`, `"None"` |
| `gpuType` | `"T4"`, `"A100"`, `"V100"`, `"L4"` |
| `gpuClass` | `"standard"`, `"premium"` |
| `machine_shape` | `"hm"` (high memory), default omit |

## Colab Forms

Forms tạo UI inputs trong cells. Dùng comment `# @param` syntax:

```python
# @title Configuration
learning_rate = 0.001  # @param {type:"number"}
model_name = "bert-base"  # @param {type:"string"}
use_gpu = True  # @param {type:"boolean"}
optimizer = "adam"  # @param ["adam", "sgd", "adamw"]
```

Cell metadata cho form:

```json
{
  "metadata": {
    "cellView": "form"
  }
}
```

## Colab Secrets (userdata)

Truy cập secrets được lưu trong Colab UI (không hardcode trong notebook):

```python
from google.colab import userdata
api_key = userdata.get('HF_TOKEN')
```

**Validate:** Secret phải được thêm trong Colab UI: Key icon (sidebar) > Add secret.

## Drive Mount

```python
from google.colab import drive
drive.mount('/content/drive')

# Access files
import os
data_path = '/content/drive/MyDrive/datasets/data.csv'
assert os.path.exists(data_path), "File not found in Drive"
```

## File Upload/Download

```python
# Upload
from google.colab import files
uploaded = files.upload()  # Opens file picker

# Download
files.download('output.csv')
```

## GPU/TPU Setup Patterns

### GPU check and info

```python
import torch
print(f"CUDA: {torch.cuda.is_available()}")
print(f"Device: {torch.cuda.get_device_name(0)}")
print(f"VRAM: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB")
```

### TPU setup (JAX)

```python
import jax
print(f"TPU devices: {jax.device_count()}")
print(f"Device type: {jax.devices()[0].platform}")
```

### TPU setup (PyTorch)

```python
!pip install -q cloud-tpu-client torch_xla
import torch_xla.core.xla_model as xm
device = xm.xla_device()
print(f"TPU device: {device}")
```

## System Commands

```python
# Install packages (quiet mode)
!pip install -q transformers datasets accelerate

# System info
!cat /proc/cpuinfo | head -20
!free -h
!df -h

# Download files
!wget -q https://example.com/data.zip
!gzip -d data.zip
```

## Colab Magic Commands

```python
%%time           # Time cell execution
%%capture output # Capture cell output to variable
%%writefile file.py  # Write cell content to file
%env VAR=value   # Set environment variable
%cd /content     # Change directory
```

## Colab-specific Cell Patterns

### Title cell (collapsible section)

```python
# @title Section Title
# @markdown This section does X and Y.
```

### Hidden setup cell

```json
{
  "cell_type": "code",
  "source": ["# @title Setup {display-mode: \"form\"}\n", "!pip install -q package"],
  "metadata": {
    "cellView": "form"
  }
}
```

## Runtime Limits

| Tier | GPU time | Idle timeout | Max runtime |
|------|----------|-------------|-------------|
| Free | ~12h/week | 90 min | 12h |
| Pro | 24h+ | 90 min | 24h |
| Pro+ | Priority GPU | 24h idle | 24h |

Tip: Dùng `from google.colab import output; output.eval_js('google.colab.kernel.proxyPort(8080)')` để expose ports.
