# ASR (Speech Recognition) with sherpa-onnx

## Two Modes

| Mode | Class | Use Case | Models |
|------|-------|----------|--------|
| Streaming (online) | `OnlineRecognizer` | Real-time mic input, live transcription | Zipformer, Paraformer streaming |
| Non-streaming (offline) | `OfflineRecognizer` | File transcription, batch processing | SenseVoice, Whisper, Paraformer, NeMo |

## Non-Streaming ASR

### SenseVoice (Recommended for zh/en/ja/ko/yue)

```bash
# Download model
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2
tar xvf sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2
```

```python
import sherpa_onnx

recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
    model="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx",
    tokens="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt",
    num_threads=2,
    use_itn=True,  # inverse text normalization
    debug=False,
)

stream = recognizer.create_stream()
stream.accept_wave_file("audio.wav")
recognizer.decode(stream)
print(stream.result.text)
# Access timestamps: stream.result.timestamps
# Access tokens: stream.result.tokens
```

### Whisper

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2
tar xvf sherpa-onnx-whisper-tiny.en.tar.bz2
```

```python
recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
    encoder="./sherpa-onnx-whisper-tiny.en/tiny.en-encoder.onnx",
    decoder="./sherpa-onnx-whisper-tiny.en/tiny.en-decoder.onnx",
    tokens="./sherpa-onnx-whisper-tiny.en/tiny.en-tokens.txt",
    num_threads=2,
)
```

### Paraformer (offline)

```python
recognizer = sherpa_onnx.OfflineRecognizer.from_paraformer(
    paraformer="./model.onnx",
    tokens="./tokens.txt",
    num_threads=2,
)
```

### NeMo CTC / Transducer

```python
# NeMo CTC
recognizer = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
    model="./model.onnx",
    tokens="./tokens.txt",
    num_threads=2,
)
```

## Streaming ASR

### Zipformer Transducer (Recommended for streaming)

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2
tar xvf sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2
```

```python
recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
    encoder="./sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/encoder-epoch-99-avg-1.onnx",
    decoder="./sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/decoder-epoch-99-avg-1.onnx",
    joiner="./sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/joiner-epoch-99-avg-1.onnx",
    tokens="./sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/tokens.txt",
    num_threads=2,
    enable_endpoint_detection=True,
    rule1_min_trailing_silence=2.4,
    rule2_min_trailing_silence=1.2,
    rule3_min_utterance_length=20,
)
```

### Streaming from Microphone

```python
import sounddevice as sd
import numpy as np

# Create recognizer (see above)
stream = recognizer.create_stream()
sample_rate = 16000

def callback(indata, frames, time, status):
    stream.accept_waveform(sample_rate, indata[:, 0].tolist())
    while recognizer.is_ready(stream):
        recognizer.decode_stream(stream)
    text = recognizer.get_result(stream)
    if text:
        print(f"Recognized: {text}")

with sd.InputStream(samplerate=sample_rate, channels=1, callback=callback):
    print("Listening... Press Ctrl+C to stop")
    import time
    while True:
        time.sleep(0.1)
```

**Validate:** Real-time text appears as you speak.

## VAD + Non-Streaming ASR (Long Audio)

For long audio files, always combine VAD with non-streaming ASR:

```python
import sherpa_onnx
import numpy as np
import soundfile as sf

# Load audio
samples, sample_rate = sf.read("long_audio.wav", dtype="float32")
if len(samples.shape) > 1:
    samples = samples[:, 0]  # mono

# Create VAD
vad_config = sherpa_onnx.VadModelConfig()
vad_config.silero_vad.model = "./silero_vad.onnx"
vad_config.silero_vad.threshold = 0.5
vad_config.silero_vad.min_silence_duration = 0.25
vad_config.silero_vad.min_speech_duration = 0.25
vad_config.sample_rate = sample_rate

vad = sherpa_onnx.VoiceActivityDetector(vad_config, buffer_size_in_seconds=30)

# Create recognizer
recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
    model="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx",
    tokens="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt",
    num_threads=2,
)

# Process with VAD
window_size = 512  # for 16kHz
for i in range(0, len(samples), window_size):
    chunk = samples[i:i+window_size]
    vad.accept_waveform(chunk)
    while not vad.empty():
        segment = vad.front()
        stream = recognizer.create_stream()
        stream.accept_waveform(sample_rate, segment.samples)
        recognizer.decode(stream)
        start_sec = segment.start / sample_rate
        print(f"[{start_sec:.2f}s] {stream.result.text}")
        vad.pop()

# Flush remaining
vad.flush()
while not vad.empty():
    segment = vad.front()
    stream = recognizer.create_stream()
    stream.accept_waveform(sample_rate, segment.samples)
    recognizer.decode(stream)
    print(f"[{segment.start/sample_rate:.2f}s] {stream.result.text}")
    vad.pop()
```

## Generate Subtitles (SRT)

Use the built-in example script:
```bash
python3 ./python-api-examples/generate-subtitles.py \
  --silero-vad-model=./silero_vad.onnx \
  --sense-voice=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.onnx \
  --tokens=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt \
  --num-threads=2 \
  ./input.wav
```
Output: `input.srt` file with timestamps.

## WebSocket Server

```bash
# Start server
python3 ./python-api-examples/non_streaming_server.py \
  --sense-voice=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx \
  --tokens=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt \
  --port=6006

# Client (sequential)
python3 ./python-api-examples/offline-websocket-client-decode-files-sequential.py audio1.wav audio2.wav

# Client (parallel)
python3 ./python-api-examples/offline-websocket-client-decode-files-paralell.py audio1.wav audio2.wav

# Web UI: open http://localhost:6006
```

## ASR Model Selection Guide

| Language | Recommended Model | Type | Size |
|----------|------------------|------|------|
| Chinese + English | SenseVoice | Non-streaming | ~400MB |
| Chinese + English (real-time) | Zipformer bilingual | Streaming | ~70MB |
| English only | Whisper tiny.en / Moonshine | Non-streaming | ~40MB |
| English only (real-time) | Zipformer en-20M | Streaming | ~20MB |
| Japanese | Zipformer ReazonSpeech | Non-streaming | ~70MB |
| Korean | Zipformer Korean | Both | ~70MB |
| Russian | NeMo Transducer/CTC | Non-streaming | ~100MB |
| Thai | Zipformer Thai | Non-streaming | ~70MB |
| Multi-dialect Chinese | TeleSpeech CTC | Non-streaming | ~100MB |
| Embedded/tiny device | Zipformer zh-14M | Streaming | ~14MB |
