# NVIDIA Driver ↔ CUDA Compatibility

## Minimum Driver Requirements

| CUDA | Min Driver (Consumer) | Data Center Forward Compat |
|---|---|---|
| 13.1 | 575+ | R470+, R525+, R535+, R545+ |
| 13.0 | 575+ | R470+, R525+, R535+, R545+ |
| 12.8–12.9 | 570+ | R470+, R525+, R535+, R545+ |
| 12.6 | 560+ | R470+, R525+, R535+, R545+ |
| 12.4–12.5 | 545–555+ | R470+, R525+, R535+ |
| 12.0–12.3 | 525–545+ | R450+, R470+, R510+, R525+ |
| 11.8 | 520+ | R450+, R470+, R510+ |
| 11.4 | 470+ | R418+, R440+, R450+, R460+ |
| 11.0 | 450+ | R418+, R440+ |

## Forward Compatibility (Data Center GPUs Only)

Data center GPUs (Tesla T4, V100, A100, H100, L4, L40) support CUDA forward compatibility. This means older drivers can run containers with newer CUDA via the compatibility package.

Example: A100 with driver R535 can run containers built with CUDA 12.8 (which normally requires R570+).

Consumer GPUs (RTX 3090, 4090, etc.) do NOT support forward compatibility — must have the minimum driver version.

## Checking Your Setup

```bash
# Check driver version and CUDA version
nvidia-smi

# Check if data center GPU
nvidia-smi -L  # Look for Tesla, A100, H100, L4, L40

# Check compute capability
nvidia-smi --query-gpu=compute_cap --format=csv
```

## Minimum Compute Capability

| Triton Release | Min Compute Cap | Architectures |
|---|---|---|
| 25.xx–26.xx | 7.5 | Turing, Ampere, Hopper, Ada, Blackwell |
| 24.xx | 7.0 | Volta, Turing, Ampere, Hopper, Ada |
| 23.xx | 6.0 | Pascal, Volta, Turing, Ampere, Hopper |

## Drivers That Lost Forward Compat

These driver branches are NOT forward-compatible with newer CUDA:
- R418, R440, R450, R460 — dropped from CUDA 12.6+
- R510, R520, R530 — dropped from CUDA 12.8+
- R545, R555, R560 — dropped from CUDA 13.0+

If on these drivers: upgrade driver or use older container.
