# GGUF Conversion with llama.cpp

Detailed guide for converting HuggingFace models to GGUF format using llama.cpp, including quantization levels, importance matrix generation, and troubleshooting.

## Prerequisites

```bash
# Clone and build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build with CUDA support (recommended for imatrix generation)
make -j$(nproc) GGML_CUDA=1

# Or build CPU-only (sufficient for conversion and quantization)
make -j$(nproc)

# Install Python dependencies for conversion
pip install -r requirements.txt
```

## Model Download

Download the source model from HuggingFace Hub before conversion:

```bash
# Using huggingface-cli (recommended)
pip install huggingface-hub
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --local-dir ./models/llama-3.1-8b

# For gated models, login first
huggingface-cli login
huggingface-cli download meta-llama/Llama-3.1-70B-Instruct \
  --local-dir ./models/llama-3.1-70b

# Download only safetensors (skip pytorch_model.bin if both exist)
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --local-dir ./models/llama-3.1-8b \
  --include "*.safetensors" "*.json" "tokenizer*"
```

> **See also**: [hf-hub-datasets](../hf-hub-datasets/SKILL.md) for advanced Hub download patterns (revision selection, partial downloads)

## Conversion: HuggingFace → GGUF

### Basic Conversion (FP16)

```bash
# Convert to FP16 GGUF (base for further quantization)
python convert_hf_to_gguf.py ./models/llama-3.1-8b \
  --outfile ./models/llama-3.1-8b.f16.gguf \
  --outtype f16
```

### Direct Quantized Conversion

```bash
# Convert directly to a quantized format (skips FP16 intermediate)
python convert_hf_to_gguf.py ./models/llama-3.1-8b \
  --outfile ./models/llama-3.1-8b.q8_0.gguf \
  --outtype q8_0
```

### Conversion Options

| Flag | Description |
|---|---|
| `--outtype f16` | FP16 output (lossless base) |
| `--outtype f32` | FP32 output (larger, rarely needed) |
| `--outtype q8_0` | Direct 8-bit quantization |
| `--outtype bf16` | BFloat16 output |
| `--vocab-only` | Export only tokenizer/vocabulary |
| `--metadata` | Add custom metadata key-value pairs |

## Quantization Levels Reference

After converting to FP16 GGUF, quantize to the desired level:

```bash
./llama-quantize <input.gguf> <output.gguf> <type>
```

### Standard Quantization Types

| Type | Bits | Method | Quality | Speed | Recommended |
|---|---|---|---|---|---|
| Q2_K | 2-bit | K-quant mixed | Poor | Fastest | Not recommended |
| Q3_K_S | 3-bit | K-quant small | Low | Very fast | Extreme compression only |
| Q3_K_M | 3-bit | K-quant medium | Acceptable | Very fast | Low VRAM only |
| Q4_K_S | 4-bit | K-quant small | Good | Fast | Budget option |
| **Q4_K_M** | **4-bit** | **K-quant medium** | **Good** | **Fast** | **Default choice** |
| Q5_K_S | 5-bit | K-quant small | Very good | Moderate | Quality-focused |
| **Q5_K_M** | **5-bit** | **K-quant medium** | **Very good** | **Moderate** | **Quality + size balance** |
| Q6_K | 6-bit | K-quant | Excellent | Moderate | High quality |
| **Q8_0** | **8-bit** | Round-to-nearest | **Excellent** | **Slower** | **Near-lossless** |
| F16 | 16-bit | No quantization | Lossless | Slowest | Reference only |

### IQ (Importance-Matrix) Quantization Types

These require an importance matrix for best results:

| Type | Bits | Quality | Notes |
|---|---|---|---|
| IQ2_XXS | ~2.1-bit | Low | Extreme compression, needs imatrix |
| IQ2_XS | ~2.3-bit | Low-moderate | Needs imatrix |
| IQ3_XXS | ~3.1-bit | Moderate | Better than Q3_K_S with imatrix |
| IQ4_XS | ~4.3-bit | Good | Competitive with Q4_K_M |
| IQ4_NL | ~4.5-bit | Good | Non-linear quantization |

## Importance Matrix (imatrix) Generation

An importance matrix improves quantization quality by weighting parameters based on their impact on model output. Essential for sub-4-bit quantization.

### Generate imatrix

```bash
# Prepare calibration text (diverse, representative text)
# Use 100-500 lines of text from your target domain

# Generate importance matrix
./llama-imatrix \
  -m ./models/llama-3.1-8b.f16.gguf \
  -f calibration-data.txt \
  -o ./models/llama-3.1-8b.imatrix \
  -ngl 99    # Offload all layers to GPU for speed
```

### Quantize with imatrix

```bash
# Use imatrix for better quality at low bit levels
./llama-quantize \
  --imatrix ./models/llama-3.1-8b.imatrix \
  ./models/llama-3.1-8b.f16.gguf \
  ./models/llama-3.1-8b.IQ4_XS.gguf \
  IQ4_XS
```

### Calibration Data Tips

- Use **100-500 lines** of diverse text
- Include text similar to your target use case
- Mix multiple sources: Wikipedia, code, conversation, technical docs
- Longer sequences (2048+ tokens per line) capture more context
- Common sources: `wikitext-2-raw`, `c4` dataset samples, domain-specific text

## Uploading Quantized GGUF Models

```bash
# Upload to HuggingFace Hub
huggingface-cli upload your-username/Llama-3.1-8B-GGUF \
  ./models/llama-3.1-8b.Q4_K_M.gguf

# Upload multiple quantizations
huggingface-cli upload your-username/Llama-3.1-8B-GGUF \
  ./models/ --include "*.gguf"
```

## Perplexity Validation

Always validate quantized models against the FP16 baseline:

```bash
# Measure perplexity on wikitext-2
./llama-perplexity \
  -m ./models/llama-3.1-8b.Q4_K_M.gguf \
  -f wikitext-2-raw/wiki.test.raw \
  -ngl 99

# Compare against FP16 baseline
./llama-perplexity \
  -m ./models/llama-3.1-8b.f16.gguf \
  -f wikitext-2-raw/wiki.test.raw \
  -ngl 99
```

**Expected perplexity increase** (wikitext-2, Llama-3.1-8B):
- Q8_0: +0.01-0.05 (negligible)
- Q5_K_M: +0.05-0.15
- Q4_K_M: +0.10-0.30
- Q3_K_M: +0.30-0.80

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `convert_hf_to_gguf.py` fails with unknown architecture | Model architecture not yet supported | Check llama.cpp supported models list, update to latest version |
| Tokenizer errors during conversion | Missing tokenizer files | Ensure `tokenizer.json`, `tokenizer_config.json` are downloaded |
| Very high perplexity after quantization | Too aggressive quantization or bad imatrix | Use higher bit level or regenerate imatrix with better calibration data |
| Out of memory during imatrix generation | Model too large for GPU | Use `-ngl 0` for CPU-only (slower) or reduce context with `-c 512` |
| GGUF file much larger than expected | Used F32 output type | Use `--outtype f16` for the base conversion |
| Model loads but outputs garbage | Conversion bug or corrupted file | Re-download source model, re-convert, verify with `llama-perplexity` |
