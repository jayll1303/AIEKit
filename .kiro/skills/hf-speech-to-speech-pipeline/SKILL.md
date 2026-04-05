---
name: hf-speech-to-speech-pipeline
description: >
  Best practices and architecture patterns for huggingface/speech-to-speech queue-chained pipeline.
  Use when building speech-to-speech pipelines, adding STT/LLM/TTS handlers, wiring queue-based
  audio processing stages, implementing VAD with progressive streaming, or designing real-time
  voice agent architectures. Does NOT handle: model training → hf-transformers-trainer,
  model serving at scale → inference-deployment, Docker/GPU setup → docker-gpu-setup.
---

# HuggingFace Speech-to-Speech Pipeline

> Source: [huggingface/speech-to-speech](https://github.com/huggingface/speech-to-speech)
> ⚠️ **DOES NOT SCALE** for multi-user concurrent. Single-process, single-session by design.

## Architecture

Queue-chained handlers on threads:

```
Audio In → VAD → STT → LLM → LM Processor → TTS → Audio Out
```

Each handler inherits `BaseHandler`, communicates via `Queue`, managed by `ThreadManager`.

## Core Patterns

### 1. BaseHandler Contract

Every pipeline stage MUST inherit `BaseHandler` and implement:

```python
class MyHandler(BaseHandler):
    def setup(self, **kwargs):
        """Init model/state. Called once."""
        self.model = load_model(kwargs["model_name"])

    def process(self, input):
        """Generator — yield outputs for next stage."""
        result = self.model(input)
        yield result

    def on_session_end(self):
        """Reset per-session state. Optional."""
        self.buffer = []

    def cleanup(self):
        """Release resources on handler stop. Optional."""
        pass
```

Rules:
- `process()` is a generator — yield 0 or more outputs per input
- Do NOT override `run()` unless absolutely necessary
- Do NOT block in `process()` — use timeouts for all I/O
- Always implement `on_session_end()` if handler holds per-session state

### 2. Queue Wiring

- Handler N's `queue_out` = Handler N+1's `queue_in`
- Default queues are unbounded — set `maxsize` if backpressure needed
- All queues created centrally in `initialize_queues_and_events()`

### 3. Control Messages

| Signal | Purpose | Behavior |
|--------|---------|----------|
| `SESSION_END` | End session, reset state | Calls `on_session_end()`, forwards downstream |
| `b"END"` | Stop handler thread | Breaks run loop, calls `cleanup()` |

Never use `b"END"` for session reset. Never use `SESSION_END` to stop handlers.

### 4. Lazy Import

Only import the selected module at runtime inside factory functions:

```python
# CORRECT — lazy import
if module_kwargs.stt == "whisper":
    from STT.whisper_stt_handler import WhisperSTTHandler
    return WhisperSTTHandler(...)

# WRONG — importing everything at top level
from STT.whisper_stt_handler import WhisperSTTHandler
from STT.paraformer_handler import ParaformerSTTHandler
```

### 5. Side-Channel Pattern

For sending data outside the main pipeline (WebSocket, metrics):

```python
class LMOutputProcessor(BaseHandler):
    def process(self, lm_output):
        text, lang, tools = lm_output
        # Side effect: send to WebSocket clients
        self.text_output_queue.put({"type": "assistant_text", "text": text, "tools": tools})
        # Main flow: forward to TTS
        yield (text, lang)
```

### 6. Progressive Streaming

VAD supports two modes:
- **Normal**: yield audio only when speech ends
- **Realtime**: yield progressive chunks periodically while speaking

```python
yield ("progressive", array)  # partial — user still speaking
yield ("final", array)        # complete — speech ended
```

## Adding a New Handler

1. Create argument dataclass in `arguments_classes/`
2. Create handler inheriting `BaseHandler` in `STT/`, `LLM/`, or `TTS/`
3. Add branch in corresponding factory: `get_stt_handler()` / `get_llm_handler()` / `get_tts_handler()`
4. Register in `parse_arguments()`, `prepare_all_args()`, `build_pipeline()`
5. Use lazy import inside factory branch only

## Supported Modules

- **VAD**: Silero VAD v5
- **STT**: whisper, whisper-mlx, mlx-audio-whisper, faster-whisper, parakeet-tdt, paraformer
- **LLM**: transformers, mlx-lm, openai API
- **TTS**: melo, chatTTS, facebookMMS, pocket, kokoro, qwen3

## Scalability — CRITICAL LIMITATION

This pipeline DOES NOT scale for concurrent multi-user:
- Single Python process, all handlers on threads
- Shared queues — no session isolation
- Stateful handlers — VAD buffer, STT context, LLM history all in-memory
- Unbounded queues — no backpressure
- No GPU batching across requests

**Only viable scale strategy**: run multiple instances behind a load balancer, one session per instance.

## Session Lifecycle

```
Client connect → should_listen.set()
  → Audio → VAD → STT → LLM → LM Processor → TTS → Audio out
Client disconnect → SESSION_END propagates through pipeline
  → Each handler calls on_session_end() then forwards
  → should_listen.set() (ready for next client)
```

## Common Pitfalls

1. Forgetting to forward `SESSION_END` — BaseHandler handles it, but custom `run()` overrides must too
2. Blocking in `process()` — stalls entire pipeline
3. State leaking between sessions — always implement `on_session_end()`
4. Top-level imports of unused handlers — use lazy imports in factories
5. Using `b"END"` for session reset — that stops the handler thread permanently

## References

- Detailed best practices: see `references/pipeline-best-practices.md`
- Repository: https://github.com/huggingface/speech-to-speech
- Silero VAD: https://github.com/snakers4/silero-vad
- HuggingFace Transformers: https://huggingface.co/docs/transformers
