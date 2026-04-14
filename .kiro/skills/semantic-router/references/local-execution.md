# Local Execution Guide

Run semantic-router fully locally without API calls.

## When to Load

Load when: setting up offline routing, avoiding API costs, or requiring data privacy.

## Installation

```bash
pip install -qU "semantic-router[local]"
```

## HuggingFaceEncoder (Local Embeddings)

```python
from semantic_router.encoders import HuggingFaceEncoder

# Default model
encoder = HuggingFaceEncoder()

# Custom model
encoder = HuggingFaceEncoder(
    name="sentence-transformers/all-MiniLM-L6-v2",
    device="cuda",  # or "cpu", "mps"
)

# With custom settings
encoder = HuggingFaceEncoder(
    name="BAAI/bge-small-en-v1.5",
    device="cuda",
    score_threshold=0.5,
)
```

**Recommended Local Models:**

| Model | Dimensions | Size | Quality |
|-------|------------|------|---------|
| all-MiniLM-L6-v2 | 384 | 80MB | Good |
| all-mpnet-base-v2 | 768 | 420MB | Better |
| bge-small-en-v1.5 | 384 | 130MB | Good |
| bge-base-en-v1.5 | 768 | 440MB | Better |
| bge-large-en-v1.5 | 1024 | 1.3GB | Best |

## FastEmbedEncoder (ONNX, Fastest)

```python
from semantic_router.encoders import FastEmbedEncoder

# Default model (auto-downloads)
encoder = FastEmbedEncoder()

# Custom model
encoder = FastEmbedEncoder(
    name="BAAI/bge-small-en-v1.5",
    cache_dir="./models",
)
```

**Advantages:**
- ONNX runtime = faster inference
- Automatic model download and caching
- CPU-optimized

## LlamaCppLLM (Local LLM for Dynamic Routes)

For dynamic routes that need parameter extraction:

```python
from semantic_router.llms import LlamaCppLLM

llm = LlamaCppLLM(
    model_path="./models/mistral-7b-instruct-v0.2.Q4_K_M.gguf",
    n_ctx=4096,
    n_gpu_layers=-1,  # -1 = all layers on GPU
    verbose=False,
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    llm=llm,
)
```

**Recommended GGUF Models:**

| Model | Size | Quality | Speed |
|-------|------|---------|-------|
| Mistral-7B-Instruct Q4_K_M | 4.4GB | Excellent | Fast |
| Llama-3-8B-Instruct Q4_K_M | 4.9GB | Excellent | Fast |
| Phi-3-mini-4k-instruct Q4_K_M | 2.4GB | Good | Fastest |

**Note:** Local models often outperform GPT-3.5 for parameter extraction.

## Complete Local Setup

```python
from semantic_router import Route, SemanticRouter
from semantic_router.encoders import HuggingFaceEncoder
from semantic_router.llms import LlamaCppLLM
from semantic_router.llms.openai import get_schemas_openai

# 1. Local encoder
encoder = HuggingFaceEncoder(
    name="sentence-transformers/all-MiniLM-L6-v2",
    device="cuda",
)

# 2. Local LLM (only needed for dynamic routes)
llm = LlamaCppLLM(
    model_path="./models/mistral-7b-instruct.gguf",
    n_gpu_layers=-1,
)

# 3. Define routes
def get_weather(location: str) -> str:
    """Get weather for a location.
    :param location: City name
    """
    return f"Weather in {location}: Sunny"

weather_route = Route(
    name="weather",
    utterances=["what's the weather in Paris?", "is it raining in London?"],
    function_schemas=get_schemas_openai([get_weather]),
)

chitchat = Route(
    name="chitchat",
    utterances=["hello", "how are you?", "what's up?"],
)

# 4. Create router
sr = SemanticRouter(
    encoder=encoder,
    routes=[weather_route, chitchat],
    llm=llm,
)

# 5. Use
result = sr("what's the weather like in Tokyo?")
print(result.name)  # "weather"
print(result.function_call)  # [{'function_name': 'get_weather', 'arguments': {'location': 'Tokyo'}}]
```

## GPU Memory Considerations

| Component | VRAM (approx) |
|-----------|---------------|
| all-MiniLM-L6-v2 | ~200MB |
| bge-large-en-v1.5 | ~2GB |
| Mistral-7B Q4 | ~5GB |
| Llama-3-8B Q4 | ~6GB |

**Tip:** Use CPU for encoder if GPU VRAM is limited for LLM.

```python
encoder = HuggingFaceEncoder(device="cpu")  # Encoder on CPU
llm = LlamaCppLLM(model_path="...", n_gpu_layers=-1)  # LLM on GPU
```

## Offline Model Download

Pre-download models for air-gapped environments:

```python
# Download HuggingFace model
from sentence_transformers import SentenceTransformer
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
model.save("./models/all-MiniLM-L6-v2")

# Use local path
encoder = HuggingFaceEncoder(name="./models/all-MiniLM-L6-v2")
```

## Performance Comparison

| Setup | Latency (per query) | Cost |
|-------|---------------------|------|
| OpenAI API | 100-300ms | $0.0001/query |
| Local HuggingFace (GPU) | 5-20ms | Free |
| Local FastEmbed (CPU) | 10-50ms | Free |
| Local LLM (dynamic) | 500-2000ms | Free |

**Recommendation:** Use local encoder + OpenAI LLM for best balance of speed and quality. Use fully local only when API access is not possible.
