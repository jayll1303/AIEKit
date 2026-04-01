# Triton Client Patterns

## Install

```bash
pip install tritonclient[all]    # gRPC + HTTP
pip install tritonclient[grpc]   # gRPC only
```

## gRPC — Basic

```python
import tritonclient.grpc as grpcclient
import numpy as np

client = grpcclient.InferenceServerClient("localhost:8001")
assert client.is_server_ready()

data = np.random.randn(1, 3, 224, 224).astype(np.float32)
inputs = [grpcclient.InferInput("INPUT", data.shape, "FP32")]
inputs[0].set_data_from_numpy(data)
outputs = [grpcclient.InferRequestedOutput("OUTPUT")]

result = client.infer("my_model", inputs, outputs=outputs)
output = result.as_numpy("OUTPUT")
```

## HTTP — Basic

```python
import tritonclient.http as httpclient

client = httpclient.InferenceServerClient("localhost:8000")
inputs = [httpclient.InferInput("INPUT", list(data.shape), "FP32")]
inputs[0].set_data_from_numpy(data)
result = client.infer("my_model", inputs)
```

## Async (gRPC)

```python
import queue
q = queue.Queue()

def callback(result, error):
    q.put(error if error else result)

client.async_infer("my_model", inputs, outputs=outputs, callback=callback)
result = q.get(timeout=10)
```

## String I/O

```python
# Send string
text_bytes = np.array([b"hello world"], dtype=object)
inputs = [grpcclient.InferInput("TEXT", [1], "BYTES")]
inputs[0].set_data_from_numpy(text_bytes)

# Receive string — handle both cases
raw = result.as_numpy("TRANSCRIPTS")[0]
if isinstance(raw, np.ndarray):
    transcript = b" ".join(raw).decode("utf-8").strip()
elif isinstance(raw, bytes):
    transcript = raw.decode("utf-8").strip()
else:
    transcript = str(raw).strip()
```

## Audio Input (ASR)

```python
import soundfile as sf

audio, sr = sf.read("audio.wav", dtype="float32")
wav = audio.astype(np.float32)
wav_lens = np.array([[len(wav)]], dtype=np.int32)

inputs = [
    grpcclient.InferInput("WAV", [1, len(wav)], "FP32"),
    grpcclient.InferInput("WAV_LENS", [1, 1], "INT32"),
]
inputs[0].set_data_from_numpy(wav.reshape(1, -1))
inputs[1].set_data_from_numpy(wav_lens)
result = client.infer("transducer", inputs)
```

## Streaming (Decoupled)

```python
def stream_cb(result, error):
    if not error:
        print(result.as_numpy("OUTPUT"))

client.start_stream(callback=stream_cb)
client.async_stream_infer("streaming_model", inputs)
client.stop_stream()
```

## Ports

| Port | Protocol | Purpose |
|---|---|---|
| 8000 | HTTP | Inference + management |
| 8001 | gRPC | Inference + management |
| 8002 | HTTP | Prometheus metrics |
