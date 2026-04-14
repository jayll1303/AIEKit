---
name: semantic-router
description: "Build superfast AI decision layers with semantic-router. ALWAYS use for Route, SemanticRouter, HybridRouter, dynamic routes with function calling, intent classification, Pinecone/Qdrant index."
---

# Semantic Router

Build superfast decision-making layers for LLMs and agents using semantic vector space instead of slow LLM generations.

## Scope

This skill handles:
- Route definition with utterances
- SemanticRouter and HybridRouter setup
- Encoder selection (OpenAI, Cohere, HuggingFace, FastEmbed)
- Index configuration (Local, Pinecone, Qdrant, Postgres)
- Dynamic routes with function calling
- Multi-function routes
- Route optimization and auto-sync

Does NOT handle:
- Embedding model training (→ text-embeddings-rag)
- LLM serving for dynamic routes (→ vllm-tgi-inference, ollama-local-llm)
- Vector database setup/management (→ text-embeddings-rag)
- Python project setup (→ python-project-setup)

## When to Use

- Building intent classification for chatbots
- Creating fast tool-use decision layers (avoid slow LLM calls)
- Routing user queries to appropriate handlers
- Implementing guardrails (e.g., block politics, detect sensitive topics)
- Adding function calling with parameter extraction

## Installation Decision Table

| Need | Install Command |
|------|-----------------|
| Basic routing | `pip install -qU semantic-router` |
| Local embeddings (no API) | `pip install -qU "semantic-router[local]"` |
| Hybrid search (dense + sparse) | `pip install -qU "semantic-router[hybrid]"` |
| Pinecone index | `pip install -qU "semantic-router[pinecone]"` |
| Qdrant index | `pip install -qU "semantic-router[qdrant]"` |
| PostgreSQL index | `pip install -qU "semantic-router[postgres]"` |

## Encoder Decision Table

| Scenario | Encoder | Setup |
|----------|---------|-------|
| Best quality, API-based | `OpenAIEncoder` | `OPENAI_API_KEY` env var |
| Alternative API | `CohereEncoder` | `COHERE_API_KEY` env var |
| Fully local, no API | `HuggingFaceEncoder` | `pip install "semantic-router[local]"` |
| Fast local, ONNX | `FastEmbedEncoder` | Auto-downloads models |
| HF Inference Endpoint | `HFEndpointEncoder` | `huggingface_url` + `huggingface_api_key` |

## Quick Start: Static Routes

To create a basic semantic router:

```python
from semantic_router import Route, SemanticRouter
from semantic_router.encoders import OpenAIEncoder
import os

os.environ["OPENAI_API_KEY"] = "your-key"

# 1. Define routes with example utterances
politics = Route(
    name="politics",
    utterances=[
        "isn't politics the best thing ever",
        "tell me about your political opinions",
        "they're going to destroy this country!",
    ],
)

chitchat = Route(
    name="chitchat", 
    utterances=[
        "how's the weather today?",
        "how are things going?",
        "lovely weather today",
    ],
)

# 2. Initialize encoder and router
encoder = OpenAIEncoder()
sr = SemanticRouter(encoder=encoder, routes=[politics, chitchat], auto_sync="local")

# 3. Route queries
result = sr("don't you love politics?")
print(result.name)  # "politics"

result = sr("I'm interested in learning about llama 3")
print(result.name)  # None (no match)
```

**Validate:** `sr("test query").name` returns expected route name or `None`.

## Quick Start: Dynamic Routes (Function Calling)

To create routes that extract parameters for function calls:

```python
from datetime import datetime
from zoneinfo import ZoneInfo
from semantic_router import Route, SemanticRouter
from semantic_router.encoders import OpenAIEncoder
from semantic_router.llms.openai import get_schemas_openai

# 1. Define the function
def get_time(timezone: str) -> str:
    """Finds the current time in a specific timezone.
    
    :param timezone: IANA timezone like "America/New_York" or "Europe/London"
    :return: Current time in HH:MM format
    """
    now = datetime.now(ZoneInfo(timezone))
    return now.strftime("%H:%M")

# 2. Generate schema from function
schemas = get_schemas_openai([get_time])

# 3. Create dynamic route
time_route = Route(
    name="get_time",
    utterances=[
        "what is the time in new york city?",
        "what is the time in london?",
        "I live in Rome, what time is it?",
    ],
    function_schemas=schemas,
)

# 4. Initialize router
encoder = OpenAIEncoder()
sr = SemanticRouter(encoder=encoder, routes=[time_route], auto_sync="local")

# 5. Route and execute
response = sr("what is the time in new york city?")
# RouteChoice(name='get_time', function_call=[{'function_name': 'get_time', 'arguments': {'timezone': 'America/New_York'}}])

for call in response.function_call:
    if call["function_name"] == "get_time":
        result = get_time(**call["arguments"])
        print(result)
```

**Validate:** `response.function_call` contains extracted parameters matching function signature.

## Index Decision Table

| Scenario | Index | Setup |
|----------|-------|-------|
| Development/testing | `LocalIndex` | Default, in-memory |
| Hybrid search | `HybridLocalIndex` | Requires `[hybrid]` install |
| Production, persistent | `PineconeIndex` | `PINECONE_API_KEY`, specify `dimensions` |
| Self-hosted vector DB | `QdrantIndex` | Qdrant server URL |
| Existing Postgres | `PostgresIndex` | pgvector extension |

## Remote Index Setup (Pinecone)

```python
from semantic_router.index import PineconeIndex
from semantic_router.routers import SemanticRouter
import os

os.environ["PINECONE_API_KEY"] = "your-key"

index = PineconeIndex(
    index_name="semantic-router",
    dimensions=1536  # Must match encoder dimension
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=index,
    auto_sync="remote"  # Push routes to Pinecone
)
```

## Hybrid Router (Dense + Sparse)

```python
from semantic_router.index import HybridLocalIndex
from semantic_router.routers import HybridRouter
from semantic_router.encoders import OpenAIEncoder, AurelioSparseEncoder

dense_encoder = OpenAIEncoder()
sparse_encoder = AurelioSparseEncoder()  # Requires AURELIO_API_KEY

router = HybridRouter(
    encoder=dense_encoder,
    sparse_encoder=sparse_encoder,
    routes=routes,
    index=HybridLocalIndex(),
    alpha=0.5  # 0=dense only, 1=sparse only
)
```

## Auto-Sync Modes

| Mode | Behavior |
|------|----------|
| `"local"` | Pull from remote to local |
| `"remote"` | Push from local to remote |
| `None` | No automatic syncing |

## Retrieve Multiple Routes

```python
# Get all matching routes with scores
results = sr.retrieve_multiple_routes("Hi! How are you doing in politics??")
# [RouteChoice(name='politics', similarity_score=0.859),
#  RouteChoice(name='chitchat', similarity_score=0.835)]
```

## Local Execution (No API)

```python
from semantic_router.encoders import HuggingFaceEncoder
from semantic_router.llms import LlamaCppLLM

# Local encoder
encoder = HuggingFaceEncoder(
    name="sentence-transformers/all-MiniLM-L6-v2",
    device="cuda"  # or "cpu"
)

# Local LLM for dynamic routes (optional)
llm = LlamaCppLLM(model_path="path/to/model.gguf")

sr = SemanticRouter(encoder=encoder, routes=routes, llm=llm)
```

## Troubleshooting

```
Route not matching?
├─ Check utterances cover semantic variations
├─ Add more diverse example utterances (5-10 recommended)
├─ Try retrieve_multiple_routes() to see scores
└─ Adjust score_threshold if needed

Dynamic route not extracting params?
├─ Verify function docstring has clear param descriptions
├─ Check get_schemas_openai() output matches expected schema
└─ Ensure LLM is configured (OpenAI key or local LLM)

Index sync issues?
├─ Check auto_sync mode matches your intent
├─ Verify API keys for remote indexes
└─ Ensure dimensions match encoder output
```

## Anti-Patterns

| Agent thinks | Reality |
|--------------|---------|
| "Just use LLM for routing" | Semantic router is 10-100x faster, use LLM only for dynamic param extraction |
| "Few utterances are enough" | More diverse utterances = better coverage, aim for 5-10 per route |
| "Default threshold is fine" | Tune score_threshold based on your use case, test with edge cases |
| "Local index for production" | Use Pinecone/Qdrant for persistence and scalability |

## Related Skills

| Situation | Activate Skill | Why |
|-----------|----------------|-----|
| Need embedding model training | text-embeddings-rag | Custom encoder fine-tuning |
| Need LLM for dynamic routes | vllm-tgi-inference, ollama-local-llm | Local LLM serving |
| Setting up Python project | python-project-setup | uv, ruff, pytest config |
