# k2 Training Pipeline Skill Creation Plan

## Phân tích

Next-gen Kaldi ecosystem gồm nhiều project:
- `k2` — FSA/FST algorithms, differentiable, PyTorch (CTC/LF-MMI loss, lattice rescoring)
- `icefall` — Training recipes (Zipformer, Conformer, VITS TTS) dùng k2 + lhotse
- `lhotse` — Data preparation (corpus, cuts, features, augmentation, PyTorch datasets)
- `sherpa-onnx` — Inference/deployment (đã có skill riêng)

Skill `sherpa-onnx` chỉ cover inference. Cần skill mới cho training pipeline: data prep → train → export → deploy.

## Scope
- Lhotse data preparation (corpus, cuts, features)
- Icefall training recipes (Zipformer transducer/CTC, Conformer, VITS TTS)
- k2 loss functions (CTC, LF-MMI, pruned RNN-T)
- Model export (ONNX, torchscript, ncnn)
- Fine-tuning pre-trained models
- Pipeline: lhotse → icefall → export → sherpa-onnx

## Tasks
- [x] Research k2/icefall/lhotse ecosystem
- [x] Create SKILL.md
- [x] Create references/lhotse-data-preparation.md
- [x] Create references/icefall-training-recipes.md
- [x] Create references/model-export-deploy.md

## Nguồn
- k2: https://k2-fsa.github.io/k2/
- icefall: https://k2-fsa.github.io/icefall/
- lhotse: https://lhotse.readthedocs.io/
- k2-fsa.org: https://www.k2-fsa.org/
