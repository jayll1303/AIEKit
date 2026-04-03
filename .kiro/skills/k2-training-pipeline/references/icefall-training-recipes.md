# Icefall Training Recipes

Icefall provides ready-to-use training recipes for ASR and TTS using k2 + lhotse + PyTorch.

## Installation

```bash
# Prerequisites: torch, torchaudio, k2, lhotse already installed

git clone https://github.com/k2-fsa/icefall
cd icefall
pip install -r requirements.txt

# Verify
python3 -c "import icefall; print(icefall.__version__)"
```

## Recipe Structure

Every recipe follows the same pattern:
```
egs/<dataset>/ASR/
├── prepare.sh              # Data preparation (calls lhotse)
├── <model>/
│   ├── train.py            # Training script
│   ├── decode.py           # Decoding/evaluation
│   ├── export-onnx.py      # Export to ONNX
│   ├── onnx_pretrained.py  # Test ONNX model
│   ├── model.py            # Model definition
│   └── asr_datamodule.py   # Data loading
├── data/
│   ├── lang_bpe_500/       # BPE tokenizer
│   └── fbank/              # Features
└── exp/                    # Checkpoints, logs
```

## Available Recipes

### ASR Recipes

| Dataset | Path | Languages | Models |
|---------|------|-----------|--------|
| LibriSpeech | `egs/librispeech/ASR` | English | Zipformer, Conformer, LSTM |
| AISHELL-1 | `egs/aishell/ASR` | Chinese | Zipformer, Conformer |
| AISHELL-2 | `egs/aishell2/ASR` | Chinese | Zipformer |
| GigaSpeech | `egs/gigaspeech/ASR` | English | Zipformer |
| WenetSpeech | `egs/wenetspeech/ASR` | Chinese | Zipformer |
| CommonVoice | `egs/commonvoice/ASR` | Multi-lang | Zipformer |
| TIMIT | `egs/timit/ASR` | English | Conformer |
| YesNo | `egs/yesno/ASR` | — | Toy example |

### TTS Recipes

| Dataset | Path | Models |
|---------|------|--------|
| LJSpeech | `egs/ljspeech/TTS` | VITS |
| VCTK | `egs/vctk/TTS` | VITS (multi-speaker) |

## Training: Zipformer Transducer (LibriSpeech)

### Step 1: Data Preparation
```bash
cd icefall/egs/librispeech/ASR
./prepare.sh
# Stages: download → prepare manifests → compute fbank → prepare BPE
# Takes several hours for full LibriSpeech
```

Control stages:
```bash
./prepare.sh --stage 0 --stop-stage 0  # Only download
./prepare.sh --stage 1 --stop-stage 3  # Manifests + features
```

### Step 2: Train Non-Streaming Zipformer
```bash
./zipformer/train.py \
  --world-size 4 \
  --num-epochs 50 \
  --start-epoch 1 \
  --max-duration 1000 \
  --exp-dir ./zipformer/exp \
  --base-lr 0.045 \
  --lr-epochs 10 \
  --lr-batches 7500 \
  --use-fp16 True
```

Key training parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--world-size` | 1 | Number of GPUs |
| `--num-epochs` | 50 | Total epochs |
| `--max-duration` | 1000 | Max total audio duration per batch (seconds) |
| `--base-lr` | 0.045 | Base learning rate |
| `--use-fp16` | True | Mixed precision training |
| `--exp-dir` | — | Checkpoint output directory |

### Step 3: Train Streaming Zipformer
```bash
./pruned_transducer_stateless7_streaming/train.py \
  --world-size 4 \
  --num-epochs 30 \
  --max-duration 600 \
  --exp-dir ./pruned_transducer_stateless7_streaming/exp \
  --decode-chunk-len 32 \
  --use-fp16 True
```

### Step 4: Decode & Evaluate
```bash
# Greedy search
./zipformer/decode.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --decoding-method greedy_search

# Modified beam search
./zipformer/decode.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --decoding-method modified_beam_search \
  --beam-size 4

# With LM rescoring
./zipformer/decode.py \
  --epoch 50 \
  --avg 10 \
  --exp-dir ./zipformer/exp \
  --decoding-method modified_beam_search \
  --use-shallow-fusion True \
  --lm-type rnn \
  --lm-exp-dir ./rnn_lm/exp
```

Decoding methods:
| Method | Speed | Quality | Use Case |
|--------|-------|---------|----------|
| `greedy_search` | Fastest | Good | Quick evaluation |
| `modified_beam_search` | Medium | Better | Production |
| `fast_beam_search` | Fast | Good | k2-based, with LG |
| + shallow fusion | Slower | Best | With external LM |

## Training: Conformer CTC (AISHELL)

```bash
cd icefall/egs/aishell/ASR
./prepare.sh

./conformer_ctc/train.py \
  --world-size 2 \
  --num-epochs 90 \
  --max-duration 300 \
  --exp-dir ./conformer_ctc/exp
```

## Training: VITS TTS (LJSpeech)

```bash
cd icefall/egs/ljspeech/TTS
./prepare.sh

./vits/train.py \
  --world-size 1 \
  --num-epochs 1000 \
  --max-duration 500 \
  --exp-dir ./vits/exp
```

## Fine-tuning Pre-trained Models

### Standard Fine-tuning
```bash
cd icefall/egs/librispeech/ASR

# Download pre-trained
GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/Zengwei/icefall-asr-librispeech-zipformer-2023-05-15
cd icefall-asr-librispeech-zipformer-2023-05-15
git lfs pull --include "exp/pretrained.pt"
git lfs pull --include "data/lang_bpe_500/bpe.model"
cd ..

# Fine-tune
./zipformer/finetune.py \
  --world-size 1 \
  --num-epochs 10 \
  --max-duration 200 \
  --base-lr 0.0005 \
  --exp-dir ./zipformer/finetune_exp \
  --finetune-from ./icefall-asr-librispeech-zipformer-2023-05-15/exp/pretrained.pt
```

### Adapter-based Fine-tuning (parameter-efficient)
```bash
./zipformer/finetune.py \
  --use-adapter True \
  --adapter-dim 64 \
  --num-epochs 10 \
  --base-lr 0.001 \
  --finetune-from ./pretrained.pt
```

## Decoding with Language Models

### Train RNN-LM
```bash
cd icefall/egs/librispeech/ASR
./rnn_lm/train.py \
  --world-size 1 \
  --num-epochs 40 \
  --max-duration 500 \
  --exp-dir ./rnn_lm/exp
```

### Shallow Fusion
```bash
./zipformer/decode.py \
  --use-shallow-fusion True \
  --lm-type rnn \
  --lm-exp-dir ./rnn_lm/exp \
  --lm-scale 0.3
```

### Lattice Rescoring (LODR)
```bash
./zipformer/decode.py \
  --decoding-method modified_beam_search \
  --use-LODR True \
  --tokens-ngram-order 2
```

## Multi-GPU Training

```bash
# Single node, 4 GPUs
./zipformer/train.py --world-size 4

# Multi-node (node 0)
./zipformer/train.py --world-size 8 --master-addr node0 --master-port 12345

# Resume from checkpoint
./zipformer/train.py --start-epoch 20 --exp-dir ./zipformer/exp
```

## Docker

```bash
# CUDA image
docker pull k2fsa/icefall:torch2.0.1-cuda11.7

# CPU image
docker pull k2fsa/icefall:torch2.0.1-cpu

# Run with GPU
docker run --gpus all -it -v /data:/data k2fsa/icefall:torch2.0.1-cuda11.7
```

## Troubleshooting

```
Training OOM?
├─ Reduce --max-duration (most effective)
├─ Enable --use-fp16 True
├─ Reduce model size (--num-encoder-layers)
└─ Use gradient accumulation

Loss not decreasing?
├─ Check data preparation (./prepare.sh completed?)
├─ Reduce learning rate
├─ Check for NaN in features
└─ Verify BPE model matches tokens

Decode gives garbage?
├─ Wrong --epoch/--avg → check exp/ for actual checkpoint files
├─ Mismatched tokens.txt → use same tokens as training
├─ Model not converged → train more epochs
└─ Wrong decoding method for model type
```
