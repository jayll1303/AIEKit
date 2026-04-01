# Embedding Model Selection Guide

Guide for choosing sentence-transformers embedding models based on quality (MTEB benchmarks), dimension, speed, and multilingual support.

## Model Comparison Table

| Model | Dimension | MTEB Avg | Speed (rel.) | Max Tokens | Multilingual | Notes |
|---|---|---|---|---|---|---|
| `BAAI/bge-base-en-v1.5` | 768 | ~63 | Fast | 512 | No | Best balance of speed and quality for English |
| `BAAI/bge-large-en-v1.5` | 1024 | ~64 | Medium | 512 | No | Higher quality, 2x slower than base |
| `BAAI/bge-small-en-v1.5` | 384 | ~62 | Very fast | 512 | No | Fastest, good for prototyping |
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | ~56 | Very fast | 256 | No | Classic lightweight model, short context |
| `sentence-transformers/all-mpnet-base-v2` | 768 | ~57 | Fast | 384 | No | Good general-purpose English model |
| `intfloat/e5-large-v2` | 1024 | ~62 | Medium | 512 | No | Strong retrieval performance |
| `intfloat/multilingual-e5-large` | 1024 | ~61 | Medium | 512 | Yes (100+ langs) | Best multilingual option |
| `BAAI/bge-m3` | 1024 | ~65 | Slow | 8192 | Yes (100+ langs) | Long context + multilingual + multi-task |
| `nomic-ai/nomic-embed-text-v1.5` | 768 | ~62 | Fast | 8192 | No | Long context, Matryoshka support |
| `Alibaba-NLP/gte-large-en-v1.5` | 1024 | ~65 | Medium | 8192 | No | High quality, long context |

*MTEB scores are approximate and may vary by task category. Check the [MTEB Leaderboard](https://huggingface.co/spaces/mteb/leaderboard) for latest results.*

## Selection Decision Guide

### By Use Case

| Scenario | Recommended Model | Why |
|---|---|---|
| English RAG, balanced speed/quality | `BAAI/bge-base-en-v1.5` | Strong MTEB scores, 768d, fast encoding |
| English RAG, maximum quality | `Alibaba-NLP/gte-large-en-v1.5` | Top MTEB scores, 8K context |
| Multilingual RAG | `intfloat/multilingual-e5-large` | 100+ languages, solid quality |
| Multilingual + long documents | `BAAI/bge-m3` | 8K context, multi-task, multi-lingual |
| Low VRAM / edge deployment | `BAAI/bge-small-en-v1.5` | 384d, minimal memory, fast |
| Long documents (>512 tokens) | `nomic-ai/nomic-embed-text-v1.5` | 8K context window |
| Prototyping / quick experiments | `sentence-transformers/all-MiniLM-L6-v2` | Tiny, fast, widely used |

### By Hardware Constraints

| GPU VRAM | Max Model Size | Recommended |
|---|---|---|
| No GPU (CPU only) | Small/Base | `BAAI/bge-small-en-v1.5` or `all-MiniLM-L6-v2` |
| 4-8 GB | Base/Large | `BAAI/bge-base-en-v1.5` |
| 8-16 GB | Large | `BAAI/bge-large-en-v1.5` or `gte-large-en-v1.5` |
| 16+ GB | Any | `BAAI/bge-m3` for maximum capability |

## Query Prefix Patterns

Some models require specific prefixes for queries vs documents to achieve optimal performance:

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("BAAI/bge-base-en-v1.5")

# BGE models: add "Represent this sentence:" prefix for queries
query_embedding = model.encode("Represent this sentence: What is RAG?")
doc_embedding = model.encode("RAG combines retrieval with generation.")

# E5 models: add "query:" and "passage:" prefixes
# model = SentenceTransformer("intfloat/e5-large-v2")
# query_embedding = model.encode("query: What is RAG?")
# doc_embedding = model.encode("passage: RAG combines retrieval with generation.")
```

**Prefix requirements by model family**:

| Model Family | Query Prefix | Document Prefix |
|---|---|---|
| BGE (`BAAI/bge-*`) | `Represent this sentence:` | None |
| E5 (`intfloat/e5-*`) | `query:` | `passage:` |
| GTE (`Alibaba-NLP/gte-*`) | None | None |
| Nomic (`nomic-ai/nomic-*`) | `search_query:` | `search_document:` |
| all-MiniLM / all-mpnet | None | None |

## Multilingual Models

### When to Use Multilingual

- Documents and queries may be in different languages (cross-lingual retrieval)
- Corpus contains mixed-language documents
- Need to support non-English queries against English documents (or vice versa)

### Multilingual Model Comparison

| Model | Languages | Dimension | Quality | Context |
|---|---|---|---|---|
| `intfloat/multilingual-e5-large` | 100+ | 1024 | Good | 512 |
| `BAAI/bge-m3` | 100+ | 1024 | Best | 8192 |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | 50+ | 384 | Moderate | 128 |
| `sentence-transformers/paraphrase-multilingual-mpnet-base-v2` | 50+ | 768 | Good | 128 |

### Cross-Lingual Retrieval Example

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("intfloat/multilingual-e5-large")

# Query in English, documents in Vietnamese
query = model.encode(["query: What is machine learning?"], normalize_embeddings=True)
docs = model.encode([
    "passage: Học máy là một nhánh của trí tuệ nhân tạo.",
    "passage: Machine learning is a branch of artificial intelligence.",
    "passage: 機器學習是人工智慧的一個分支。",
], normalize_embeddings=True)

# Compute similarities — cross-lingual matching works
import numpy as np
similarities = np.dot(query, docs.T)
print(similarities)  # All three should score high
```

## Matryoshka Embeddings

Some models support Matryoshka Representation Learning (MRL), allowing you to truncate embeddings to smaller dimensions with minimal quality loss:

```python
from sentence_transformers import SentenceTransformer

# nomic-embed supports Matryoshka dimensions: 768, 512, 256, 128, 64
model = SentenceTransformer("nomic-ai/nomic-embed-text-v1.5")

# Full dimension
full_emb = model.encode(texts, normalize_embeddings=True)  # (N, 768)

# Truncate to 256 dimensions (saves ~66% storage, minor quality loss)
truncated_emb = full_emb[:, :256]
truncated_emb = truncated_emb / np.linalg.norm(truncated_emb, axis=1, keepdims=True)
```

**Benefits**: Reduce vector store size and search latency while maintaining most retrieval quality. Useful for large-scale deployments where storage/speed matters more than marginal quality.

## Benchmarking Your Own Models

```python
from sentence_transformers import SentenceTransformer
import time
import numpy as np

def benchmark_model(model_name: str, texts: list[str], device: str = "cuda"):
    model = SentenceTransformer(model_name, device=device)

    # Warmup
    model.encode(texts[:10])

    # Benchmark encoding speed
    start = time.time()
    embeddings = model.encode(texts, batch_size=256, show_progress_bar=False)
    elapsed = time.time() - start

    print(f"Model: {model_name}")
    print(f"  Dimension: {embeddings.shape[1]}")
    print(f"  Encoded {len(texts)} texts in {elapsed:.2f}s")
    print(f"  Throughput: {len(texts)/elapsed:.0f} texts/sec")
    return embeddings

# Compare models on your data
for model_name in [
    "BAAI/bge-small-en-v1.5",
    "BAAI/bge-base-en-v1.5",
    "BAAI/bge-large-en-v1.5",
]:
    benchmark_model(model_name, your_texts)
```
