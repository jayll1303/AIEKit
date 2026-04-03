# TTS (Text-to-Speech) with sherpa-onnx

## TTS Engine Decision Table

| Engine | Languages | Speakers | Quality | Speed | Best For |
|--------|-----------|----------|---------|-------|----------|
| Kokoro | zh + en | 53-103 | High | Fast | Multi-lang, multi-speaker |
| KittenTTS | en | 1+ | High | Fast | Compact English TTS |
| Matcha | zh, en | 1 per model | Good | Fast | Single-speaker, lightweight |
| Piper | 30+ langs | Varies | Good | Very fast | Many languages, edge devices |
| VITS | zh, en, etc. | Varies | Good | Medium | Legacy, many pre-trained |

## Kokoro TTS (Recommended)

### Download Model
```bash
# Multi-lang v1.1 (Chinese + English, 103 speakers)
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2
tar xvf kokoro-multi-lang-v1_1.tar.bz2

# English only (11 speakers)
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-en-v0_19.tar.bz2
tar xvf kokoro-en-v0_19.tar.bz2
```

### Generate Speech
```python
import sherpa_onnx
import soundfile as sf

tts = sherpa_onnx.OfflineTts.from_kokoro(
    model="./kokoro-multi-lang-v1_1/model.onnx",
    voices="./kokoro-multi-lang-v1_1/voices.bin",
    tokens="./kokoro-multi-lang-v1_1/tokens.txt",
    data_dir="./kokoro-multi-lang-v1_1/espeak-ng-data",
    num_threads=2,
    debug=False,
)

# Generate with speaker ID
audio = tts.generate("你好世界，Hello World!", sid=0, speed=1.0)
sf.write("output.wav", audio.samples, samplerate=audio.sample_rate)

# List available speakers: check model's speaker map
# sid=0..102 for kokoro-multi-lang-v1_1
```

### CLI
```bash
sherpa-onnx-offline-tts \
  --kokoro-model=./kokoro-multi-lang-v1_1/model.onnx \
  --kokoro-voices=./kokoro-multi-lang-v1_1/voices.bin \
  --tokens=./kokoro-multi-lang-v1_1/tokens.txt \
  --kokoro-data-dir=./kokoro-multi-lang-v1_1/espeak-ng-data \
  --sid=0 \
  --output-filename=output.wav \
  "Hello, this is a test."
```

## KittenTTS

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kitten-nano-en-v0_1-fp16.tar.bz2
tar xvf kitten-nano-en-v0_1-fp16.tar.bz2
```

```python
tts = sherpa_onnx.OfflineTts.from_kitten(
    model="./kitten-nano-en-v0_1-fp16/model.onnx",
    tokens="./kitten-nano-en-v0_1-fp16/tokens.txt",
    data_dir="./kitten-nano-en-v0_1-fp16/espeak-ng-data",
    num_threads=2,
)
audio = tts.generate("Hello world", sid=0, speed=1.0)
```

## Matcha TTS

```bash
# English
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/matcha-icefall-en_US-ljspeech.tar.bz2
tar xvf matcha-icefall-en_US-ljspeech.tar.bz2

# Chinese
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/matcha-icefall-zh-baker.tar.bz2
tar xvf matcha-icefall-zh-baker.tar.bz2
```

```python
tts = sherpa_onnx.OfflineTts.from_matcha(
    acoustic_model="./matcha-icefall-en_US-ljspeech/model-steps-3.onnx",
    vocoder="./matcha-icefall-en_US-ljspeech/hifigan_v2.onnx",
    tokens="./matcha-icefall-en_US-ljspeech/tokens.txt",
    data_dir="./matcha-icefall-en_US-ljspeech/espeak-ng-data",
    num_threads=2,
)
audio = tts.generate("Hello world", sid=0, speed=1.0)
```

## Piper TTS

Piper supports 30+ languages with many pre-trained voices.

```bash
# Download from https://huggingface.co/rhasspy/piper-voices
# Example: English US lessac medium
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2
tar xvf vits-piper-en_US-lessac-medium.tar.bz2
```

```python
tts = sherpa_onnx.OfflineTts.from_vits(
    model="./vits-piper-en_US-lessac-medium/en_US-lessac-medium.onnx",
    tokens="./vits-piper-en_US-lessac-medium/tokens.txt",
    data_dir="./vits-piper-en_US-lessac-medium/espeak-ng-data",
    num_threads=2,
)
audio = tts.generate("Hello world", sid=0, speed=1.0)
```

Browse all Piper voices: https://huggingface.co/rhasspy/piper-voices

## VITS TTS

```python
# MeloTTS (Chinese + English)
tts = sherpa_onnx.OfflineTts.from_vits(
    model="./vits-melo-tts-zh_en/model.onnx",
    tokens="./vits-melo-tts-zh_en/tokens.txt",
    dict_dir="./vits-melo-tts-zh_en/dict",
    num_threads=2,
)

# Multi-speaker VCTK (109 English speakers)
tts = sherpa_onnx.OfflineTts.from_vits(
    model="./vits-vctk/vits-vctk.onnx",
    tokens="./vits-vctk/tokens.txt",
    num_threads=2,
)
audio = tts.generate("Hello", sid=10, speed=1.0)  # sid=0..108
```

## TTS with Callback (Streaming Output)

```python
import sherpa_onnx
import soundfile as sf
import numpy as np

all_samples = []

def callback(samples, progress):
    """Called as audio chunks are generated."""
    all_samples.extend(samples)
    return 1  # return 0 to stop generation

tts = sherpa_onnx.OfflineTts.from_kokoro(
    model="./kokoro-multi-lang-v1_1/model.onnx",
    voices="./kokoro-multi-lang-v1_1/voices.bin",
    tokens="./kokoro-multi-lang-v1_1/tokens.txt",
    data_dir="./kokoro-multi-lang-v1_1/espeak-ng-data",
    num_threads=2,
)

audio = tts.generate("Long text here...", sid=0, speed=1.0, callback=callback)
```

## All TTS Models

Browse: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models

## Troubleshooting

```
No audio / empty output?
├─ Check text is not empty
├─ Verify model + tokens paths
├─ Try different sid
└─ Check espeak-ng-data dir exists (for Kokoro/Piper/Matcha)

Garbled audio?
├─ Wrong sample rate → use audio.sample_rate from output
├─ Wrong model for language → match model to text language
└─ Model corrupted → re-download

Slow generation?
├─ Use int8 model if available
├─ Reduce num_threads on single-core
└─ Use Piper for fastest RTF on edge devices
```
