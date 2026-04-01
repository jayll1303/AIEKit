# Triton Troubleshooting

## Model Loading Errors

### "ModelLoadFailed"
1. Check config.pbtxt syntax and required fields
2. Verify model file at correct path: `<model>/1/model.onnx`
3. Check backend available in container
4. Run with `--log-verbose=1` for details

### "Ensemble tensor inconsistent data type"
Data type mismatch between ensemble steps. Check every step's input/output types match.

### "Unsupported opset"
ONNX model uses newer opset than ORT supports. Downgrade opset:
```python
from onnx import version_converter
model = onnx.load("model.onnx")
converted = version_converter.convert_version(model, 13)
onnx.save(converted, "model_v13.onnx")
```

## CUDA / GPU

### "CUDA out of memory"
- Reduce `max_batch_size`
- Reduce `instance_group` count
- Use int8 quantized model
- Check: `nvidia-smi`

### "free(): invalid pointer" warning
ONNX Runtime warning on model load. Harmless, ignore.

### "N Memcpy nodes added for CUDAExecutionProvider"
Normal CPU↔GPU tensor transfer warning. Harmless.

## Python Backend

### "Stub process crashed"
- Python exception not caught
- Segfault from C extension
- OOM in Python process
- Debug: `--log-verbose=1`, test model.py standalone

### Feature_extractor loads slowly (~3 min)
Python backend importing heavy libs (torch, kaldifeat). Normal — wait for "successfully loaded" log.

## Network

### "Connection refused"
```bash
curl localhost:8000/v2/health/ready    # Check server
netstat -tlnp | grep 8001             # Check port
# Docker: ensure -p 8001:8001
```

### Port conflict on restart
```bash
pkill -f tritonserver && sleep 3
tritonserver --model-repository=./model_repo --grpc-port 8003
```

## Performance

### Slow inference
```bash
# Check GPU utilization
nvidia-smi dmon -s u

# Increase instances for bottleneck
instance_group [ { count: 4, kind: KIND_GPU } ]

# Enable batching
dynamic_batching { preferred_batch_size: [4, 8], max_queue_delay_microseconds: 100 }

# Profile
pip install perf-analyzer
perf_analyzer -m <model> -u localhost:8001 -i grpc --concurrency-range 1:16
```

### Memory not released
Triton uses memory arena. Try:
```bash
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4 tritonserver ...
```

## Debug Checklist

1. `nvidia-smi` — GPU available? Driver?
2. `tritonserver --log-verbose=1` — full logs
3. `find model_repo -type f` — correct structure?
4. config.pbtxt — no placeholders, types correct?
5. Test model standalone (onnxruntime / python import)
6. `curl localhost:8000/v2/health/ready` — server up?
7. Client: correct port, model name, tensor names?
