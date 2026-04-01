# GPU Troubleshooting in Docker

Step-by-step diagnostic process for resolving GPU visibility and access issues inside Docker containers. Covers NVIDIA Container Toolkit installation, Docker runtime configuration, driver compatibility, and common error messages.

## Step-by-Step Diagnostic Process

Work through these checks in order. Most GPU-in-Docker issues are caught in the first three steps.

### Step 1: Verify GPU Works on the Host

Before touching Docker, confirm the host can see the GPU:

```bash
# Check driver is loaded and GPU is visible
nvidia-smi
```

**Expected**: Table showing driver version, CUDA version, GPU name, temperature, memory.

**If `nvidia-smi` fails**:
- `command not found` → NVIDIA driver is not installed
- `NVIDIA-SMI has failed` → Driver installed but not loaded (reboot, or `sudo modprobe nvidia`)
- `No devices were found` → GPU not detected by the OS (check PCIe seating, BIOS settings)

Install or update the driver:
```bash
# Ubuntu — use the recommended driver
sudo ubuntu-drivers autoinstall
sudo reboot

# Or install a specific version
sudo apt-get install nvidia-driver-550
sudo reboot
```

### Step 2: Verify NVIDIA Container Toolkit is Installed

The NVIDIA Container Toolkit (formerly nvidia-docker2) is the bridge between Docker and the GPU. Without it, containers cannot access GPUs.

```bash
# Check if the toolkit is installed
dpkg -l | grep nvidia-container-toolkit

# Or check if the nvidia runtime is registered
docker info 2>/dev/null | grep -i nvidia
```

**Expected**: `nvidia-container-toolkit` package listed, and `docker info` shows `nvidia` in Runtimes.

**If not installed**, install it:

```bash
# Ubuntu/Debian
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

For RHEL/CentOS/Amazon Linux, use the RPM repo at `https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo` and install via `yum`.

### Step 3: Configure Docker Runtime

After installing the toolkit, Docker must be configured to use the `nvidia` runtime:

```bash
# Automatic configuration (recommended)
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

This adds the nvidia runtime to `/etc/docker/daemon.json`. Verify:

```bash
cat /etc/docker/daemon.json
```

**Expected** — should contain:
```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

To make nvidia the default runtime (dev machines), add `"default-runtime": "nvidia"` to the same JSON. Always restart Docker after editing `daemon.json`.

### Step 4: Test GPU Access in a Container

```bash
# Quick test — should show the same nvidia-smi output as the host
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

**If this works**, your Docker + GPU setup is correct. Any issues are in your specific image or compose config.

**If this fails**, see the error messages section below.

### Step 5: Check Your Container Configuration

There are two ways to pass GPUs to containers. They are **not interchangeable**.

#### `docker run` — use `--gpus`

```bash
# All GPUs
docker run --gpus all my-image

# Specific count
docker run --gpus 2 my-image

# Specific devices
docker run --gpus '"device=0,2"' my-image
```

#### `docker compose` — use `deploy.resources.reservations.devices`

```yaml
services:
  app:
    image: my-image
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Common mistake**: Using `--gpus` syntax in compose or `runtime: nvidia` in Compose v2. The `deploy.resources` syntax is the correct approach for Compose v2.

### Step 6: Verify Driver/CUDA Compatibility

The host driver must be new enough for the CUDA version inside the container.

```bash
# Host driver version
nvidia-smi | head -3
# Look for "Driver Version: 550.54.15" and "CUDA Version: 12.4"
```

| Container CUDA | Minimum Driver |
|---|---|
| CUDA 12.6 | ≥ 560.28 |
| CUDA 12.4 | ≥ 550.54 |
| CUDA 12.1 | ≥ 530.30 |
| CUDA 11.8 | ≥ 520.61 |

If the driver is too old, either:
1. Update the host driver: `sudo apt-get install nvidia-driver-560`
2. Use an older NGC image that matches your driver

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for full driver/CUDA/cuDNN compatibility tables

## Common Error Messages and Fixes

### `docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]`

**Cause**: NVIDIA Container Toolkit not installed or Docker not configured.

**Fix**:
```bash
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### `Failed to initialize NVML: Unknown Error`

**Cause**: Usually a driver mismatch or cgroup issue. Common after a driver update without reboot.

**Fix**:
```bash
# Reboot to reload the driver
sudo reboot

# Or try reloading the module
sudo rmmod nvidia_uvm nvidia_drm nvidia_modeset nvidia
sudo modprobe nvidia
```

### `nvidia-container-cli: initialization error: load library failed: libnvidia-ml.so.1`

**Cause**: The container toolkit can't find the NVIDIA driver libraries.

**Fix**:
```bash
# Reinstall the toolkit
sudo apt-get install --reinstall nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### `CUDA error: no kernel image is available for execution on the device`

**Cause**: The CUDA code was compiled for a different GPU architecture than what's installed.

**Fix**: Use an NGC image that supports your GPU architecture, or rebuild with the correct `TORCH_CUDA_ARCH_LIST`:
```bash
# Check your GPU's compute capability
nvidia-smi --query-gpu=compute_cap --format=csv,noheader
# e.g., "8.9" for RTX 4090

# Set arch list when building
ENV TORCH_CUDA_ARCH_LIST="8.9"
```

### `RuntimeError: DataLoader worker ... is killed by signal: Bus Error`

**Cause**: Insufficient shared memory. PyTorch DataLoader workers use `/dev/shm` for IPC.

**Fix**:
```bash
# docker run
docker run --gpus all --shm-size=8g my-image

# docker compose
services:
  app:
    shm_size: "8g"
```

### `NCCL error: unhandled system error` or `NCCL WARN ... no CUDA-capable device is detected`

**Cause**: Multi-GPU communication failure. Often caused by missing IPC or PID namespace sharing.

**Fix** (for multi-GPU training — add `--ipc=host --pid=host`):
```bash
docker run --gpus all --ipc=host --pid=host my-training-image
```

In compose, add `ipc: host` and `pid: host` to the service.

### `permission denied` when accessing GPU device

**Cause**: Running as non-root user without GPU device permissions.

**Fix**: Add the user to the `video` group, or use `--device` flags:
```bash
# In Dockerfile
RUN usermod -aG video appuser

# Or pass devices explicitly
docker run --gpus all --device /dev/nvidia0 --device /dev/nvidiactl --device /dev/nvidia-uvm my-image
```

## GPU Selection and Visibility

```bash
# docker run — limit to specific GPUs
docker run --gpus '"device=0,1"' my-image

# docker compose — specific GPUs
# deploy.resources.reservations.devices[].device_ids: ["0", "2"]

# Inside container — further restrict
CUDA_VISIBLE_DEVICES=0 python train.py

# Verify what the container sees
docker run --rm --gpus all my-image python -c "
import torch; print(f'GPUs: {torch.cuda.device_count()}')
[print(f'  {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]
"
```

## Quick Diagnostic Checklist

Run through this when GPU isn't working in a container:

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Host GPU works | `nvidia-smi` | GPU table displayed |
| 2 | Toolkit installed | `dpkg -l \| grep nvidia-container-toolkit` | Package listed |
| 3 | Docker configured | `docker info \| grep -i nvidia` | `nvidia` in Runtimes |
| 4 | Basic container test | `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi` | GPU table displayed |
| 5 | Driver compat | Compare `nvidia-smi` driver version with container CUDA | Driver ≥ minimum |
| 6 | Correct GPU flags | `--gpus all` (run) or `deploy.resources` (compose) | GPU visible in app |
| 7 | Shared memory | `--shm-size=8g` or `shm_size: "8g"` | No Bus Error |

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for driver/CUDA/cuDNN version compatibility

> **See also**: [NGC Base Images](ngc-base-images.md) for choosing the right base image for your GPU architecture
