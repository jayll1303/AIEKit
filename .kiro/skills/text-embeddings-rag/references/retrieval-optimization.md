# Retrieval Optimization

Techniques for improving RAG retrieval quality: chunk size tuning, overlap strategy, re-ranking with cross-encoders, hybrid search (BM25 + vector), and metadata filtering.

## Chunk Size Tuning

### Impact of Chunk Size

| Chunk Size | Retrieval Precision | Context Quality | Trade-off |
|---|---|---|---|
| Small (100-300 chars) | High (focused matches) | Low (fragmented, lacks context) | Good for factoid Q&A |
| Medium (400-600 chars) | Balanced | Balanced | Best general-purpose default |
| Large (800-1500 chars) | Lower (mixed topics in chunk) | High (rich context) | Good for summarization, complex questions |

### Tuning Process

```python
from sentence_transformers import SentenceTransformer
from langchain.text_splitter import RecursiveCharacterTextSplitter
import numpy as np

def evaluate_chunk_size(
    documents: list[str],
    queries: list[str],
    expected_answers: list[str],
    chunk_sizes: list[int] = [256, 512, 768, 1024],
    model_name: str = "BAAI/bge-base-en-v1.5",
):
    model = SentenceTransformer(model_name, device="cuda")
    results = {}

    for size in chunk_sizes:
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=size, chunk_overlap=int(size * 0.1)
        )

        # Chunk all documents
        all_chunks = []
        for doc in documents:
            all_chunks.extend(splitter.split_text(doc))

        # Embed chunks
        chunk_embeddings = model.encode(all_chunks, normalize_embeddings=True)

        # Evaluate retrieval for each query
        hits = 0
        for query, expected in zip(queries, expected_answers):
            query_emb = model.encode([query], normalize_embeddings=True)
            scores = np.dot(chunk_embeddings, query_emb.T).flatten()
            top_indices = np.argsort(scores)[-5:][::-1]
            top_chunks = [all_chunks[i] for i in top_indices]

            # Check if expected answer is in retrieved chunks
            if any(expected.lower() in chunk.lower() for chunk in top_chunks):
                hits += 1

        results[size] = {
            "recall@5": hits / len(queries),
            "num_chunks": len(all_chunks),
            "avg_chunk_len": np.mean([len(c) for c in all_chunks]),
        }

    return results
```

### Recommendations by Document Type

| Document Type | Chunk Size | Overlap | Splitter |
|---|---|---|---|
| General articles | 512 | 50 | `RecursiveCharacterTextSplitter` |
| Technical docs | 800 | 100 | Markdown-aware separators |
| Code files | 500 | 100 | `from_language()` splitter |
| Legal documents | 1000 | 150 | Sentence-aware splitting |
| FAQ / Q&A pairs | Per pair | 0 | Split by Q&A boundary |

## Overlap Strategy

### Why Overlap Matters

Without overlap, information at chunk boundaries is split across two chunks, and neither chunk contains the full context. Overlap ensures boundary information appears in at least one chunk.

### Overlap Guidelines

| Chunk Size | Recommended Overlap | Ratio |
|---|---|---|
| 256 chars | 25-50 chars | 10-20% |
| 512 chars | 50-100 chars | 10-20% |
| 1024 chars | 100-150 chars | 10-15% |
| 2048 chars | 150-200 chars | 7-10% |

**Rules of thumb**:
- Start with 10% overlap
- Increase to 20% for documents with long cross-referencing sentences
- Use 0% overlap for naturally bounded items (Q&A pairs, log entries, chat messages)
- Higher overlap = more chunks = more storage + slower indexing, but better boundary coverage

## Re-Ranking with Cross-Encoders

### Why Re-Rank?

Bi-encoders (sentence-transformers) encode query and document independently — fast but less precise. Cross-encoders process query-document pairs jointly — slower but much more accurate for relevance scoring.

**Pattern**: Retrieve top-N with bi-encoder → re-rank to top-K with cross-encoder (N >> K).

### Cross-Encoder Models

| Model | Speed | Quality | Use Case |
|---|---|---|---|
| `cross-encoder/ms-marco-MiniLM-L-6-v2` | Fast | Good | Low-latency applications |
| `cross-encoder/ms-marco-MiniLM-L-12-v2` | Medium | Better | Best speed/quality balance |
| `cross-encoder/ms-marco-electra-base` | Slow | Best | Maximum quality |
| `BAAI/bge-reranker-base` | Medium | Better | Works well with BGE embeddings |
| `BAAI/bge-reranker-large` | Slow | Best | Maximum quality with BGE |

### Implementation

```python
from sentence_transformers import CrossEncoder
import numpy as np

# Load cross-encoder
reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-12-v2", device="cuda")

def retrieve_and_rerank(
    query: str,
    initial_k: int = 20,
    final_k: int = 5,
) -> list[dict]:
    # Stage 1: Bi-encoder retrieval
    query_emb = bi_encoder.encode([query], normalize_embeddings=True)
    scores, indices = index.search(np.array(query_emb, dtype="float32"), initial_k)

    candidates = [
        {"text": chunks[idx], "bi_score": float(score), "index": int(idx)}
        for score, idx in zip(scores[0], indices[0])
    ]

    # Stage 2: Cross-encoder re-ranking
    pairs = [(query, c["text"]) for c in candidates]
    rerank_scores = reranker.predict(pairs, batch_size=32)

    for i, score in enumerate(rerank_scores):
        candidates[i]["rerank_score"] = float(score)

    # Sort by re-rank score and return top-K
    candidates.sort(key=lambda x: x["rerank_score"], reverse=True)
    return candidates[:final_k]
```

### Latency Considerations

| initial_k | final_k | Cross-Encoder Calls | Typical Latency (GPU) |
|---|---|---|---|
| 10 | 3 | 10 | ~15ms |
| 20 | 5 | 20 | ~25ms |
| 50 | 10 | 50 | ~50ms |
| 100 | 10 | 100 | ~100ms |

Keep `initial_k` ≤ 50 for interactive applications. For batch processing, higher values improve quality.

## Hybrid Search (BM25 + Vector)

### Why Hybrid?

| Search Type | Strengths | Weaknesses |
|---|---|---|
| BM25 (keyword) | Exact term matching, acronyms, IDs, code | Misses synonyms, paraphrases |
| Vector (semantic) | Synonyms, paraphrases, conceptual similarity | Misses exact keywords, rare terms |
| Hybrid (both) | Best of both worlds | More complex, needs score fusion |

### Implementation with rank_bm25

```python
from rank_bm25 import BM25Okapi
import numpy as np

# Build BM25 index
tokenized_chunks = [chunk.lower().split() for chunk in chunks]
bm25 = BM25Okapi(tokenized_chunks)

def hybrid_search(
    query: str,
    k: int = 5,
    bm25_weight: float = 0.3,
    vector_weight: float = 0.7,
) -> list[dict]:
    # BM25 scores
    tokenized_query = query.lower().split()
    bm25_scores = bm25.get_scores(tokenized_query)

    # Vector scores
    query_emb = model.encode([query], normalize_embeddings=True)
    vector_scores = np.dot(embeddings, query_emb.T).flatten()

    # Normalize scores to [0, 1]
    bm25_norm = (bm25_scores - bm25_scores.min()) / (bm25_scores.max() - bm25_scores.min() + 1e-8)
    vector_norm = (vector_scores - vector_scores.min()) / (vector_scores.max() - vector_scores.min() + 1e-8)

    # Weighted combination
    combined = bm25_weight * bm25_norm + vector_weight * vector_norm

    # Top-k results
    top_indices = np.argsort(combined)[-k:][::-1]
    return [
        {"text": chunks[i], "score": float(combined[i]), "bm25": float(bm25_norm[i]), "vector": float(vector_norm[i])}
        for i in top_indices
    ]
```

### Reciprocal Rank Fusion (RRF)

Alternative to weighted combination — more robust, no normalization needed:

```python
def reciprocal_rank_fusion(
    rankings: list[list[int]],
    k: int = 60,
) -> list[tuple[int, float]]:
    """Fuse multiple ranked lists using RRF.

    Args:
        rankings: List of ranked lists (each is a list of document indices)
        k: RRF constant (default 60, higher = more weight to lower-ranked items)
    """
    scores = {}
    for ranking in rankings:
        for rank, doc_id in enumerate(ranking):
            scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank + 1)

    return sorted(scores.items(), key=lambda x: x[1], reverse=True)

# Usage
bm25_ranking = np.argsort(bm25_scores)[::-1][:50].tolist()
vector_ranking = np.argsort(vector_scores)[::-1][:50].tolist()

fused = reciprocal_rank_fusion([bm25_ranking, vector_ranking])
top_k = fused[:5]  # List of (doc_id, rrf_score)
```

### Weight Tuning Guidelines

| Query Type | BM25 Weight | Vector Weight | Why |
|---|---|---|---|
| Technical / code queries | 0.4-0.5 | 0.5-0.6 | Exact terms matter (function names, error codes) |
| Natural language questions | 0.2-0.3 | 0.7-0.8 | Semantic understanding more important |
| Mixed (general default) | 0.3 | 0.7 | Good starting point |
| Keyword-heavy (IDs, names) | 0.5-0.7 | 0.3-0.5 | BM25 excels at exact matching |

## Metadata Filtering

### Pre-Filter vs Post-Filter

| Strategy | How | Pros | Cons |
|---|---|---|---|
| Pre-filter | Filter metadata before vector search | Smaller search space, faster | May miss relevant docs outside filter |
| Post-filter | Vector search first, then filter results | Considers all docs | May return fewer than K results |
| Hybrid | Pre-filter with broad criteria, post-filter for precision | Balanced | More complex |

### Common Metadata Fields

```python
metadata = {
    "source": "wiki",           # Document source
    "date": "2024-01-15",       # Publication/update date
    "category": "ml",           # Topic category
    "language": "en",           # Document language
    "doc_id": "doc_001",        # Parent document ID
    "chunk_index": 3,           # Position within parent document
    "author": "team-ml",        # Author or team
    "version": "2.1",           # Document version
}
```

### Filtering Patterns by Vector Store

```python
# ChromaDB
results = collection.query(
    query_embeddings=[query_emb],
    n_results=5,
    where={
        "$and": [
            {"source": {"$eq": "wiki"}},
            {"date": {"$gte": "2024-01-01"}},
            {"category": {"$in": ["ml", "ai"]}},
        ]
    },
)

# Qdrant
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range, MatchAny

results = client.search(
    collection_name="documents",
    query_vector=query_emb,
    limit=5,
    query_filter=Filter(
        must=[
            FieldCondition(key="source", match=MatchValue(value="wiki")),
            FieldCondition(key="date", range=Range(gte="2024-01-01")),
            FieldCondition(key="category", match=MatchAny(any=["ml", "ai"])),
        ]
    ),
)

# FAISS: No built-in filtering — filter externally
scores, indices = index.search(query_emb, k=50)  # Over-retrieve
filtered = [
    (score, idx) for score, idx in zip(scores[0], indices[0])
    if chunk_metadata[idx]["source"] == "wiki"
    and chunk_metadata[idx]["date"] >= "2024-01-01"
][:5]  # Take top 5 after filtering
```
