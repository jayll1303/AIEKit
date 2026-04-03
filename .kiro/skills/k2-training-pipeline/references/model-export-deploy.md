# Model Export & Deployment

Export trained icefall models to ONNX, torchscript, or ncnn for deployment with sherpa-onnx.

## Export Formats

| Format | Runtime | Platforms | Use Case |
|--------|---------|-----------|----------|
| ONNX | onnxruntime (sherpa-onnx) | All (mobile, server, edge, WebAssembly) | Primary deployment |
| torchscript | libtorch (sherpa) | Server, desktop | Legacy, C++ apps |
| ncnn | ncnn (sherpa-ncnn) | Mobile, embedded | Ultra-lightweight |

## Export to ONNX (Recommended)

Each recipe has its own `export-onnx.py`. Options vary by model architecture.

### Non-Streaming Zipformer
```bash
cd icefall/egs/librispeech/ASR

./zipformer/export-onnx.py \
  --tokens data/lang_bpe_500/tokens.txt \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp
```

Output files:
- `encoder-epoch-50-avg-10.onnx`
- `decoder-epoch-50-avg-10.onnx`
- `joiner-epoch-50-avg-10.onnx`

### Streaming Zipformer
```bash
./pruned_transducer_stateless7_streaming/export-onnx.py \
  --tokens data/lang_bpe_500/tokens.txt \
  --epoch 30 \
  --avg 10 \
  --decode-chunk-len 32 \
  --exp-dir ./pruned_transducer_stateless7_streaming/exp
```

Note: `--decode-chunk-len` is specific to streaming models.

### Conformer CTC
```bash
./conformer_ctc/export-onnx.py \
  --tokens data/lang_bpe_500/tokens.txt \
  --epoch 90 \
  --avg 10 \
  --exp-dir ./conformer_ctc/exp
```

### VITS TTS
```bash
cd icefall/egs/ljspeech/TTS

./vits/export-onnx.py \
  --epoch 1000 \
  --exp-dir ./vits/exp \
  --tokens data/tokens.txt
```

## Test Exported ONNX Model

Each recipe includes `onnx_pretrained.py`:

```bash
./zipformer/onnx_pretrained.py \
  --encoder-model-filename exp/encoder-epoch-50-avg-10.onnx \
  --decoder-model-filename exp/decoder-epoch-50-avg-10.onnx \
  --joiner-model-filename exp/joiner-epoch-50-avg-10.onnx \
  --tokens data/lang_bpe_500/tokens.txt \
  test_wavs/test.wav
```

**Validate:** Prints recognized text matching expected transcription.

## Export to torchscript

### Method 1: torch.jit.trace()
```bash
./zipformer/export.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --jit-trace True
```

### Method 2: torch.jit.script()
```bash
./zipformer/export.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --jit True
```

### Method 3: state_dict only
```bash
./zipformer/export.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp
```
Output: `pretrained.pt` (state dict for fine-tuning or sharing on HuggingFace).

## Export to ncnn

```bash
# Step 1: Export to torchscript
./pruned_transducer_stateless7_streaming/export.py \
  --epoch 30 --avg 10 \
  --exp-dir ./exp \
  --jit-trace True

# Step 2: Convert with pnnx (ncnn tool)
pnnx encoder_jit_trace.pt
pnnx decoder_jit_trace.pt
pnnx joiner_jit_trace.pt

# Step 3: Modify encoder for sherpa-ncnn (see icefall docs)
```

## Deploy with sherpa-onnx

After exporting to ONNX, use with sherpa-onnx Python API:

```python
import sherpa_onnx

# Non-streaming (offline)
recognizer = sherpa_onnx.OfflineRecognizer.from_transducer(
    encoder="./exp/encoder-epoch-50-avg-10.onnx",
    decoder="./exp/decoder-epoch-50-avg-10.onnx",
    joiner="./exp/joiner-epoch-50-avg-10.onnx",
    tokens="./data/lang_bpe_500/tokens.txt",
    num_threads=4,
)

# Streaming (online)
recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
    encoder="./exp/encoder-epoch-30-avg-10.onnx",
    decoder="./exp/decoder-epoch-30-avg-10.onnx",
    joiner="./exp/joiner-epoch-30-avg-10.onnx",
    tokens="./data/lang_bpe_500/tokens.txt",
    num_threads=4,
)
```

See sherpa-onnx skill for full deployment guide.

## ONNX Model Optimization

### Quantize ONNX Model (int8)
```python
import onnxruntime as ort
from onnxruntime.quantization import quantize_dynamic, QuantType

quantize_dynamic(
    "encoder.onnx",
    "encoder-int8.onnx",
    weight_type=QuantType.QInt8,
)
```

### Optimize with ONNX Runtime
```python
import onnx
from onnxruntime.transformers import optimizer

optimized = optimizer.optimize_model("encoder.onnx")
optimized.save_model_to_file("encoder-optimized.onnx")
```

## Upload to HuggingFace

```bash
# Install git-lfs
git lfs install

# Create repo
huggingface-cli repo create icefall-asr-my-model --type model

# Clone and push
git clone https://huggingface.co/<user>/icefall-asr-my-model
cp -r exp/pretrained.pt data/lang_bpe_500 test_wavs icefall-asr-my-model/
cd icefall-asr-my-model
git add .
git commit -m "Add pre-trained model"
git push
```

## Full Pipeline Summary

```
1. Data Prep (lhotse)
   └─ prepare.sh → manifests, features, BPE

2. Train (icefall + k2)
   └─ train.py → checkpoints in exp/

3. Evaluate (icefall)
   └─ decode.py → WER on test sets

4. Export (icefall)
   └─ export-onnx.py → encoder.onnx, decoder.onnx, joiner.onnx

5. Test Export (icefall)
   └─ onnx_pretrained.py → verify ONNX output

6. Deploy (sherpa-onnx)
   └─ Use ONNX models with sherpa-onnx API

7. Share (HuggingFace)
   └─ Upload pretrained.pt + ONNX models
```

## Troubleshooting

```
Export fails with KeyError?
├─ Check --epoch and --avg match actual files in exp/
├─ Ensure exp/ contains epoch-N.pt files
└─ Try --use-averaged-model 0 with specific epoch

ONNX model gives different results than PyTorch?
├─ Normal: small numerical differences expected
├─ Large differences → check export script version matches training
└─ Verify tokens.txt is same file used in training

ONNX model too large?
├─ Apply int8 quantization (see above)
├─ Use smaller model architecture
└─ Export with --fp16 if supported

sherpa-onnx can't load exported model?
├─ Check model type matches API (transducer vs CTC vs paraformer)
├─ Verify all 3 files present (encoder, decoder, joiner) for transducer
├─ Check tokens.txt path
└─ Update sherpa-onnx to latest version
```
