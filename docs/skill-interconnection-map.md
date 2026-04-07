# Skill Interconnection Map

> Bản đồ quan hệ giữa 29 AIE-Skills + 3 Powers — dùng để hiểu skill nào chain sang skill nào, tránh overlap, và guide agent chọn đúng skill.

## Skill Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    POWERS (MCP Integration)                   │
│  power-huggingface (Hub API)  │  power-gpu-monitor (GPU/VRAM)│
│  power-sentry (Error Tracking & Debugging)                   │
├─────────────────────────────────────────────────────────────┤
│                    APPLICATION LAYER                         │
│  freqtrade  │  ultralytics-yolo  │  k2-training-pipeline    │
│  sherpa-onnx │  arxiv-reader      │  notebook-workflows      │
│  paddleocr   │  fastapi-at-scale  │  hf-speech-to-speech-pipeline │
│  openai-audio-api  │  opentelemetry                           │
├─────────────────────────────────────────────────────────────┤
│                    WORKFLOW LAYER                             │
│  hf-transformers-trainer  │  text-embeddings-rag             │
│  model-quantization       │  experiment-tracking             │
│  unsloth-training                                            │
├─────────────────────────────────────────────────────────────┤
│                    SERVING LAYER                              │
│  vllm-tgi-inference  │  sglang-serving  │  triton-deployment │
│  text-embeddings-inference  │  ollama-local-llm              │
│  llama-cpp-inference  │  tensorrt-llm                        │
├─────────────────────────────────────────────────────────────┤
│                    INFRASTRUCTURE LAYER                       │
│  python-project-setup  │  python-ml-deps  │  docker-gpu-setup│
│  python-quality-testing │  hf-hub-datasets                   │
├─────────────────────────────────────────────────────────────┤
│                    META LAYER                                 │
│  aie-skills-installer                                        │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Matrix

Đọc theo hàng: skill ở cột trái phụ thuộc vào skills ở các cột.

| Skill | python-ml-deps | hf-hub-datasets | docker-gpu-setup | model-quantization | vllm-tgi-inference | triton-deployment | hf-transformers-trainer | experiment-tracking |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| hf-transformers-trainer | ● | ● | | | | | | ○ |
| model-quantization | ● | ● | | | | | | |
| vllm-tgi-inference | ● | | ● | ○ | | | | |
| triton-deployment | ● | | ● | | | | | |
| text-embeddings-rag | ● | ● | | | ○ | | | |
| text-embeddings-inference | | | ● | | | | | |
| ultralytics-yolo | ● | | ○ | | | ○ | | ○ |
| k2-training-pipeline | ● | ● | ○ | | | | | ○ |
| sherpa-onnx | ● | ● | | | | | | |
| freqtrade | ● | | ○ | | | | | |
| experiment-tracking | ● | | | | | | ○ | |
| unsloth-training | ● | ● | | ○ | ○ | | | ○ |
| paddleocr | ● | | ○ | | | ○ | | ○ |
| ollama-local-llm | | | ○ | ○ | | | | |
| llama-cpp-inference | ● | ○ | ○ | ○ | | | | |
| sglang-serving | ● | | ● | ○ | | | | |
| tensorrt-llm | ● | | ● | ○ | | ○ | | |
| hf-speech-to-speech-pipeline | ● | ○ | ○ | | | | | |
| fastapi-at-scale | | | ○ | | | | | |
| openai-audio-api | ○ | | ○ | | | | | |
| opentelemetry | ○ | | ○ | | | | | |

● = hard dependency (thường cần)  ○ = soft dependency (optional, tùy workflow)

## Common Workflow Chains

### 1. LLM Fine-tune → Serve

```
python-project-setup → python-ml-deps → hf-hub-datasets
    → hf-transformers-trainer (+ experiment-tracking)
    → model-quantization
    → vllm-tgi-inference (hoặc triton-deployment)
    → docker-gpu-setup (containerize)
```

### 1b. LLM Fine-tune with Unsloth (2x faster) → Serve

```
python-ml-deps → hf-hub-datasets
    → unsloth-training (SFT/DPO/GRPO, + experiment-tracking)
    → export GGUF (built-in) hoặc merged_16bit
    → vllm-tgi-inference / Ollama
```

### 2. RAG Pipeline

```
python-ml-deps → hf-hub-datasets
    → text-embeddings-rag (chunking, indexing, retrieval)
    → vllm-tgi-inference (generation backend)
```

### 3. Computer Vision (YOLO)

```
python-ml-deps → ultralytics-yolo (train, predict, export)
    → triton-deployment (production serving)
    → docker-gpu-setup (containerize)
```

### 4. Speech Processing

```
python-ml-deps → hf-hub-datasets (download speech data)
    → k2-training-pipeline (train ASR/TTS)
    → sherpa-onnx (deploy offline inference)
```

### 4b. Speech-to-Speech Pipeline (real-time voice agent)

```
python-ml-deps → hf-hub-datasets (download STT/LLM/TTS models)
    → hf-speech-to-speech-pipeline (queue-chained pipeline)
    → docker-gpu-setup (containerize, optional)
```

### 5. Quantize & Deploy (no training)

```
hf-hub-datasets (download model)
    → model-quantization (GGUF/GPTQ/AWQ)
    → vllm-tgi-inference (serve quantized)
```

### 5b. GGUF Local Inference (llama.cpp)

```
hf-hub-datasets (download GGUF)
    → llama-cpp-inference (llama-server / llama-cpp-python)
    → model-quantization (if need custom quantization)
```

### 6. Local LLM with Ollama

```
ollama-local-llm (pull + run, or import GGUF)
    → model-quantization (convert HF → GGUF if needed)
    → docker-gpu-setup (containerize Ollama if needed)
```

### 7. FastAPI Backend at Scale

```
python-project-setup → fastapi-at-scale (structure, auth, DB)
    → docker-gpu-setup (containerize, optional GPU for ML endpoints)
```

### 8. OpenAI-Compatible Audio API

```
python-project-setup → python-ml-deps (torch, torchaudio)
    → hf-hub-datasets (download TTS model)
    → openai-audio-api (build API server)
    → docker-gpu-setup (containerize)
```

### 9. Production App with Error Tracking

```
python-project-setup → fastapi-at-scale (structure, auth, DB)
    → power-sentry (Sentry SDK init, error capture, tracing)
    → docker-gpu-setup (containerize with SENTRY_DSN env var)
```

### 10. Observable Service with OpenTelemetry

```
python-project-setup → python-ml-deps (otel packages)
    → fastapi-at-scale (structure, auth, DB)
    → opentelemetry (instrument + collector + sampling)
    → docker-gpu-setup (containerize with collector sidecar)
```

## Serving Alternatives

| Scenario | Skill | Khi nào dùng |
|----------|-------|-------------|
| LLM inference (OpenAI-compatible API) | vllm-tgi-inference | Single/multi-GPU, quick setup |
| Max throughput NVIDIA GPU, FP8/INT4 | tensorrt-llm | trtllm-build, kernel fusion, Triton backend |
| LLM inference, structured output, prefix caching | sglang-serving | RadixAttention, JSON/regex/EBNF constrained decoding |
| GGUF inference, CPU+GPU, max control | llama-cpp-inference | llama-server, llama-cli, llama-cpp-python |
| Local LLM, single-user, CLI-first | ollama-local-llm | One-command setup, Modelfile customization |
| Multi-model, ensemble, custom pipeline | triton-deployment | Production, multi-backend, batching |
| Embedding models only | text-embeddings-inference | TEI Docker, embedding API |
| Edge/offline speech | sherpa-onnx | No internet, mobile, embedded |
| Audio/TTS API (OpenAI-compatible) | openai-audio-api | FastAPI + streaming + batching |

## Khi thêm skill mới

1. Xác định skill thuộc layer nào (Application / Workflow / Serving / Infrastructure)
2. Map dependencies: skill mới phụ thuộc vào skills nào? (thêm vào Dependency Matrix)
3. Map reverse dependencies: skills nào sẽ reference đến skill mới? (update scope boundaries)
4. Thêm vào workflow chains nếu skill tham gia pipeline phổ biến
5. Update file này và README.md

## Powers — MCP Integration Layer

Powers nằm trên cùng, cung cấp external tool access cho agent qua MCP protocol.

### power-huggingface

| Connects to | How |
|-------------|-----|
| hf-hub-datasets | search → download workflow |
| hf-transformers-trainer | model discovery → fine-tune |
| unsloth-training | model discovery → fast fine-tune |
| model-quantization | model discovery → quantize |
| vllm-tgi-inference / sglang-serving | model discovery → serve |
| arxiv-reader | paper discovery → full read |

### power-gpu-monitor

| Connects to | How |
|-------------|-----|
| Mọi serving skills | VRAM check trước khi launch server |
| Mọi training skills | VRAM estimation trước khi train |
| model-quantization | OOM → suggest quantize |
| docker-gpu-setup | GPU availability check |

### power-sentry

| Connects to | How |
|-------------|-----|
| fastapi-at-scale | Sentry Python SDK setup cho FastAPI endpoints |
| python-project-setup | Add sentry-sdk dependency |
| docker-gpu-setup | Sentry env vars trong Docker containers |
| backend-development | Error handling patterns → Sentry capture |
