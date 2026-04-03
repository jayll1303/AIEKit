# sherpa-onnx Model Catalog

All models: https://github.com/k2-fsa/sherpa-onnx/releases

## ASR Models (Streaming)

| Model | Languages | Size | Notes |
|-------|-----------|------|-------|
| sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20 | zh, en | ~70MB | Best bilingual streaming |
| sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16 | zh, en | ~30MB | Smaller bilingual |
| sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23 | zh | ~14MB | Tiny, for Cortex A7 |
| sherpa-onnx-streaming-zipformer-en-20M-2023-02-17 | en | ~20MB | Tiny English |
| sherpa-onnx-streaming-zipformer-korean-2024-06-16 | ko | ~70MB | Korean |
| sherpa-onnx-streaming-zipformer-fr-2023-04-14 | fr | ~70MB | French |

Download: `https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models`

## ASR Models (Non-Streaming)

| Model | Languages | Type | Notes |
|-------|-----------|------|-------|
| sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17 | zh, en, ja, ko, yue | SenseVoice | Best multi-lang, supports dialects |
| sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8 | en | NeMo | High accuracy English |
| sherpa-onnx-whisper-tiny.en | en | Whisper | Tiny English |
| sherpa-onnx-whisper-small | multi | Whisper | Multi-language |
| sherpa-onnx-paraformer-zh-2024-03-09 | zh, en | Paraformer | Chinese + dialects |
| sherpa-onnx-zipformer-ja-reazonspeech-2024-08-01 | ja | Zipformer | Japanese |
| sherpa-onnx-nemo-transducer-giga-am-russian-2024-10-24 | ru | NeMo | Russian |
| sherpa-onnx-zipformer-korean-2024-06-24 | ko | Zipformer | Korean |
| sherpa-onnx-zipformer-thai-2024-06-20 | th | Zipformer | Thai |
| sherpa-onnx-telespeech-ctc-int8-zh-2024-06-04 | zh (dialects) | TeleSpeech | Multi-dialect Chinese |
| Moonshine tiny | en | Moonshine | Compact English |

## TTS Models

| Model | Languages | Speakers | Engine |
|-------|-----------|----------|--------|
| kokoro-multi-lang-v1_1 | zh + en | 103 | Kokoro |
| kokoro-multi-lang-v1_0 | zh + en | 53 | Kokoro |
| kokoro-en-v0_19 | en | 11 | Kokoro |
| kitten-nano-en-v0_1-fp16 | en | 1+ | KittenTTS |
| kitten-nano-en-v0_2-fp16 | en | 1+ | KittenTTS |
| kitten-mini-en-v0_1-fp16 | en | 1+ | KittenTTS |
| matcha-icefall-en_US-ljspeech | en | 1 | Matcha |
| matcha-icefall-zh-baker | zh | 1 | Matcha |
| vits-melo-tts-zh_en | zh + en | 1 | VITS/MeloTTS |
| vits-piper-en_US-lessac-medium | en | 1 | Piper |
| vits-piper-en_US-libritts_r-medium | en | 904 | Piper |
| vits-piper-en_US-glados | en | 1 | Piper (GLaDOS) |
| vits-zh-hf-fanchen-C | zh | 187 | VITS |
| vits-zh-hf-theresa | zh | 804 | VITS |
| vits-vctk | en | 109 | VITS |
| vits-aishell3 | zh | 174 | VITS |

Download: `https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models`

Piper voices (30+ languages): https://huggingface.co/rhasspy/piper-voices

## VAD Models

| Model | Notes |
|-------|-------|
| silero_vad.onnx | Standard VAD, works well for most cases |

Download: included in `asr-models` release tag.

## Speaker Models

### Segmentation (for diarization)

| Model | Source |
|-------|--------|
| sherpa-onnx-pyannote-segmentation-3-0 | pyannote 3.0 |
| sherpa-onnx-reverb-diarization-v1 | Reverb |

Download: `https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-segmentation-models`

### Embedding (for ID/verification/diarization)

| Model | Languages |
|-------|-----------|
| 3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common | zh |
| wespeaker_en_voxceleb_resnet34 | en |
| nemo_en_speakerverification_speakernet | en |

Download: `https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models`

## Other Models

| Category | Release Tag |
|----------|-------------|
| Keyword spotting | `kws-models` |
| Audio tagging | `audio-tagging-models` |
| Punctuation | `punctuation-models` |
| Speech enhancement | `speech-enhancement-models` |
| Source separation | `source-separation-models` |

## Model Selection Flowchart

```
What do you need?
├─ Speech-to-text?
│   ├─ Real-time/streaming?
│   │   ├─ Chinese + English → streaming-zipformer-bilingual
│   │   ├─ English only → streaming-zipformer-en-20M
│   │   └─ Tiny device → streaming-zipformer-zh-14M
│   └─ File/batch processing?
│       ├─ zh/en/ja/ko → SenseVoice (best quality)
│       ├─ English only → Parakeet or Whisper
│       ├─ Rare language → Whisper (multi-lang)
│       └─ Chinese dialects → TeleSpeech or Paraformer
│
├─ Text-to-speech?
│   ├─ Chinese + English → Kokoro multi-lang
│   ├─ English only, high quality → Kokoro en or KittenTTS
│   ├─ Many languages → Piper (30+ langs)
│   ├─ Fastest on edge → Piper
│   └─ Many Chinese speakers → VITS (theresa: 804 speakers)
│
├─ Speaker tasks?
│   ├─ Who spoke when → pyannote segmentation + 3dspeaker embedding
│   ├─ Identify known speakers → 3dspeaker/wespeaker embedding
│   └─ Verify same person → embedding + cosine similarity
│
└─ Other?
    ├─ Remove noise → GTCRN or DPDFNet
    ├─ Detect speech → silero_vad
    ├─ Classify sounds → zipformer audio tagging
    ├─ Wake word → zipformer KWS
    └─ Separate vocals → spleeter/UVR
```
