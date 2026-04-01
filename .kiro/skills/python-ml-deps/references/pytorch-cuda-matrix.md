# PyTorch × CUDA Compatibility Matrix

Full compatibility table for PyTorch 2.0–2.6 with supported CUDA versions and `uv pip install` commands.

> **Last verified**: Based on official PyTorch wheel availability at `https://download.pytorch.org/whl/`

## How to Read This Table

- **✅** = Official pre-built wheel available
- **❌** = No wheel available for this combination
- Each entry includes the exact `uv pip install` command
- Always match the index URL to your **toolkit** CUDA version (`nvcc --version`), not the driver version from `nvidia-smi`

## Quick CUDA Version Check

```bash
# Toolkit version (this is what matters for PyTorch wheels)
nvcc --version

# Driver version (upper bound — toolkit can be equal or lower)
nvidia-smi
```

---

## PyTorch 2.6

**Supported Python**: 3.9–3.12

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.4 | ✅ | `cu124` |
| 12.6 | ✅ | `cu126` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.6.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.4
uv pip install torch==2.6.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu124

# CUDA 12.6
uv pip install torch==2.6.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu126

# CPU only
uv pip install torch==2.6.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.5

**Supported Python**: 3.9–3.12

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.1 | ✅ | `cu121` |
| 12.4 | ✅ | `cu124` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.5.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.1
uv pip install torch==2.5.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# CUDA 12.4
uv pip install torch==2.5.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu124

# CPU only
uv pip install torch==2.5.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.4

**Supported Python**: 3.8–3.12

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.1 | ✅ | `cu121` |
| 12.4 | ✅ | `cu124` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.4.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.1
uv pip install torch==2.4.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# CUDA 12.4
uv pip install torch==2.4.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu124

# CPU only
uv pip install torch==2.4.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.3

**Supported Python**: 3.8–3.12

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.1 | ✅ | `cu121` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.3.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.1
uv pip install torch==2.3.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# CPU only
uv pip install torch==2.3.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.2

**Supported Python**: 3.8–3.12

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.1 | ✅ | `cu121` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.2.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.1
uv pip install torch==2.2.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# CPU only
uv pip install torch==2.2.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.1

**Supported Python**: 3.8–3.11

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.8 | ✅ | `cu118` |
| 12.1 | ✅ | `cu121` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.8
uv pip install torch==2.1.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CUDA 12.1
uv pip install torch==2.1.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# CPU only
uv pip install torch==2.1.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## PyTorch 2.0

**Supported Python**: 3.8–3.11

| CUDA | Status | Index URL |
|------|--------|-----------|
| 11.7 | ✅ | `cu117` |
| 11.8 | ✅ | `cu118` |
| CPU  | ✅ | `cpu` |

```bash
# CUDA 11.7
uv pip install torch==2.0.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu117

# CUDA 11.8
uv pip install torch==2.0.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu118

# CPU only
uv pip install torch==2.0.* torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

---

## Summary Matrix

| PyTorch | cu117 | cu118 | cu121 | cu124 | cu126 | cpu |
|---------|-------|-------|-------|-------|-------|-----|
| 2.6     | ❌    | ✅    | ❌    | ✅    | ✅    | ✅  |
| 2.5     | ❌    | ✅    | ✅    | ✅    | ❌    | ✅  |
| 2.4     | ❌    | ✅    | ✅    | ✅    | ❌    | ✅  |
| 2.3     | ❌    | ✅    | ✅    | ❌    | ❌    | ✅  |
| 2.2     | ❌    | ✅    | ✅    | ❌    | ❌    | ✅  |
| 2.1     | ❌    | ✅    | ✅    | ❌    | ❌    | ✅  |
| 2.0     | ✅    | ✅    | ❌    | ❌    | ❌    | ✅  |

## pyproject.toml Pinning Examples

### Pin to specific PyTorch + CUDA combination

```toml
[project]
dependencies = [
    "torch==2.6.*",
    "torchvision>=0.21",
    "torchaudio>=2.6",
]

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu124" }
torchvision = { index = "pytorch-cu124" }
torchaudio = { index = "pytorch-cu124" }
```

### Pin to older PyTorch for CUDA 11.8 compatibility

```toml
[project]
dependencies = [
    "torch==2.4.*",
    "torchvision>=0.19",
    "torchaudio>=2.4",
]

[[tool.uv.index]]
name = "pytorch-cu118"
url = "https://download.pytorch.org/whl/cu118"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu118" }
torchvision = { index = "pytorch-cu118" }
torchaudio = { index = "pytorch-cu118" }
```

## Upgrade Path

When upgrading PyTorch versions, check this sequence:

1. **Check your CUDA toolkit version**: `nvcc --version`
2. **Find the row** in the summary matrix for your target PyTorch version
3. **Verify your CUDA column** has ✅
4. **If ❌**: Either upgrade/downgrade your CUDA toolkit, or pick a different PyTorch version
5. **Update the index URL** in your `uv pip install` command or `pyproject.toml`

> **Common pitfall**: Upgrading from PyTorch 2.3 → 2.4+ with CUDA 12.1 works fine. But upgrading to 2.6 with CUDA 12.1 fails — you need to move to CUDA 12.4 or 12.6.
