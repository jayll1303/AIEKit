---
name: triton-deployment
description: "Deploy ML models on NVIDIA Triton Inference Server. Use when writing config.pbtxt, structuring model_repository, building ensemble pipelines, configuring dynamic batching, writing tritonclient code, or debugging Triton model loading failures."
---

# Triton Inference Server Deployment

End-to-end guide for deploying models on Triton: model repo structure, config.pbtxt, backends, ensembles, clients, and debugging.

## Scope

This skill handles:
- Writing and validating `config.pbtxt` files for all Triton backends (ONNX, Python, TensorRT, PyTorch)
- Structuring `model_repository/` directories with correct versioning layout
- Building ensemble and BLS (Business Logic Scripting) pipelines
- Configuring dynamic batching, instance groups, and model warmup
- Writing gRPC/HTTP client code with `tritonclient`
- Debugging Triton model loading failures and performance tuning

Does NOT handle:
- Building GPU-enabled Docker containers or selecting NGC base images (→ docker-gpu-setup)
- Installing ML Python packages or resolving CUDA version conflicts (→ python-ml-deps)
- Serving models with vLLM or TGI instead of Triton (→ vllm-tgi-inference)

## When to Use

- Creating or editing `config.pbtxt` files
- Structuring a `model_repository/` directory
- Building ensemble or BLS pipelines
- Writing gRPC/HTTP client code with `tritonclient`
- Debugging "model failed to load" errors
- Configuring dynamic batching or instance groups
- Deploying ONNX, Python, TensorRT, or PyTorch models on Triton

## Model Repository Structure

```
model_repository/
├── <model_name>/
│   ├── config.pbtxt
│   ├── 1/                    # Version directory
│   │   ├── model.onnx        # ONNX backend
│   │   ├── model.plan        # TensorRT backend
│   │   ├── model.pt          # PyTorch (TorchScript)
│   │   └── model.py          # Python backend
│   └── <extra_files>         # Tokenizer, vocab, etc.
```

## Deployment Workflow

⚠️ **HARD GATE:** Do NOT deploy a model before validating that `config.pbtxt` tensor data types and dims match the actual model's input/output signatures. Mismatched types are the #1 cause of silent inference errors.

### 1. Prepare model repository

Place model files in the correct directory structure. Each model needs its own directory with a version subdirectory (e.g., `1/`) containing the model artifact.

**Validate:** Run `find model_repository/ -name "config.pbtxt" | head` — must list at least one config file. If not → verify directory structure matches the template above.

### 2. Write config.pbtxt

```protobuf
name: "<model_name>"
backend: "<backend>"          # onnxruntime | python | pytorch | tensorrt
max_batch_size: <N>           # 0 = batching disabled

input [
  {
    name: "<name>"
    data_type: <TYPE>         # TYPE_FP32, TYPE_INT32, TYPE_STRING, etc.
    dims: [ <d1>, <d2> ]      # -1 = dynamic. Exclude batch dim when max_batch_size > 0
  }
]
output [
  {
    name: "<name>"
    data_type: <TYPE>
    dims: [ <d1> ]
  }
]
```

**Validate:** Tensor names and data types must match the model's actual I/O signature. For ONNX: `python -c "import onnxruntime as ort; s=ort.InferenceSession('model.onnx'); print([(i.name, i.type, i.shape) for i in s.get_inputs()])"`. If mismatch → fix `config.pbtxt` names, types, and dims before proceeding.

### 3. Launch Triton server

```bash
docker run --gpus all --rm -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v $(pwd)/model_repository:/models \
  nvcr.io/nvidia/tritonserver:24.07-py3 \
  tritonserver --model-repository=/models
```

**Validate:** Check server log for `"<model_name>" ... READY` for each model. Run `curl -s localhost:8000/v2/health/ready` — must return HTTP 200. If not → check Troubleshooting reference.

### 4. Test with client

```python
import tritonclient.grpc as grpcclient
import numpy as np

client = grpcclient.InferenceServerClient("localhost:8001")

inputs = [grpcclient.InferInput("input_name", [1, 3, 224, 224], "FP32")]
inputs[0].set_data_from_numpy(np.random.randn(1, 3, 224, 224).astype(np.float32))

result = client.infer("model_name", inputs)
output = result.as_numpy("output_name")
print(output.shape)
```

**Validate:** Client must return output with expected shape. If `StatusCode.UNAVAILABLE` → server not running. If `INVALID_ARG` → input name/shape/type mismatch with config.pbtxt.

## Critical Rules

1. **dims exclude batch dimension** when `max_batch_size > 0`
2. **TYPE_STRING** = bytes in numpy (`dtype=object`), not Python str
3. **Ensemble** uses `platform: "ensemble"`, NOT `backend`
4. **Ensemble tensor types must be consistent** across all steps — most common error
5. **Python backend** file must be `model.py` implementing `TritonPythonModel`
6. **ONNX dynamic axes** → use `-1` in dims

## Ensemble Pipeline Template

```protobuf
name: "ensemble_pipeline"
platform: "ensemble"
max_batch_size: 8

input [ { name: "RAW_INPUT" data_type: TYPE_STRING dims: [ 1 ] } ]
output [ { name: "FINAL_OUTPUT" data_type: TYPE_FP32 dims: [ -1 ] } ]

ensemble_scheduling {
  step [
    {
      model_name: "preprocessor"
      model_version: -1
      input_map { key: "TEXT_IN" value: "RAW_INPUT" }
      output_map { key: "TOKENS_OUT" value: "preprocessed" }
    },
    {
      model_name: "model"
      model_version: -1
      input_map { key: "input_ids" value: "preprocessed" }
      output_map { key: "logits" value: "FINAL_OUTPUT" }
    }
  ]
}
```

⚠️ **HARD GATE:** Do NOT finalize an ensemble pipeline before verifying that every `input_map`/`output_map` tensor name matches the corresponding model's config.pbtxt exactly. Mismatched tensor names cause silent pipeline failures.

## Dynamic Batching Quick Config

```protobuf
dynamic_batching {
  preferred_batch_size: [ 4, 8 ]
  max_queue_delay_microseconds: 100
}
```

| Parameter | Default | Recommendation |
|---|---|---|
| `preferred_batch_size` | none | Set to powers of 2 matching your GPU memory budget |
| `max_queue_delay_microseconds` | 0 | 100-1000 for throughput; 0 for lowest latency |
| `max_batch_size` | 0 (disabled) | Set > 0 to enable batching; match model's max supported batch |

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "I'll skip validating config.pbtxt tensor types — the model will just error if wrong" | Mismatched tensor types can cause silent wrong results, not just errors. Always verify input/output names, types, and dims against the actual model before deploying. |
| "Ensemble tensor names don't need to match exactly — Triton will figure it out" | Triton requires exact string matches for `input_map`/`output_map` keys. A single typo causes the pipeline to fail silently or produce zeros. Always cross-check every step's tensor names. |
| "I can set `max_batch_size > 0` and keep batch dimension in dims" | When `max_batch_size > 0`, Triton manages the batch dimension automatically. Including it in `dims` causes shape mismatch errors. Dims must exclude the batch dimension. |
| "Python backend can use any filename" | Python backend requires exactly `model.py` with a class implementing `TritonPythonModel`. Any other filename is silently ignored and the model fails to load. |
| "I don't need to estimate VRAM — Triton handles memory automatically" | Triton loads all model versions into GPU memory by default. Without estimating VRAM per model and setting `instance_group` counts carefully, multi-model deployments OOM. Always check `nvidia-smi` free VRAM before adding models. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Building the Triton Docker container or selecting NGC base image | docker-gpu-setup | Covers GPU Dockerfile patterns, NGC image selection, NVIDIA Container Toolkit setup |
| Need to resolve CUDA/cuDNN version conflicts for Triton container | python-ml-deps | Handles NVIDIA stack version resolution, driver-CUDA compatibility matrix |
| Quantizing a model to TensorRT or ONNX before deploying on Triton | model-quantization | Covers GGUF, GPTQ, AWQ, TensorRT conversion, and quality validation |
| Serving models with vLLM/TGI instead of Triton | vllm-tgi-inference | Handles vllm serve, TGI Docker, OpenAI-compatible API, simpler single-model serving |

## References

- [Config Reference](references/config-reference.md) — Data types, instance groups, batching, ensemble, warmup
  **Load when:** need detailed config.pbtxt options beyond the minimal template (instance groups, rate limiting, warmup, response cache)
- [Python Backend & BLS](references/python-backend.md) — TritonPythonModel template, BLS, decoupled, GPU tensors
  **Load when:** implementing a Python backend model or using BLS to chain models programmatically instead of ensemble scheduling
- [Client Patterns](references/client-patterns.md) — gRPC/HTTP client code, async, streaming, string I/O
  **Load when:** writing production client code with async inference, streaming, shared memory, or TYPE_STRING handling
- [Troubleshooting](references/troubleshooting.md) — Common errors, debug checklist, performance tuning
  **Load when:** model fails to load, inference returns unexpected results, or need to tune throughput/latency performance