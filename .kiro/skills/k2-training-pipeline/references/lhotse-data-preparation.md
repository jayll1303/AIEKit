# Lhotse Data Preparation

Lhotse handles speech data for ML: corpus representation, feature extraction, augmentation, and PyTorch dataset integration.

## Install

```bash
pip install lhotse
# With Kaldi support:
pip install lhotse[kaldi]
# With all extras:
pip install lhotse[all]
```

## Core Concepts

| Concept | Description | Class |
|---------|-------------|-------|
| Recording | Audio file metadata (path, duration, channels) | `Recording`, `RecordingSet` |
| Supervision | Annotation (text, speaker, language, timestamps) | `SupervisionSegment`, `SupervisionSet` |
| Cut | Audio segment with features + supervisions | `MonoCut`, `CutSet` |
| Feature | Extracted features (fbank, mfcc, spectrogram) | `Features`, `FeatureSet` |

Pipeline: `Recordings + Supervisions → Cuts → Features → PyTorch DataLoader`

## Built-in Corpus Recipes

Lhotse has recipes for 50+ corpora:

```python
from lhotse.recipes import (
    download_librispeech, prepare_librispeech,
    download_aishell, prepare_aishell,
    download_musan, prepare_musan,
    # Many more: ami, commonvoice, gigaspeech, tedlium, voxceleb, etc.
)
```

### LibriSpeech Example
```python
from lhotse.recipes import download_librispeech, prepare_librispeech

# Download (or skip if already downloaded)
download_librispeech("/data/librispeech", dataset_parts=["train-clean-100", "dev-clean"])

# Prepare manifests
manifests = prepare_librispeech(
    corpus_dir="/data/librispeech",
    dataset_parts=["train-clean-100", "dev-clean"],
    output_dir="/data/librispeech/manifests",
)
# Returns dict: {"train-clean-100": {"recordings": ..., "supervisions": ...}, ...}
```

### Custom Dataset
```python
from lhotse import Recording, RecordingSet, SupervisionSegment, SupervisionSet

# Create recordings from audio files
recordings = RecordingSet.from_recordings([
    Recording.from_file("audio/001.wav", recording_id="001"),
    Recording.from_file("audio/002.wav", recording_id="002"),
])

# Create supervisions (transcriptions)
supervisions = SupervisionSet.from_segments([
    SupervisionSegment(
        id="001-1", recording_id="001",
        start=0.0, duration=3.5,
        text="hello world",
        speaker="spk01", language="en",
    ),
    SupervisionSegment(
        id="002-1", recording_id="002",
        start=0.0, duration=4.2,
        text="xin chào",
        speaker="spk02", language="vi",
    ),
])

# Save manifests
recordings.to_file("recordings.jsonl.gz")
supervisions.to_file("supervisions.jsonl.gz")
```

## Cuts

Cuts are the central abstraction — audio segments with aligned features and supervisions.

```python
from lhotse import CutSet

# Create cuts from manifests
cuts = CutSet.from_manifests(recordings=recordings, supervisions=supervisions)

# Trim to supervision boundaries (remove silence)
cuts = cuts.trim_to_supervisions()

# Filter by duration
cuts = cuts.filter(lambda c: 1.0 <= c.duration <= 30.0)

# Shuffle
cuts = cuts.shuffle()

# Split train/dev
cuts_train, cuts_dev = cuts.split(num_splits=2, shuffle=True)

# Save
cuts.to_file("cuts_train.jsonl.gz")
```

### Cut Operations
```python
# Truncate long cuts
cuts = cuts.truncate(max_duration=15.0)

# Pad short cuts
cuts = cuts.pad(duration=10.0)

# Mix cuts (for data augmentation)
cuts_mixed = cuts.mix(cuts_noise, snr=[10, 15, 20])

# Concatenate cuts
cuts_concat = cuts.concat()
```

## Feature Extraction

```python
from lhotse import Fbank, FbankConfig, Spectrogram, Mfcc

# Fbank (most common for ASR)
extractor = Fbank(FbankConfig(
    num_mel_bins=80,
    frame_shift=0.01,    # 10ms
    frame_length=0.025,  # 25ms
    sampling_rate=16000,
))

# Compute and store features
cuts_with_feats = cuts.compute_and_store_features(
    extractor=extractor,
    storage_path="feats/",
    num_jobs=4,           # parallel workers
    storage_type=lhotse.LilcomChunkyWriter,  # compressed storage
)
cuts_with_feats.to_file("cuts_with_feats.jsonl.gz")
```

### On-the-fly Features (no pre-computation)
```python
# Features computed during training — saves disk space
from lhotse.dataset import OnTheFlyFeatures

on_the_fly = OnTheFlyFeatures(extractor=Fbank())
# Use in DataLoader pipeline
```

## Data Augmentation

```python
from lhotse import CutSet
from lhotse.recipes import download_musan, prepare_musan

# Prepare noise corpus
download_musan("/data/musan")
musan = prepare_musan("/data/musan")
cuts_musan = CutSet.from_manifests(**musan["noise"])

# Speed perturbation
cuts_sp = cuts.perturb_speed(factor=0.9) + cuts + cuts.perturb_speed(factor=1.1)

# Volume perturbation
cuts_vp = cuts.perturb_volume(factor=0.5)

# Noise mixing (additive)
cuts_noisy = cuts.mix(cuts_musan, snr=[10, 15, 20], mix_prob=0.5)

# SpecAugment (applied in model, not lhotse)
```

## PyTorch DataLoader Integration

```python
from lhotse.dataset import K2SpeechRecognitionDataset, SimpleCutSampler
from torch.utils.data import DataLoader

cuts = CutSet.from_file("cuts_train.jsonl.gz")

dataset = K2SpeechRecognitionDataset()
sampler = SimpleCutSampler(cuts, max_duration=300)  # batch by total duration

dataloader = DataLoader(
    dataset,
    batch_size=None,  # sampler handles batching
    sampler=sampler,
    num_workers=4,
)

for batch in dataloader:
    features = batch["inputs"]      # (B, T, F)
    supervisions = batch["supervisions"]
    # ... training step
```

### Dynamic Bucketing (recommended for training)
```python
from lhotse.dataset import DynamicBucketingSampler

sampler = DynamicBucketingSampler(
    cuts,
    max_duration=300,
    num_buckets=30,
    shuffle=True,
    drop_last=True,
)
```

## Lhotse Shar (Streaming Format)

For very large datasets that don't fit in memory:

```bash
# Export to shar format
lhotse cut to-shar cuts_train.jsonl.gz --output-dir shars/ --num-jobs 4

# Load from shar
cuts = CutSet.from_shar(in_dir="shars/")
```

## CLI Commands

```bash
# Prepare a corpus
lhotse prepare librispeech /data/librispeech /data/manifests

# Extract features
lhotse feat extract -r recordings.jsonl.gz -o feats/

# Create cuts
lhotse cut simple -r recordings.jsonl.gz -s supervisions.jsonl.gz cuts.jsonl.gz

# Inspect
lhotse cut describe cuts.jsonl.gz

# Convert Kaldi data
lhotse kaldi import data/train_clean_100 data/train_clean_100/wav.scp manifests/
```

## Troubleshooting

```
Feature extraction slow?
├─ Increase num_jobs
├─ Use LilcomChunkyWriter (compressed, fast I/O)
└─ Use on-the-fly features for small datasets

Memory error with large CutSet?
├─ Use lazy mode: CutSet.from_file() (lazy by default)
├─ Use Shar format for streaming
└─ Filter cuts before loading features

Kaldi data import fails?
├─ Check wav.scp paths are absolute
├─ Ensure segments file format is correct
└─ Use lhotse kaldi import command
```
