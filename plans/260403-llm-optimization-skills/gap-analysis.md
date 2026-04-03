# Gap Analysis: LLM Speed/Memory/GPU Optimization Skills

> Phân tích 12 repos + 4 bổ sung từ user, so sánh với 20 skills hiện có, đề xuất skills/steering/hooks mới.

## Mapping: Repos → Existing Coverage

| # | Repo | Stars | Existing Skill | Coverage Level | Ghi chú |
|---|------|-------|---------------|----------------|---------|
| 1 | vLLM | 66.5k | `vllm-tgi-inference` | ✅ Đầy đủ | vLLM + TGI trong cùng skill |
| 2 | llama.cpp | 92.2k | `model-quantization` (GGUF conversion) | ⚠️ Một phần | Chỉ cover GGUF conversion, KHÔNG cover llama.cpp inference/server |
| 3 | Ollama | 158k | ❌ Không có | ❌ Thiếu hoàn toàn | Cần skill mới |
| 4 | HF Transformers | 154k | `hf-transformers-trainer` + `hf-hub-datasets` | ✅ Đầy đủ | Training + Hub đã cover |
| 5 | PyTorch | 96.2k | `python-ml-deps` (install) | ⚠️ Một phần | Chỉ cover install, không cover custom training loops, torch.compile |
| 6 | Unsloth | 50k | ❌ Không có | ❌ Thiếu hoàn toàn | Cần skill mới — 2x faster, 70% less VRAM |
| 7 | exo | 38.9k | ❌ Không có | ❌ Thiếu hoàn toàn | Distributed inference across consumer devices |
| 8 | FastChat | 39.3k | ❌ Không có | 🔸 Thấp ưu tiên | Overlap nhiều với vLLM/TGI, chủ yếu dùng cho eval/arena |
| 9 | llm.c (Karpathy) | 28.5k | ❌ Không có | 🔸 Thấp ưu tiên | Educational, raw C/CUDA, niche |
| 10 | MLC LLM | 21.8k | ❌ Không có | 🔸 Trung bình | Universal deployment, ML compilation |
| 11 | Flash Attention | 21.4k | ❌ Không có (ngầm dùng) | ⚠️ Một phần | Nhiều tools dùng FA ngầm, nhưng không có guide cài/debug riêng |
| 12 | whisper.cpp | 45.4k | `sherpa-onnx` (speech) | ⚠️ Một phần | sherpa-onnx cover speech nhưng không cover whisper.cpp trực tiếp |

### Bổ sung từ user:

| # | Repo/Tool | Existing Skill | Coverage Level | Ghi chú |
|---|-----------|---------------|----------------|---------|
| 13 | LMCache | ❌ Không có | 🔸 Niche | KV cache sharing, tích hợp vào vllm-tgi skill |
| 14 | SGLang | ❌ Không có | ⚠️ Thiếu | Serving framework mạnh, RadixAttention, structured output |
| 15 | TensorRT-LLM | ❌ Không có | ❌ Thiếu | NVIDIA inference optimization, FP8, kernel fusion |
| 16 | MLX | ❌ Không có | ❌ Thiếu | Apple Silicon ML framework |
| 17 | NVIDIA Dynamo | ❌ Không có | 🔸 Niche | Multi-node distributed inference orchestration |

## Đề xuất: Skills mới (ưu tiên cao → thấp)

### Priority 1 — Thiếu hoàn toàn, impact cao

| Skill mới | Lý do | Layer |
|-----------|-------|-------|
| `ollama-local-llm` | 158k stars, easiest local LLM, Modelfile, REST API, GGUF import | Application |
| `unsloth-training` | 50k stars, 2x faster fine-tuning, 70% less VRAM, SFT/DPO/GRPO | Workflow |
| `llama-cpp-inference` | 92.2k stars, llama.cpp server, CPU+GPU inference, GGUF runtime | Serving |
| `sglang-serving` | RadixAttention, structured output, up to 3x faster than vLLM, PyTorch ecosystem | Serving |
| `tensorrt-llm` | NVIDIA inference optimization, FP8, kernel fusion, 4x throughput vs PyTorch | Serving |

### Priority 2 — Hữu ích, niche hơn

| Skill mới | Lý do | Layer |
|-----------|-------|-------|
| `mlx-apple-silicon` | Apple Silicon ML, unified memory, fine-tune + inference on Mac | Infrastructure |
| `flash-attention-guide` | Install/debug FA2/FA3, CUDA compat, build from source | Infrastructure |
| `whisper-cpp` | 45.4k stars, fast audio transcription C/C++, edge deployment | Application |

### Priority 3 — Có thể tích hợp vào skills hiện có thay vì tạo mới

| Nội dung | Tích hợp vào | Cách |
|----------|-------------|------|
| exo distributed inference | `vllm-tgi-inference` references | Thêm reference file về distributed inference alternatives |
| LMCache KV cache sharing | `vllm-tgi-inference` references | Thêm reference về KV cache optimization |
| NVIDIA Dynamo | `triton-deployment` references | Thêm reference về multi-node orchestration |
| FastChat | Không cần | Overlap quá nhiều với vLLM/TGI |
| llm.c | Không cần | Educational, không phải production workflow |
| MLC LLM | `llama-cpp-inference` references | Mention as alternative universal deployment |

## Đề xuất: Steering mới

| Steering | Inclusion | Lý do |
|----------|-----------|-------|
| `local-llm-deployment.md` | `auto` | Conventions khi chạy LLM local: Ollama vs llama.cpp vs vLLM. Match khi user hỏi "run model locally", "local inference", "Ollama" |

## Đề xuất: Hooks mới

Không cần hook mới — hooks hiện tại đã cover quality gate và README index.

## Đề xuất: Updates cho skills hiện có

| Skill | Update |
|-------|--------|
| `vllm-tgi-inference` | Thêm SGLang vào engine comparison, mention LMCache, exo |
| `model-quantization` | Cross-ref đến `llama-cpp-inference` cho GGUF runtime |
| `python-ml-deps` | Thêm flash-attn install patterns, MLX install |

## Implementation Order

Dựa trên impact × effort:

```
Phase 1 (High impact, moderate effort):
  1. ollama-local-llm          — 158k stars, dễ viết, clear scope
  2. unsloth-training           — 50k stars, fills training gap
  3. llama-cpp-inference        — 92.2k stars, fills serving gap

Phase 2 (High impact, higher effort):
  4. sglang-serving             — Complex serving framework
  5. tensorrt-llm               — NVIDIA-specific, complex

Phase 3 (Medium impact):
  6. mlx-apple-silicon          — Apple-only, niche
  7. flash-attention-guide      — Infrastructure, install/debug
  8. whisper-cpp                — Overlap with sherpa-onnx

Phase 4 (Integration updates):
  9. Update vllm-tgi-inference  — Add SGLang, LMCache, exo refs
  10. Update model-quantization — Cross-ref llama-cpp-inference
  11. New steering: local-llm-deployment.md
  12. Update interconnection map
```

## Unresolved Questions

1. `sglang-serving` vs mở rộng `vllm-tgi-inference` thành `vllm-tgi-sglang-inference`? → Recommend skill riêng vì SGLang có frontend language riêng
2. `whisper-cpp` vs mở rộng `sherpa-onnx`? → Recommend skill riêng vì whisper.cpp có ecosystem riêng (ggml, không dùng ONNX)
3. PyTorch custom training loops (torch.compile, custom CUDA kernels) — cần skill riêng hay tích hợp vào `hf-transformers-trainer`? → Recommend tích hợp vào references
