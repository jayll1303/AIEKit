# Testing Patterns — Audio API

## Core Principle: Mock at Service Boundary

Don't mock the model directly. Mock `InferenceService.synthesize()` — this tests
the full HTTP layer without needing actual model weights.

## conftest.py Template

```python
from __future__ import annotations
import struct
from unittest.mock import AsyncMock, patch
import pytest
import torch
from fastapi.testclient import TestClient
from my_audio_server.app import create_app
from my_audio_server.config import Settings

def make_silence_tensor(duration_s: float = 1.0) -> torch.Tensor:
    """Return a silent (1, T) float32 tensor at 24kHz."""
    return torch.zeros(1, int(24_000 * duration_s))

def make_wav_bytes(duration_frames: int = 0, sample_rate: int = 24000) -> bytes:
    """Minimal valid WAV file for upload tests."""
    data_size = duration_frames * 2
    return (
        b"RIFF" + struct.pack("<I", 36 + data_size) + b"WAVE"
        + b"fmt " + struct.pack("<I", 16)
        + struct.pack("<HHIIHH", 1, 1, sample_rate, sample_rate * 2, 2, 16)
        + b"data" + struct.pack("<I", data_size) + b"\x00" * data_size
    )

def _mock_synthesize(req):
    from my_audio_server.services.inference import SynthesisResult
    return SynthesisResult(
        tensors=[make_silence_tensor(1.0)],
        duration_s=1.0,
        latency_s=0.05,
    )

@pytest.fixture
def settings(tmp_path_factory):
    return Settings(
        device="cpu",
        num_step=4,
        max_concurrent=1,
        api_key="",
        profile_dir=tmp_path_factory.mktemp("profiles"),
    )

@pytest.fixture
def client(settings):
    app = create_app(settings)
    with patch("my_audio_server.services.model.ModelService.load", new_callable=AsyncMock):
        with patch(
            "my_audio_server.services.model.ModelService.is_loaded",
            new_callable=lambda: property(lambda self: True),
        ):
            with TestClient(app) as c:
                c.app.state.inference_svc.synthesize = AsyncMock(
                    side_effect=_mock_synthesize
                )
                yield c

@pytest.fixture
def sample_audio_bytes():
    return make_wav_bytes(duration_frames=100)
```

## Test Categories

### 1. Speech Endpoint Tests

```python
def test_speech_returns_wav(client):
    resp = client.post("/v1/audio/speech", json={"input": "Hello", "voice": "auto"})
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "audio/wav"
    assert resp.content[:4] == b"RIFF"

def test_speech_empty_text_rejected(client):
    resp = client.post("/v1/audio/speech", json={"input": "", "voice": "auto"})
    assert resp.status_code == 422

def test_speech_pcm_format(client):
    resp = client.post("/v1/audio/speech", json={"input": "Hello", "response_format": "pcm"})
    assert resp.status_code == 200
    assert "audio/pcm" in resp.headers["content-type"]

def test_openai_model_names_accepted(client):
    for model in ("tts-1", "tts-1-hd", "your-model"):
        resp = client.post("/v1/audio/speech", json={"model": model, "input": "Hello"})
        assert resp.status_code == 200
```

### 2. Streaming Tests

```python
def test_streaming_pcm_headers(client):
    resp = client.post("/v1/audio/speech", json={"input": "Hello.", "stream": True})
    assert resp.status_code == 200
    assert resp.headers.get("X-Audio-Sample-Rate") == "24000"
    assert resp.headers.get("X-Audio-Format") == "pcm-int16-le"

def test_streaming_no_wav_header(client):
    resp = client.post("/v1/audio/speech", json={"input": "Hello.", "stream": True})
    if len(resp.content) >= 4:
        assert resp.content[:4] != b"RIFF", "PCM stream must not contain WAV header"

def test_streaming_returns_bytes(client):
    resp = client.post("/v1/audio/speech", json={"input": "Hello.", "stream": True})
    assert len(resp.content) > 0
```

### 3. Health/Metrics Tests

```python
def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] in ("ok", "loading")

def test_metrics_returns_counters(client):
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "requests_total" in resp.json()
```

### 4. Audio Upload Validation Tests

```python
def test_invalid_audio_rejected(client, tmp_path):
    fake = tmp_path / "fake.wav"
    fake.write_text("not audio")
    with open(fake, "rb") as f:
        resp = client.post(
            "/v1/audio/speech/clone",
            data={"text": "Hello"},
            files={"ref_audio": ("fake.wav", f, "audio/wav")},
        )
    assert resp.status_code == 422
    assert "could not parse" in resp.json()["detail"]
```
