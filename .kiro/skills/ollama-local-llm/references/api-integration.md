# API Integration Guide

Full REST API reference, OpenAI-compatible endpoints, Python and JavaScript client patterns, streaming, and embedding generation for Ollama.

## REST API Overview

Ollama serves on `http://localhost:11434` by default. All endpoints accept JSON.

```bash
# Ensure server is running
ollama serve &

# Health check
curl -s http://localhost:11434/api/tags | python -m json.tool
```

## Core Endpoints

### POST /api/generate — Text Completion

Single-turn text generation (non-chat).

```bash
# Non-streaming
curl -s http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Explain REST APIs in 2 sentences.",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "num_ctx": 4096
  }
}' | python -m json.tool
```

Response:
```json
{
  "model": "llama3.1:8b",
  "response": "REST APIs are...",
  "done": true,
  "total_duration": 1234567890,
  "eval_count": 42,
  "eval_duration": 987654321
}
```

### POST /api/chat — Chat Completion

Multi-turn conversation with message history.

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is Docker?"},
    {"role": "assistant", "content": "Docker is a containerization platform..."},
    {"role": "user", "content": "How does it differ from VMs?"}
  ],
  "stream": false,
  "options": {
    "temperature": 0.7
  }
}' | python -m json.tool
```

### POST /api/embed — Generate Embeddings

```bash
curl -s http://localhost:11434/api/embed -d '{
  "model": "nomic-embed-text",
  "input": ["Hello world", "Ollama is great"]
}' | python -m json.tool
```

Response:
```json
{
  "model": "nomic-embed-text",
  "embeddings": [
    [0.123, -0.456, ...],
    [0.789, -0.012, ...]
  ]
}
```

### GET /api/tags — List Models

```bash
curl -s http://localhost:11434/api/tags | python -m json.tool
```

### POST /api/show — Model Details

```bash
curl -s http://localhost:11434/api/show -d '{"name": "llama3.1:8b"}' | python -m json.tool
```

### POST /api/pull — Pull Model

```bash
curl -s http://localhost:11434/api/pull -d '{"name": "llama3.1:8b", "stream": false}'
```

### DELETE /api/delete — Delete Model

```bash
curl -s -X DELETE http://localhost:11434/api/delete -d '{"name": "my-model"}'
```

## OpenAI-Compatible Endpoints

Ollama exposes OpenAI-compatible endpoints for drop-in replacement with existing OpenAI client code.

### POST /v1/chat/completions

```bash
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [
      {"role": "system", "content": "You are helpful."},
      {"role": "user", "content": "Hello!"}
    ],
    "temperature": 0.7,
    "max_tokens": 256,
    "stream": false
  }' | python -m json.tool
```

### GET /v1/models

```bash
curl -s http://localhost:11434/v1/models | python -m json.tool
```

### Supported OpenAI Parameters

| Parameter | Supported | Notes |
|---|---|---|
| `model` | ✅ | Ollama model name |
| `messages` | ✅ | system, user, assistant roles |
| `temperature` | ✅ | |
| `max_tokens` | ✅ | Maps to num_predict |
| `top_p` | ✅ | |
| `stream` | ✅ | SSE streaming |
| `stop` | ✅ | Stop sequences |
| `frequency_penalty` | ✅ | |
| `presence_penalty` | ✅ | |
| `seed` | ✅ | |
| `tools` | ✅ | Function calling (model-dependent) |
| `response_format` | ✅ | `{"type": "json_object"}` for JSON mode |

## Python Client

### Official ollama Library

```bash
pip install ollama
```

#### Basic Chat

```python
import ollama

response = ollama.chat(
    model="llama3.1:8b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain Python decorators."},
    ],
)
print(response["message"]["content"])
```

#### Streaming

```python
import ollama

stream = ollama.chat(
    model="llama3.1:8b",
    messages=[{"role": "user", "content": "Write a haiku about coding."}],
    stream=True,
)
for chunk in stream:
    print(chunk["message"]["content"], end="", flush=True)
print()
```

#### Generate Embeddings

```python
import ollama

result = ollama.embed(
    model="nomic-embed-text",
    input=["Hello world", "Ollama embeddings"],
)
print(f"Dimensions: {len(result['embeddings'][0])}")
print(f"Vectors: {len(result['embeddings'])}")
```

#### List and Manage Models

```python
import ollama

# List models
models = ollama.list()
for m in models["models"]:
    print(f"{m['name']} — {m['size'] / 1e9:.1f} GB")

# Pull model
ollama.pull("llama3.1:8b")

# Show model info
info = ollama.show("llama3.1:8b")
print(info["parameters"])
```

### Using openai Library (Drop-in)

```bash
pip install openai
```

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama",  # Required by client but not validated
)

# Chat completion
response = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is Kubernetes?"},
    ],
    temperature=0.7,
    max_tokens=256,
)
print(response.choices[0].message.content)

# Streaming
stream = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[{"role": "user", "content": "Explain microservices."}],
    stream=True,
)
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

### JSON Mode

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")

response = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[
        {"role": "user", "content": "List 3 Python frameworks as JSON array with name and description fields."}
    ],
    response_format={"type": "json_object"},
    temperature=0.0,
)
import json
data = json.loads(response.choices[0].message.content)
print(json.dumps(data, indent=2))
```

## JavaScript / TypeScript Client

### Official ollama-js Library

```bash
npm install ollama
```

```typescript
import { Ollama } from "ollama";

const ollama = new Ollama({ host: "http://localhost:11434" });

// Chat
const response = await ollama.chat({
  model: "llama3.1:8b",
  messages: [{ role: "user", content: "Hello!" }],
});
console.log(response.message.content);

// Streaming
const stream = await ollama.chat({
  model: "llama3.1:8b",
  messages: [{ role: "user", content: "Write a poem." }],
  stream: true,
});
for await (const chunk of stream) {
  process.stdout.write(chunk.message.content);
}

// Embeddings
const embedResult = await ollama.embed({
  model: "nomic-embed-text",
  input: ["Hello world"],
});
console.log(`Dimensions: ${embedResult.embeddings[0].length}`);
```

### Using openai-node (Drop-in)

```bash
npm install openai
```

```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:11434/v1",
  apiKey: "ollama",
});

const response = await client.chat.completions.create({
  model: "llama3.1:8b",
  messages: [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: "Explain Docker Compose." },
  ],
  temperature: 0.7,
  max_tokens: 256,
});
console.log(response.choices[0].message.content);
```

## Streaming Patterns

### Server-Sent Events (SSE) — Raw HTTP

```bash
# Streaming chat (default behavior, stream: true)
curl -N http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [{"role": "user", "content": "Count to 10"}]
}'
```

Each line is a JSON object:
```json
{"model":"llama3.1:8b","message":{"role":"assistant","content":"1"},"done":false}
{"model":"llama3.1:8b","message":{"role":"assistant","content":","},"done":false}
...
{"model":"llama3.1:8b","message":{"role":"assistant","content":""},"done":true,"total_duration":...}
```

### Python Async Streaming

```python
import ollama
import asyncio

async def stream_chat():
    client = ollama.AsyncClient()
    stream = await client.chat(
        model="llama3.1:8b",
        messages=[{"role": "user", "content": "Explain async/await."}],
        stream=True,
    )
    async for chunk in stream:
        print(chunk["message"]["content"], end="", flush=True)

asyncio.run(stream_chat())
```

## Embeddings for RAG

### Complete RAG Pattern with Ollama

```python
import ollama
import numpy as np

# Step 1: Generate embeddings for documents
documents = [
    "Python is a high-level programming language.",
    "Docker containers package applications with dependencies.",
    "Kubernetes orchestrates container deployments at scale.",
]

doc_embeddings = ollama.embed(
    model="nomic-embed-text",
    input=documents,
)["embeddings"]

# Step 2: Generate embedding for query
query = "How do I deploy containers?"
query_embedding = ollama.embed(
    model="nomic-embed-text",
    input=[query],
)["embeddings"][0]

# Step 3: Compute cosine similarity
def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

similarities = [cosine_similarity(query_embedding, doc_emb) for doc_emb in doc_embeddings]
top_idx = np.argmax(similarities)
context = documents[top_idx]

# Step 4: Generate answer with context
response = ollama.chat(
    model="llama3.1:8b",
    messages=[
        {"role": "system", "content": f"Answer based on this context: {context}"},
        {"role": "user", "content": query},
    ],
)
print(response["message"]["content"])
```

### Embedding Models Available

| Model | Dimensions | Use Case |
|---|---|---|
| `nomic-embed-text` | 768 | General-purpose text embeddings |
| `mxbai-embed-large` | 1024 | High-quality, larger embeddings |
| `all-minilm` | 384 | Lightweight, fast embeddings |
| `snowflake-arctic-embed` | 1024 | Strong retrieval performance |

```bash
# Pull embedding model
ollama pull nomic-embed-text
```

## Request Options Reference

Options can be passed in the `options` field for `/api/generate` and `/api/chat`:

```json
{
  "model": "llama3.1:8b",
  "messages": [...],
  "stream": false,
  "options": {
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "num_ctx": 4096,
    "num_predict": 256,
    "repeat_penalty": 1.1,
    "seed": 42,
    "stop": ["\n\n", "END"]
  }
}
```

These override Modelfile PARAMETER values for the current request only.

## Error Handling

```python
import ollama

try:
    response = ollama.chat(
        model="nonexistent-model",
        messages=[{"role": "user", "content": "Hello"}],
    )
except ollama.ResponseError as e:
    if e.status_code == 404:
        print(f"Model not found. Pull it first: ollama pull <model>")
    else:
        print(f"Ollama error {e.status_code}: {e.error}")
except Exception as e:
    print(f"Connection error: {e}. Is ollama serve running?")
```

## Performance Tips

| Tip | Detail |
|---|---|
| Keep model loaded | Set `OLLAMA_KEEP_ALIVE=24h` to avoid reload latency |
| Use `stream: false` for batch | Non-streaming returns full response, easier to parse |
| Reuse client instances | Don't create new client per request |
| Limit `num_ctx` | Smaller context = faster inference, less VRAM |
| Use embedding models for search | Don't use chat models for embeddings — use dedicated models |
