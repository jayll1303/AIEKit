---
name: k2-training-pipeline
description: "Train speech models with Next-gen Kaldi ecosystem: k2 (FSA/FST loss), icefall (Zipformer/Conformer recipes), lhotse (data prep). Use when training ASR/TTS models, preparing speech datasets, exporting to ONNX for sherpa-onnx, or fine-tuning pre-trained speech models."
---

# k2 Training Pipeline — Next-gen Kaldi

Train, fine-tune, and export speech recognition (ASR) and TTS models using the Next-gen Kaldi ecosystem. This covers the full pipeline from data preparation to deployment-ready ONNX models.

## Ecosystem Overview

| Project | Role | PyPI | Docs |
|---------|------|------|------|
| `k2` | FSA/FST algorithms, differentiable loss (CTC, LF-MMI, pruned RNN-T) | `pip install k2` | k2-fsa.github.io/k2 |
| `icefall` | Training recipes (Zipformer, Conformer, VITS) | git clone | k2-fsa.github.io/icefall |
| `lhotse` | Speech data preparation (corpus, cuts, features, augmentation) | `pip install lhotse` | lhotse.readthedocs.io |
| `sherpa-onnx` | Inference/deployment (→ sherpa-onnx skill) | `pip install sherpa-onnx` | k2-fsa.github.io/sherpa/onnx |

Pipeline flow: `lhotse (data) → icefall (train) → export (ONNX) → sherpa-onnx (deploy)`

## Scope

This skill handles: lhotse data preparation, icefall training recipes, k2 loss functions, model export to ONNX/torchscript/ncnn, fine-tuning pre-trained models.

Does NOT handle:
- Inference/deployment with exported models (→ sherpa-onnx)
- General PyTorch training loops (→ hf-transformers-trainer)
- Docker GPU setup (→ docker-gpu-setup)

## When to Use

- Preparing speech datasets for ASR/TTS training
- Training Zipformer/Conformer models from scratch
- Fine-tuning pre-trained ASR models on custom data
- Exporting trained models to ONNX for sherpa-onnx deployment
- Computing CTC/LF-MMI/pruned-RNN-T loss with k2
- Training VITS TTS models with icefall

## Installation

```bash
# 1. PyTorch (match your CUDA version)
pip install torch torchaudio

# 2. k2 (pre-compiled wheels)
pip install k2==1.24.4.dev20231220+cpu.torch2.1.2 -f https://k2-fsa.github.io/k2/cpu.html
# CUDA version:
pip install k2==1.24.4.dev20231220+cuda11.8.torch2.1.2 -f https://k2-fsa.github.io/k2/cuda.html

# 3. lhotse
pip install lhotse

# 4. icefall (no pip, clone repo)
git clone https://github.com/k2-fsa/icefall
cd icefall
pip install -r requirements.txt

# Verify
python3 -c "import k2; print(k2.__version__)"
python3 -c "import lhotse; print(lhotse.__version__)"
```

**Validate:** All imports succeed without errors.

## Recipe Decision Table

| Goal | Recipe | Dataset | Architecture |
|------|--------|---------|-------------|
| English ASR (non-streaming) | `egs/librispeech/ASR` | LibriSpeech | Zipformer transducer/CTC |
| English ASR (streaming) | `egs/librispeech/ASR` | LibriSpeech | Zipformer streaming |
| Chinese ASR | `egs/aishell/ASR` | AISHELL-1 | Zipformer/Conformer |
| English TTS | `egs/ljspeech/TTS` | LJSpeech | VITS |
| Multi-speaker TTS | `egs/vctk/TTS` | VCTK | VITS |
| Fine-tune on custom data | `egs/librispeech/ASR` + adapter | Custom | Zipformer + adapter |
| Language model | `egs/librispeech/ASR` | LibriSpeech | RNN-LM |

## Core Workflow: Train ASR Model

### Step 1: Prepare Data with lhotse
```bash
cd icefall/egs/librispeech/ASR
./prepare.sh
# This runs lhotse internally to create manifests, features, BPE model
```

Or manually with lhotse:
```python
import lhotse
from lhotse import RecordingSet, SupervisionSet, CutSet
from lhotse.recipes import download_librispeech, prepare_librispeech

# Download
download_librispeech("/data/librispeech", dataset_parts=["train-clean-100"])

# Prepare manifests
manifests = prepare_librispeech("/data/librispeech", dataset_parts=["train-clean-100"])

# Create cuts
cuts = CutSet.from_manifests(**manifests["train-clean-100"])
cuts = cuts.trim_to_supervisions()

# Extract features
from lhotse import Fbank, FbankConfig
extractor = Fbank(FbankConfig(num_mel_bins=80))
cuts = cuts.compute_and_store_features(extractor, storage_path="feats", num_jobs=4)
cuts.to_file("cuts_train.jsonl.gz")
```
**Validate:** `cuts_train.jsonl.gz` exists and `len(cuts) > 0`.

### Step 2: Train
```bash
cd icefall/egs/librispeech/ASR

# Zipformer transducer (non-streaming)
./zipformer/train.py \
  --world-size 1 \
  --num-epochs 30 \
  --max-duration 300 \
  --exp-dir ./zipformer/exp

# Streaming Zipformer
./pruned_transducer_stateless7_streaming/train.py \
  --world-size 1 \
  --num-epochs 30 \
  --max-duration 300 \
  --exp-dir ./pruned_transducer_stateless7_streaming/exp
```
**Validate:** Loss decreasing in training logs. Checkpoints saved in exp dir.

### Step 3: Decode & Evaluate
```bash
./zipformer/decode.py \
  --epoch 30 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --decoding-method greedy_search
```
**Validate:** WER printed for test sets.

### Step 4: Export to ONNX
```bash
./zipformer/export-onnx.py \
  --tokens data/lang_bpe_500/tokens.txt \
  --epoch 30 \
  --avg 10 \
  --exp-dir ./zipformer/exp
```
Output: `encoder-epoch-30-avg-10.onnx`, `decoder-epoch-30-avg-10.onnx`, `joiner-epoch-30-avg-10.onnx`

**Validate:** ONNX files exist. Test with `onnx_pretrained.py`.

### Step 5: Deploy with sherpa-onnx
Use exported ONNX models with sherpa-onnx (→ sherpa-onnx skill).

## Fine-tuning Pre-trained Models

```bash
cd icefall/egs/librispeech/ASR

# Download pre-trained model
GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/Zengwei/icefall-asr-librispeech-zipformer-2023-05-15
cd icefall-asr-librispeech-zipformer-2023-05-15
git lfs pull --include "exp/pretrained.pt"
git lfs pull --include "data/lang_bpe_500/bpe.model"

# Fine-tune on GigaSpeech subset
./zipformer/finetune.py \
  --world-size 1 \
  --num-epochs 10 \
  --max-duration 200 \
  --exp-dir ./zipformer/finetune_exp \
  --base-lr 0.0005 \
  --finetune-from ./icefall-asr-librispeech-zipformer-2023-05-15/exp/pretrained.pt
```

### Fine-tune with Adapters (parameter-efficient)
```bash
./zipformer/finetune.py \
  --world-size 1 \
  --use-adapter True \
  --adapter-dim 64 \
  --num-epochs 10 \
  --finetune-from ./pretrained.pt
```

## Troubleshooting

```
k2 install fails?
├─ CUDA version mismatch → Match k2 wheel to your torch+CUDA version exactly
├─ "No matching distribution" → Check Python version, use -f URL for wheel index
└─ Build from source if no wheel available

Training OOM?
├─ Reduce --max-duration (e.g., 300 → 150)
├─ Reduce --num-encoder-layers
├─ Use gradient checkpointing
└─ Use multi-GPU: --world-size N

Export fails?
├─ "KeyError" → Check --epoch and --avg match actual checkpoint files
├─ ONNX opset error → Update onnx package
└─ Streaming model needs --decode-chunk-len

lhotse data prep fails?
├─ "FileNotFoundError" → Check dataset download path
├─ Feature extraction slow → Increase --num-jobs
└─ Disk full → Use lhotse Shar format for streaming
```

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Just use icefall without k2" | k2 is required for loss computation. Always install k2 first. |
| "Skip lhotse, use raw audio" | Icefall recipes expect lhotse manifests. Always prepare data with lhotse. |
| "Export any model to ONNX" | Each recipe has its own export-onnx.py with different options. |
| "Fine-tune = train from scratch" | Use --finetune-from with lower learning rate. Don't retrain from random init. |
| "Same k2 wheel for any PyTorch" | k2 wheels are tied to specific PyTorch + CUDA versions. Must match exactly. |

## Related Skills

| Situation | Skill | Why |
|---|---|---|
| Deploy exported ONNX models | sherpa-onnx | Inference with sherpa-onnx |
| Need HuggingFace models/datasets | hf-hub-datasets | Download pre-trained models |
| Docker for training | docker-gpu-setup | GPU container setup |
| Experiment tracking | experiment-tracking | MLflow/W&B for training runs |
| Python project setup | python-project-setup | uv, ruff, pytest |

## References

- [Lhotse Data Preparation](references/lhotse-data-preparation.md) — **Load when:** preparing speech datasets, creating manifests/cuts/features
- [Icefall Training Recipes](references/icefall-training-recipes.md) — **Load when:** training ASR/TTS models, decoding, evaluating
- [Model Export & Deploy](references/model-export-deploy.md) — **Load when:** exporting to ONNX/ncnn, deploying trained models
