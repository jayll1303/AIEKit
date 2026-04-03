# VAD, Speech Enhancement & Utilities

## Voice Activity Detection (VAD)

### Download silero-vad
```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx
```

### Standalone VAD

```python
import sherpa_onnx
import soundfile as sf

config = sherpa_onnx.VadModelConfig()
config.silero_vad.model = "./silero_vad.onnx"
config.silero_vad.threshold = 0.5
config.silero_vad.min_silence_duration = 0.25
config.silero_vad.min_speech_duration = 0.25
config.sample_rate = 16000

vad = sherpa_onnx.VoiceActivityDetector(config, buffer_size_in_seconds=30)

samples, sr = sf.read("audio.wav", dtype="float32")
if len(samples.shape) > 1:
    samples = samples[:, 0]

window_size = 512  # 32ms at 16kHz
for i in range(0, len(samples), window_size):
    chunk = samples[i:i+window_size]
    vad.accept_waveform(chunk)
    while not vad.empty():
        segment = vad.front()
        duration = len(segment.samples) / sr
        start = segment.start / sr
        print(f"Speech: {start:.2f}s, duration: {duration:.2f}s")
        vad.pop()

vad.flush()
while not vad.empty():
    segment = vad.front()
    print(f"Speech: {segment.start/sr:.2f}s")
    vad.pop()
```

### VAD Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| threshold | 0.5 | Speech detection threshold (0-1). Lower = more sensitive |
| min_silence_duration | 0.5 | Min silence to split segments (seconds) |
| min_speech_duration | 0.25 | Min speech duration to keep (seconds) |
| max_speech_duration | inf | Max speech segment length |
| window_size | 512 | Samples per chunk (512 for 16kHz) |

### VAD + Microphone (Real-time)

```python
import sounddevice as sd
import sherpa_onnx

config = sherpa_onnx.VadModelConfig()
config.silero_vad.model = "./silero_vad.onnx"
config.silero_vad.threshold = 0.5
config.sample_rate = 16000

vad = sherpa_onnx.VoiceActivityDetector(config, buffer_size_in_seconds=30)

def callback(indata, frames, time, status):
    vad.accept_waveform(indata[:, 0])
    while not vad.empty():
        segment = vad.front()
        print(f"Speech detected! {len(segment.samples)/16000:.2f}s")
        vad.pop()

with sd.InputStream(samplerate=16000, channels=1, callback=callback, blocksize=512):
    print("Listening for speech...")
    import time
    while True:
        time.sleep(0.1)
```

## Speech Enhancement

### GTCRN (Recommended)

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/speech-enhancement-models/gtcrn_simple.onnx
```

```python
import sherpa_onnx
import numpy as np
import soundfile as sf

config = sherpa_onnx.OfflineSpeechDenoiserGtcrnModelConfig(
    model="./gtcrn_simple.onnx",
)
denoiser_config = sherpa_onnx.OfflineSpeechDenoiserModelConfig(gtcrn=config)
denoiser = sherpa_onnx.OfflineSpeechDenoiser(denoiser_config)

samples, sr = sf.read("noisy.wav", dtype="float32", always_2d=True)
samples = np.ascontiguousarray(samples[:, 0])

result = denoiser.run(samples, sr)
sf.write("clean.wav", result.samples, samplerate=result.sample_rate)
```

### DPDFNet

```python
config = sherpa_onnx.OfflineSpeechDenoiserDpdfNetModelConfig(
    model="./dpdfnet.onnx",
)
denoiser_config = sherpa_onnx.OfflineSpeechDenoiserModelConfig(dpdfnet=config)
denoiser = sherpa_onnx.OfflineSpeechDenoiser(denoiser_config)
```

## Audio Tagging

Classify audio content (music, speech, environmental sounds).

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/audio-tagging-models/sherpa-onnx-zipformer-audio-tagging-2024-04-09.tar.bz2
tar xvf sherpa-onnx-zipformer-audio-tagging-2024-04-09.tar.bz2
```

```python
import sherpa_onnx

config = sherpa_onnx.AudioTaggingConfig(
    model=sherpa_onnx.AudioTaggingModelConfig(
        zipformer=sherpa_onnx.OfflineZipformerAudioTaggingModelConfig(
            model="./sherpa-onnx-zipformer-audio-tagging-2024-04-09/model.onnx",
        ),
    ),
    labels="./sherpa-onnx-zipformer-audio-tagging-2024-04-09/class_labels_indices.csv",
    top_k=5,
)

tagger = sherpa_onnx.AudioTagging(config)
stream = tagger.create_stream()
stream.accept_wave_file("audio.wav")
result = tagger.compute(stream)

for event in result:
    print(f"{event.name}: {event.prob:.3f}")
```

## Keyword Spotting (KWS)

Detect specific keywords/wake words in audio stream.

```bash
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/sherpa-onnx-kws-zipformer-wenetspeech-3.3M-2024-01-01.tar.bz2
tar xvf sherpa-onnx-kws-zipformer-wenetspeech-3.3M-2024-01-01.tar.bz2
```

```python
import sherpa_onnx

config = sherpa_onnx.KeywordSpotterConfig(
    model=sherpa_onnx.OnlineTransducerModelConfig(
        encoder="./model/encoder.onnx",
        decoder="./model/decoder.onnx",
        joiner="./model/joiner.onnx",
    ),
    tokens="./model/tokens.txt",
    keywords_file="./keywords.txt",
    num_threads=2,
    keywords_threshold=0.1,
    keywords_score=1.0,
)

spotter = sherpa_onnx.KeywordSpotter(config)
stream = spotter.create_stream()

# Feed audio chunks
# stream.accept_waveform(sample_rate, samples)
# while spotter.is_ready(stream):
#     spotter.decode_stream(stream)
# result = spotter.get_result(stream)
```

### Keywords File Format
```
# keywords.txt — one keyword per line, with optional boosting score
你好小明 @0.5
开灯 @1.0
关灯 @1.0
```

## Source Separation

Separate vocals from music (Spleeter/UVR-based).

```python
# Models: https://github.com/k2-fsa/sherpa-onnx/releases/tag/source-separation-models
import sherpa_onnx

config = sherpa_onnx.OfflineSourceSeparationConfig(
    model=sherpa_onnx.OfflineSourceSeparationModelConfig(
        spleeter=sherpa_onnx.OfflineSourceSeparationSpleeterModelConfig(
            model="./spleeter-2stems.onnx",
        ),
    ),
)
separator = sherpa_onnx.OfflineSourceSeparation(config)
# Process audio...
```

## Spoken Language Identification

Detect which language is being spoken.

```python
# Uses Whisper models for language ID
# See: https://k2-fsa.github.io/sherpa/onnx/spoken-language-identification/
```

## Add Punctuation

```python
# Models: https://github.com/k2-fsa/sherpa-onnx/releases/tag/punctuation-models
import sherpa_onnx

config = sherpa_onnx.OfflinePunctuationConfig(
    model=sherpa_onnx.OfflinePunctuationModelConfig(
        ct_transformer="./punctuation-model/model.onnx",
    ),
)
punct = sherpa_onnx.OfflinePunctuation(config)
result = punct.add_punctuation("hello world how are you")
print(result)  # "Hello world, how are you?"
```
