# Speaker Processing with sherpa-onnx

## Capabilities

| Task | Class | Description |
|------|-------|-------------|
| Speaker diarization | `OfflineSpeakerDiarization` | "Who spoke when" — segment audio by speaker |
| Speaker identification | `SpeakerEmbeddingExtractor` + `SpeakerEmbeddingManager` | Identify known speakers |
| Speaker verification | `SpeakerEmbeddingExtractor` | Verify if two audio clips are same speaker |

## Speaker Diarization

### Download Models

Requires 2 models: segmentation + embedding.

```bash
# Segmentation model (pyannote-based)
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2
tar xvf sherpa-onnx-pyannote-segmentation-3-0.tar.bz2

# Speaker embedding model (3D-Speaker)
curl -SL -O https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common.onnx
```

### Run Diarization

```python
import sherpa_onnx

config = sherpa_onnx.OfflineSpeakerDiarizationConfig(
    segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
        pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(
            model="./sherpa-onnx-pyannote-segmentation-3-0/model.onnx",
        ),
    ),
    embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(
        model="./3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common.onnx",
    ),
    min_duration_on=0.3,   # min speech duration (seconds)
    min_duration_off=0.5,  # min silence duration (seconds)
)

sd = sherpa_onnx.OfflineSpeakerDiarization(config)

# Process audio file
import soundfile as sf
samples, sample_rate = sf.read("meeting.wav", dtype="float32")
if len(samples.shape) > 1:
    samples = samples[:, 0]

result = sd.process(samples)

for segment in result:
    print(f"Speaker {segment.speaker}: {segment.start:.2f}s - {segment.end:.2f}s")
```

**Validate:** Output shows speaker labels with time ranges.

### With Progress Callback

```python
def progress_callback(num_processed, num_total):
    print(f"Progress: {num_processed}/{num_total}")
    return 0  # return 0 to continue, 1 to stop

result = sd.process(samples, callback=progress_callback)
```

## Speaker Identification

Register known speakers, then identify from new audio.

### Setup

```python
import sherpa_onnx
import soundfile as sf
import numpy as np

extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
    model="./3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common.onnx",
    num_threads=2,
)

manager = sherpa_onnx.SpeakerEmbeddingManager(extractor.dim)
```

### Register Speakers

```python
def extract_embedding(extractor, audio_path):
    samples, sr = sf.read(audio_path, dtype="float32")
    if len(samples.shape) > 1:
        samples = samples[:, 0]
    stream = extractor.create_stream()
    stream.accept_waveform(sr, samples.tolist())
    stream.input_finished()
    assert extractor.is_ready(stream)
    return extractor.compute(stream)

# Register speaker "Alice" with enrollment audio
embedding_alice = extract_embedding(extractor, "alice_enrollment.wav")
manager.add("Alice", embedding_alice)

# Register speaker "Bob"
embedding_bob = extract_embedding(extractor, "bob_enrollment.wav")
manager.add("Bob", embedding_bob)

# Can register multiple embeddings per speaker
embedding_alice2 = extract_embedding(extractor, "alice_enrollment2.wav")
manager.add("Alice", embedding_alice2)
```

### Identify Speaker

```python
embedding_unknown = extract_embedding(extractor, "unknown.wav")
name = manager.search(embedding_unknown, threshold=0.5)
if name:
    print(f"Identified: {name}")
else:
    print("Unknown speaker")
```

### Manage Speakers

```python
# List all registered speakers
names = manager.all_speaker_names()

# Remove a speaker
manager.remove("Alice")

# Check if speaker exists
exists = manager.contains("Bob")

# Get number of speakers
count = manager.num_speakers
```

## Speaker Verification

Compare two audio clips to determine if same speaker.

```python
import sherpa_onnx
import numpy as np

extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
    model="./3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common.onnx",
)

embedding1 = extract_embedding(extractor, "audio1.wav")
embedding2 = extract_embedding(extractor, "audio2.wav")

# Compute cosine similarity
similarity = np.dot(embedding1, embedding2) / (
    np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
)

threshold = 0.5
if similarity > threshold:
    print(f"Same speaker (similarity: {similarity:.3f})")
else:
    print(f"Different speakers (similarity: {similarity:.3f})")
```

## Speaker Embedding Models

| Model | Source | Languages |
|-------|--------|-----------|
| 3dspeaker_speech_eres2net_base_200k_sv_zh-cn_16k-common | 3D-Speaker | Chinese |
| wespeaker_en_voxceleb_resnet34 | WeSpeaker | English |
| nemo_en_speakerverification_speakernet | NeMo | English |

Download from: https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models

## Speaker Segmentation Models

| Model | Source |
|-------|--------|
| sherpa-onnx-pyannote-segmentation-3-0 | pyannote 3.0 |
| sherpa-onnx-reverb-diarization-v1 | Reverb |

Download from: https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-segmentation-models

## Troubleshooting

```
Diarization gives wrong speaker count?
├─ Adjust min_duration_on/off thresholds
├─ Try different embedding model
└─ Ensure audio is 16kHz mono

Speaker ID always returns unknown?
├─ Lower threshold (default 0.5, try 0.3)
├─ Enrollment audio too short → use 5+ seconds
├─ Noisy enrollment → use clean audio
└─ Wrong sample rate → resample to 16kHz
```
