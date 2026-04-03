---
name: sherpa-onnx
description: "Offline speech processing with sherpa-onnx: ASR (streaming/non-streaming), TTS (Piper/Kokoro/Matcha/VITS), VAD, speaker diarization, speech enhancement. Use when running speech-to-text, text-to-speech, speaker identification, voice activity detection, or audio processing locally without internet."
---

# sherpa-onnx — Offline Speech Processing

Local speech-to-text, text-to-speech, speaker diarization, VAD, speech enhancement, and more using ONNX Runtime. No internet required. Supports 12 programming languages, multiple platforms (Windows/macOS/Linux/Android/iOS/RISC-V/NPU).

## Scope

This skill handles: sherpa-onnx Python API for ASR, TTS, VAD, speaker diarization/identification/verification, speech enhancement, audio tagging, keyword spotting, source separation.

Does NOT handle:
- Model training or fine-tuning (→ hf-transformers-trainer)
- Model quantization to ONNX format (→ model-quantization)
- Docker GPU setup (→ docker-gpu-setup)
- General ONNX Runtime optimization (separate topic)

## When to Use

- Running offline/local speech recognition (streaming or batch)
- Generating speech from text locally (TTS)
- Detecting who spoke when (speaker diarization)
- Adding VAD to audio pipeline
- Enhancing noisy speech or separating sources
- Building voice apps for embedded/mobile/edge devices

## Quick Install

```bash
# CPU only
pip install sherpa-onnx sherpa-onnx-bin

# CUDA 11.8 (Linux/Windows x64)
pip install sherpa-onnx=="1.12.34+cuda" --no-index -f https://k2-fsa.github.io/sherpa/onnx/cuda.html

# CUDA 12.8 + cuDNN 9
pip install sherpa-onnx==1.12.34+cuda12.cudnn9 -f https://k2-fsa.github.io/sherpa/onnx/cuda.html

# Verify
python3 -c "import sherpa_onnx; print(sherpa_onnx.__version__)"
```

## Task Decision Table

| Task | API Class | Model Type | Reference |
|------|-----------|------------|-----------|
| Streaming ASR | `OnlineRecognizer` | Zipformer/Paraformer streaming | [ASR Guide](references/asr-speech-recognition.md) |
| Non-streaming ASR | `OfflineRecognizer` | SenseVoice/Whisper/Paraformer | [ASR Guide](references/asr-speech-recognition.md) |
| Text-to-speech | `OfflineTts` | Kokoro/Piper/Matcha/VITS/KittenTTS | [TTS Guide](references/tts-text-to-speech.md) |
| VAD | `VoiceActivityDetector` | silero_vad.onnx | [VAD Guide](references/vad-enhancement-utils.md) |
| Speaker diarization | `OfflineSpeakerDiarization` | pyannote segmentation + embedding | [Speaker Guide](references/speaker-processing.md) |
| Speaker ID/verify | `SpeakerEmbeddingExtractor` | 3D-Speaker/WeSpeaker | [Speaker Guide](references/speaker-processing.md) |
| Speech enhancement | `OfflineSpeechDenoiser` | GTCRN/DPDFNet | [VAD Guide](references/vad-enhancement-utils.md) |
| Audio tagging | `AudioTagging` | CED/zipformer | [VAD Guide](references/vad-enhancement-utils.md) |
| Keyword spotting | `KeywordSpotter` | zipformer KWS | [VAD Guide](references/vad-enhancement-utils.md) |

## Core Workflow: ASR (Non-streaming)

### Step 1: Download model
```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2
tar xvf sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2
```
**Validate:** Directory contains `model.int8.onnx` and `tokens.txt`.

### Step 2: Run recognition
```python
import sherpa_onnx

recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
    model="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx",
    tokens="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt",
    num_threads=2,
    use_itn=True,
)
stream = recognizer.create_stream()
stream.accept_wave_file("test.wav")
recognizer.decode(stream)
print(stream.result.text)
```
**Validate:** Prints recognized text from audio file.

## Core Workflow: TTS

### Step 1: Download TTS model
```bash
# Kokoro multi-lang (Chinese + English, 103 speakers)
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2
tar xvf kokoro-multi-lang-v1_1.tar.bz2
```

### Step 2: Generate speech
```python
import sherpa_onnx
import soundfile as sf

tts = sherpa_onnx.OfflineTts.from_kokoro(
    model="./kokoro-multi-lang-v1_1/model.onnx",
    voices="./kokoro-multi-lang-v1_1/voices.bin",
    tokens="./kokoro-multi-lang-v1_1/tokens.txt",
    data_dir="./kokoro-multi-lang-v1_1/espeak-ng-data",
    num_threads=2,
)
audio = tts.generate("Hello world, this is a test.", sid=0, speed=1.0)
sf.write("output.wav", audio.samples, samplerate=audio.sample_rate)
```
**Validate:** `output.wav` plays correctly.

## Troubleshooting

```
Import fails?
├─ "No module named sherpa_onnx"
│   └─ pip install sherpa-onnx sherpa-onnx-bin
├─ CUDA version mismatch
│   └─ Install matching CUDA wheel (see Quick Install)
└─ Platform not supported
    └─ Build from source: git clone + python3 setup.py install

Model fails to load?
├─ File not found → Check paths, ensure tar extracted correctly
├─ Wrong model type → Match model to correct API (streaming vs offline)
└─ OOM → Use int8 quantized model variant

No audio output (TTS)?
├─ Check soundfile installed: pip install soundfile
├─ Verify model path and tokens path
└─ Try different sid (speaker ID)
```

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Just use Whisper for everything" | SenseVoice is faster for zh/en/ja/ko. Whisper better for rare languages. |
| "Streaming and offline use same model" | Different models. Streaming = OnlineRecognizer, Offline = OfflineRecognizer. |
| "TTS models are interchangeable" | Each engine (Kokoro/Piper/VITS/Matcha) has different API factory method. |
| "Don't need VAD for long audio" | Always use VAD + non-streaming ASR for long audio. Direct decode may OOM or lose accuracy. |

## Model Downloads

All pre-trained models: `https://github.com/k2-fsa/sherpa-onnx/releases`

| Category | Release Tag |
|----------|-------------|
| ASR models | `asr-models` |
| TTS models | `tts-models` |
| VAD | `asr-models` (silero_vad.onnx) |
| Speaker segmentation | `speaker-segmentation-models` |
| Speaker embedding | `speaker-recongition-models` |
| Keyword spotting | `kws-models` |
| Audio tagging | `audio-tagging-models` |
| Speech enhancement | `speech-enhancement-models` |

## Related Skills

| Situation | Skill | Why |
|---|---|---|
| Need to download models from HuggingFace | hf-hub-datasets | Some models hosted on HF |
| Need Docker for deployment | docker-gpu-setup | Container setup |
| Need to serve via Triton | triton-deployment | Production serving |

## References

- [Installation](references/installation.md) — **Load when:** setting up sherpa-onnx, CUDA, build from source
- [ASR Guide](references/asr-speech-recognition.md) — **Load when:** speech recognition tasks
- [TTS Guide](references/tts-text-to-speech.md) — **Load when:** text-to-speech generation
- [Speaker Processing](references/speaker-processing.md) — **Load when:** diarization, speaker ID, verification
- [VAD & Utils](references/vad-enhancement-utils.md) — **Load when:** VAD, speech enhancement, audio tagging, KWS
- [Model Catalog](references/model-catalog.md) — **Load when:** choosing which model to use
