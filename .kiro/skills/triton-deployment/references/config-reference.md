# Triton config.pbtxt Reference

## Data Types

| Triton | NumPy | PyTorch | Bytes |
|---|---|---|---|
| TYPE_BOOL | bool | torch.bool | 1 |
| TYPE_UINT8 | uint8 | torch.uint8 | 1 |
| TYPE_INT8 | int8 | torch.int8 | 1 |
| TYPE_INT16 | int16 | torch.int16 | 2 |
| TYPE_INT32 | int32 | torch.int32 | 4 |
| TYPE_INT64 | int64 | torch.int64 | 8 |
| TYPE_FP16 | float16 | torch.float16 | 2 |
| TYPE_FP32 | float32 | torch.float32 | 4 |
| TYPE_FP64 | float64 | torch.float64 | 8 |
| TYPE_STRING | object (bytes) | — | variable |

## Instance Groups

```protobuf
instance_group [
  { count: 2, kind: KIND_GPU, gpus: [0] }
]
# KIND_GPU, KIND_CPU, KIND_MODEL
```

## Dynamic Batching

```protobuf
dynamic_batching {
  preferred_batch_size: [ 4, 8, 16 ]
  max_queue_delay_microseconds: 100
}
```

## Ensemble Model

```protobuf
platform: "ensemble"
max_batch_size: <N>
input [ ... ]
output [ ... ]

ensemble_scheduling {
  step [
    {
      model_name: "step_a"
      model_version: -1
      input_map { key: "step_a_input", value: "ENSEMBLE_INPUT" }
      output_map { key: "step_a_output", value: "intermediate_tensor" }
    },
    {
      model_name: "step_b"
      model_version: -1
      input_map { key: "step_b_input", value: "intermediate_tensor" }
      output_map { key: "step_b_output", value: "ENSEMBLE_OUTPUT" }
    }
  ]
}
```

Rules:
- `platform: "ensemble"` (NOT `backend`)
- No model file in version directory
- Tensor names in maps must match exactly
- Data types must be consistent across steps

## ONNX Backend — TRT Acceleration

```protobuf
backend: "onnxruntime"
optimization {
  execution_accelerators {
    gpu_execution_accelerator : [
      {
        name : "tensorrt"
        parameters { key: "precision_mode" value: "FP16" }
        parameters { key: "max_workspace_size_bytes" value: "1073741824" }
      }
    ]
  }
}
```

## Model Warmup

```protobuf
model_warmup [
  {
    name: "warmup"
    batch_size: 1
    inputs {
      key: "INPUT"
      value: { data_type: TYPE_FP32, dims: [3, 224, 224], zero_data: true }
    }
  }
]
```

## Response Cache

```protobuf
response_cache { enable: true }
```

## Model Control (Runtime)

```bash
# Explicit mode
tritonserver --model-control-mode=explicit --load-model=model_a

# Load/unload via API
curl -X POST localhost:8000/v2/repository/models/my_model/load
curl -X POST localhost:8000/v2/repository/models/my_model/unload
```
