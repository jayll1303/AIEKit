# Triton Python Backend & BLS

## TritonPythonModel Template

```python
import triton_python_backend_utils as pb_utils
import numpy as np
import json

class TritonPythonModel:
    def initialize(self, args):
        self.model_config = json.loads(args['model_config'])
        output_config = pb_utils.get_output_config_by_name(self.model_config, "OUTPUT")
        self.output_dtype = pb_utils.triton_string_to_numpy(output_config['data_type'])

    def execute(self, requests):
        responses = []
        for request in requests:
            input_tensor = pb_utils.get_input_tensor_by_name(request, "INPUT")
            input_data = input_tensor.as_numpy()
            result = self._process(input_data)
            output_tensor = pb_utils.Tensor("OUTPUT", result.astype(self.output_dtype))
            responses.append(pb_utils.InferenceResponse(output_tensors=[output_tensor]))
        return responses

    def finalize(self):
        pass
```

## BLS (Business Logic Scripting)

Call other Triton models from within Python backend. ONLY in `execute()`.

```python
def execute(self, requests):
    responses = []
    for request in requests:
        input_data = pb_utils.get_input_tensor_by_name(request, "RAW").as_numpy()

        # Call another model
        infer_req = pb_utils.InferenceRequest(
            model_name="encoder",
            requested_output_names=["encoder_out"],
            inputs=[pb_utils.Tensor("x", input_data)]
        )
        infer_resp = infer_req.exec()

        if infer_resp.has_error():
            raise pb_utils.TritonModelException(infer_resp.error().message())

        encoder_out = pb_utils.get_output_tensor_by_name(infer_resp, "encoder_out").as_numpy()
        # ... continue processing ...
    return responses
```

## Async BLS

```python
async def execute(self, requests):
    responses = []
    for request in requests:
        infer_req = pb_utils.InferenceRequest(
            model_name="sub_model",
            requested_output_names=["OUTPUT"],
            inputs=[pb_utils.Tensor("INPUT", data)]
        )
        infer_resp = await infer_req.async_exec()
        # ...
    return responses
```

## Decoupled Mode (Streaming)

```python
def execute(self, requests):
    for request in requests:
        sender = request.get_response_sender()
        for chunk in self._generate(request):
            sender.send(pb_utils.InferenceResponse(output_tensors=[pb_utils.Tensor("OUT", chunk)]))
        sender.send(flags=pb_utils.TRITONSERVER_RESPONSE_COMPLETE_FINAL)
    return None  # Decoupled returns None
```

Config: `model_transaction_policy { decoupled: true }`

## String I/O

```python
# Receive
raw = pb_utils.get_input_tensor_by_name(request, "TEXT").as_numpy()
text = raw[0].decode("utf-8")

# Send
output = pb_utils.Tensor("RESULT", np.array([result.encode("utf-8")], dtype=object))
```

## GPU Tensors (Zero-Copy)

```python
import torch

# Receive GPU tensor
torch_tensor = torch.from_dlpack(input_tensor.to_dlpack())

# Send GPU tensor
output_tensor = pb_utils.Tensor.from_dlpack("OUTPUT", torch.utils.dlpack.to_dlpack(result))
```

## Custom Execution Environment

```bash
conda create -n custom python=3.10 && conda activate custom
pip install transformers tokenizers
conda-pack -o custom_env.tar.gz
# Place in model_repo/my_model/custom_env.tar.gz
```

Config: `parameters { key: "EXECUTION_ENV_PATH" value: { string_value: "$$TRITON_MODEL_DIRECTORY/custom_env.tar.gz" } }`

## Common Errors

| Error | Fix |
|---|---|
| ModuleNotFoundError | Install in container or use custom env |
| BLS only in execute() | Move BLS calls out of initialize/finalize |
| Stub process crashed | Check Python logs, memory, C extensions |
| Numpy dtype mismatch | Use `.astype(self.output_dtype)` |
| NGC containers: `python3` only | No `python` command, always `python3` |
