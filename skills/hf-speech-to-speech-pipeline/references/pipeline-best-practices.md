# HuggingFace Speech-to-Speech Pipeline — Best Practices

> Repo: [huggingface/speech-to-speech](https://github.com/huggingface/speech-to-speech)
> ⚠️ Pipeline này KHÔNG scale cho multi-user concurrent. Single-process, single-session by design.

## Architecture Overview

Pipeline sử dụng mô hình **queue-chained handlers** chạy trên threads:

```
Audio In → VAD → STT → LLM → LM Processor → TTS → Audio Out
```

Mỗi handler kế thừa `BaseHandler` (`baseHandler.py`), giao tiếp qua `Queue`.
`ThreadManager` (`utils/thread_manager.py`) quản lý lifecycle.

Supported modules (xem `arguments_classes/module_arguments.py`):
- **VAD**: Silero VAD v5
- **STT**: whisper, whisper-mlx, mlx-audio-whisper, faster-whisper, parakeet-tdt, paraformer
- **LLM**: transformers, mlx-lm, openai API
- **TTS**: melo, chatTTS, facebookMMS, pocket, kokoro, qwen3

## Core Patterns

### 1. BaseHandler Contract

Mọi pipeline stage PHẢI kế thừa `BaseHandler` và implement:

- `setup()` — khởi tạo model/state, gọi 1 lần
- `process(input)` — generator, yield output cho stage tiếp theo
- `on_session_end()` — reset per-session state (optional)
- `cleanup()` — giải phóng resource khi handler dừng (optional)

```python
class MyHandler(BaseHandler):
    def setup(self, model_name="default"):
        self.model = load_model(model_name)

    def process(self, input):
        result = self.model(input)
        yield result

    def on_session_end(self):
        self.buffer = []
```

Xem `baseHandler.py` cho implementation chi tiết của `run()` loop.

### 2. Queue Wiring

- Mỗi handler có `queue_in` và `queue_out`
- Output queue của handler N = Input queue của handler N+1
- Queue mặc định unbounded — cân nhắc set `maxsize` nếu cần backpressure
- Tất cả queues được tạo trong `initialize_queues_and_events()` (`s2s_pipeline.py`)

```python
q1 = Queue()
q2 = Queue()
handler_a = HandlerA(stop_event, queue_in=q1, queue_out=q2)
handler_b = HandlerB(stop_event, queue_in=q2, queue_out=q3)
```

### 3. Control Messages

Defined trong `pipeline_control.py`:

| Signal | Mục đích | Handler behavior |
|--------|----------|-----------------|
| `SESSION_END` | Kết thúc session, reset state | Gọi `on_session_end()`, forward xuống |
| `b"END"` | Dừng handler thread | Break khỏi run loop, gọi `cleanup()` |

KHÔNG dùng `b"END"` để reset session. KHÔNG dùng `SESSION_END` để dừng handler.

### 4. Lazy Import

Chỉ import module được chọn tại runtime (trong factory functions của `s2s_pipeline.py`):

```python
# ĐÚNG — lazy import trong get_stt_handler()
if module_kwargs.stt == "whisper":
    from STT.whisper_stt_handler import WhisperSTTHandler
    return WhisperSTTHandler(...)

# SAI — import tất cả ở đầu file
from STT.whisper_stt_handler import WhisperSTTHandler
from STT.paraformer_handler import ParaformerSTTHandler
```

### 5. Side-Channel Pattern

Khi cần gửi data ra ngoài pipeline chính (WebSocket, logging, metrics):

- Tạo middleware handler giữa 2 stage (xem `LLM/lm_output_processor.py`)
- Gửi side data qua queue riêng (`text_output_queue`)
- Forward main data xuống pipeline bình thường

```python
class MyProcessor(BaseHandler):
    def process(self, input):
        self.side_queue.put({"type": "event", "data": input})
        yield transform(input)
```

### 6. Progressive Streaming (VAD)

VAD (`VAD/vad_handler.py`) hỗ trợ 2 mode:
- **Normal**: yield audio chỉ khi speech kết thúc
- **Realtime**: yield progressive chunks định kỳ khi đang nói

```python
yield ("progressive", array)  # partial, user vẫn đang nói
yield ("final", array)        # complete, speech đã kết thúc
```

Xem `STT/smart_progressive_streaming.py` cho incremental transcription logic.

## Adding a New Handler

1. Tạo argument class trong `arguments_classes/<tên>_arguments.py`
2. Tạo handler class kế thừa `BaseHandler` trong `<STT|LLM|TTS>/`
3. Thêm vào factory function tương ứng trong `s2s_pipeline.py`:
   - `get_stt_handler()` cho STT
   - `get_llm_handler()` cho LLM
   - `get_tts_handler()` cho TTS
4. Register argument class trong `parse_arguments()`
5. Wire vào `prepare_all_args()` và `build_pipeline()`

## Scalability — CRITICAL LIMITATION

### Pipeline này KHÔNG scale cho multi-user concurrent:
- **Single-process**: tất cả handlers chạy trên threads trong 1 Python process
- **Shared queues**: không có session isolation, audio từ mọi client đổ vào cùng queue
- **Stateful handlers**: VAD buffer, STT context, LLM chat history đều in-memory per-thread
- **Unbounded queues**: không có backpressure, memory sẽ phình nếu downstream chậm
- **No GPU batching**: mỗi instance load model riêng, không share across requests

### Scale strategy:
- **Horizontal**: nhiều instance phía sau load balancer (cách duy nhất thực tế)
- **Session isolation**: queue-per-session nếu cần multi-tenant (cần refactor)
- **Service decomposition**: tách STT/LLM/TTS thành microservice (rewrite lớn)

## Session Lifecycle

```
Client connect → should_listen.set()
    → Audio chunks vào recv_audio_chunks_queue
    → VAD detect speech → STT → LLM → LM Processor → TTS → Audio out
Client disconnect → SESSION_END propagate qua pipeline
    → Mỗi handler gọi on_session_end() rồi forward
    → should_listen.set() (ready cho client mới)
```

## Communication Modes

| Mode | Files | Use case |
|------|-------|----------|
| Socket | `connections/socket_receiver.py`, `connections/socket_sender.py` | Server/client TCP |
| WebSocket | `connections/websocket_streamer.py` | Browser/app client |
| Local | `connections/local_audio_streamer.py` | Local mic/speaker |

## Common Pitfalls

1. **Quên forward SESSION_END**: BaseHandler tự forward, nhưng nếu override `run()` thì phải tự handle
2. **Block trong process()**: `process()` chạy trên thread, block = pipeline stall. Dùng timeout cho mọi I/O
3. **Yield nhiều lần**: `process()` là generator — có thể yield 0 hoặc nhiều output cho 1 input
4. **State leak giữa sessions**: Luôn implement `on_session_end()` nếu handler giữ state
5. **Import ở đầu file**: Chỉ lazy import trong factory function, tránh load model không cần thiết

## File Reference

```
baseHandler.py                  — Base class, run loop, control message handling
pipeline_control.py             — SESSION_END, PipelineControlMessage
s2s_pipeline.py                 — Pipeline assembly, factory functions, main()
utils/thread_manager.py         — ThreadManager start/stop
utils/utils.py                  — Shared utilities
VAD/vad_handler.py              — Voice activity detection + progressive mode
VAD/vad_iterator.py             — Silero VAD iterator wrapper
STT/                            — Speech-to-text handlers (6 engines)
STT/smart_progressive_streaming.py — Incremental transcription
LLM/                            — Language model handlers (3 backends)
LLM/lm_output_processor.py     — Tool extraction, side-channel middleware
TTS/                            — Text-to-speech handlers (6 engines)
connections/                    — Socket, WebSocket, local audio I/O
arguments_classes/              — Dataclass arguments per handler
```
