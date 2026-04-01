# Engine Comparison: vLLM vs TGI

Feature-by-feature comparison of vLLM and HuggingFace Text Generation Inference (TGI) for local LLM serving.

## Feature Comparison

| Feature | vLLM | TGI |
|---|---|---|
| **Installation** | `pip install vllm` | Docker image (primary) |
| **Deployment** | Python process or Docker | Docker (recommended) |
| **OpenAI-compatible API** | Native `/v1/` endpoints | Native `/v1/` endpoints |
| **Tensor parallelism** | `--tensor-parallel-size` | `--num-shard` |
| **Pipeline parallelism** | Supported | Not supported |
| **PagedAttention** | Yes (core feature) | Yes |
| **Continuous batching** | Yes | Yes |
| **Speculative decoding** | Yes | Yes |
| **Prefix caching** | Yes (automatic) | Yes |
| **Grammar-constrained output** | Via Outlines integration | Built-in (JSON schema, regex) |
| **Watermarking** | Not built-in | Built-in `--watermark` |
| **Prometheus metrics** | Yes | Yes (`/metrics`) |
| **Multi-LoRA serving** | Yes | Yes |
| **Vision models** | Yes (LLaVA, etc.) | Yes |
| **Embedding models** | Yes | Limited |

## Quantization Support

| Format | vLLM | TGI |
|---|---|---|
| AWQ | ✅ `--quantization awq` | ✅ `--quantize awq` |
| GPTQ | ✅ `--quantization gptq` | ✅ `--quantize gptq` |
| GGUF | ✅ (pass file path) | ❌ Not supported |
| bitsandbytes 4-bit | ❌ | ✅ `--quantize bitsandbytes-nf4` |
| bitsandbytes 8-bit | ❌ | ✅ `--quantize bitsandbytes-fp4` |
| FP8 | ✅ `--quantization fp8` | ❌ |
| EETQ | ❌ | ✅ `--quantize eetq` |
| Marlin (optimized GPTQ) | ✅ `--quantization marlin` | ❌ |
| SqueezeLLM | ✅ `--quantization squeezellm` | ❌ |

**Summary**:
- vLLM has broader quantization format support (GGUF, FP8, Marlin, SqueezeLLM)
- TGI supports runtime bitsandbytes quantization (no pre-quantized model needed)
- Both support the most common formats: AWQ and GPTQ

## Model Support

Both engines support a wide range of HuggingFace models. Key differences:

| Model Type | vLLM | TGI |
|---|---|---|
| Llama / Llama 2 / Llama 3 | ✅ | ✅ |
| Mistral / Mixtral | ✅ | ✅ |
| Qwen / Qwen2 | ✅ | ✅ |
| Falcon | ✅ | ✅ |
| Phi-3 | ✅ | ✅ |
| Gemma / Gemma 2 | ✅ | ✅ |
| Command R | ✅ | ✅ |
| StarCoder / StarCoder2 | ✅ | ✅ |
| DeepSeek | ✅ | ✅ |
| Custom architectures | `--trust-remote-code` | `--trust-remote-code` |

vLLM generally adds support for new architectures faster due to its larger open-source contributor base.

## Performance Characteristics

| Aspect | vLLM | TGI |
|---|---|---|
| **Throughput (tokens/sec)** | Generally higher for large batches | Competitive, slightly lower at scale |
| **Latency (time to first token)** | Low, CUDA graphs help | Low, Flash Attention optimized |
| **Memory efficiency** | PagedAttention minimizes waste | PagedAttention, similar efficiency |
| **Multi-GPU scaling** | Excellent TP scaling | Good sharding, slightly more overhead |
| **Cold start time** | Moderate (model loading) | Moderate (Docker + model loading) |
| **Concurrent request handling** | Excellent (continuous batching) | Good (continuous batching) |

### Throughput Benchmarks (Approximate)

These are rough guidelines — actual performance depends on hardware, model, and workload:

| Model | Engine | GPU | Throughput (tokens/sec) | Config |
|---|---|---|---|---|
| Llama-3.1-8B (FP16) | vLLM | A100 80GB | ~2500-3500 | Default settings |
| Llama-3.1-8B (FP16) | TGI | A100 80GB | ~2000-3000 | Default settings |
| Llama-3.1-8B (AWQ 4-bit) | vLLM | RTX 4090 24GB | ~1500-2500 | `--quantization awq` |
| Llama-3.1-8B (AWQ 4-bit) | TGI | RTX 4090 24GB | ~1200-2000 | `--quantize awq` |
| Llama-3.1-70B (FP16) | vLLM | 4×A100 80GB | ~1000-1500 | `--tensor-parallel-size 4` |
| Llama-3.1-70B (FP16) | TGI | 4×A100 80GB | ~800-1200 | `--num-shard 4` |

**Note**: Benchmarks are approximate and vary significantly with batch size, sequence length, and hardware configuration. Always benchmark on your specific setup.

## API Compatibility

### OpenAI-Compatible Endpoints

Both engines support the OpenAI API format:

| Endpoint | vLLM | TGI |
|---|---|---|
| `/v1/chat/completions` | ✅ | ✅ |
| `/v1/completions` | ✅ | ✅ |
| `/v1/models` | ✅ | ✅ |
| `/v1/embeddings` | ✅ | ❌ |

### Native Endpoints

| Endpoint | vLLM | TGI |
|---|---|---|
| `/generate` | ❌ | ✅ |
| `/generate_stream` | ❌ | ✅ |
| `/health` | ✅ | ✅ |
| `/metrics` | ✅ | ✅ |
| `/info` | ❌ | ✅ |

## Decision Guide

### Choose vLLM When

- You need maximum throughput for high-concurrency workloads
- You want to serve GGUF or FP8 quantized models
- You prefer pip install over Docker
- You need pipeline parallelism for very large models
- You want speculative decoding with a draft model
- You need embedding model serving

### Choose TGI When

- You prefer Docker-native deployment
- You need grammar-constrained generation (JSON schema, regex)
- You want built-in text watermarking
- You need runtime bitsandbytes quantization without pre-quantizing
- You're deeply integrated with the HuggingFace ecosystem
- You want built-in Prometheus metrics at `/metrics`

### Either Engine Works Well For

- Standard chat/completion serving with OpenAI-compatible API
- Multi-GPU tensor parallelism
- AWQ/GPTQ quantized model serving
- Production deployments with monitoring
- Streaming responses
