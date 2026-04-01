---
name: text-embeddings-rag
description: "Build local RAG pipelines with sentence-transformers, FAISS, ChromaDB, Qdrant. Use when generating embeddings, setting up semantic search, or optimizing retrieval with re-ranking and hybrid search."
---

# Text Embeddings & RAG

Patterns for building local RAG (Retrieval-Augmented Generation) pipelines using sentence-transformers for embedding generation, FAISS/ChromaDB/Qdrant for vector storage, and retrieval optimization techniques for production-quality semantic search.

## Scope

This skill handles:
- Generating text embeddings locally with sentence-transformers (model loading, batch encoding, GPU acceleration)
- Setting up and querying vector stores (FAISS, ChromaDB, Qdrant) for semantic search
- Building end-to-end RAG pipelines (chunking → embedding → indexing → retrieval → generation)
- Choosing embedding models by quality (MTEB), dimension, speed, and multilingual support
- Optimizing retrieval quality with chunk tuning, overlap, re-ranking, and hybrid search (BM25 + vector)

Does NOT handle:
- Downloading models/datasets from HuggingFace Hub (→ hf-hub-datasets)
- Serving the LLM generation backend for RAG (→ vllm-tgi-inference)
- Fine-tuning embedding models or LLMs (→ hf-transformers-trainer)
- Installing ML Python dependencies or resolving CUDA conflicts (→ python-ml-deps)

## When to Use

- Generating text embeddings locally with sentence-transformers and GPU acceleration
- Setting up a local vector store (FAISS, ChromaDB, or Qdrant) for semantic search
- Building an end-to-end RAG pipeline (chunking → embedding → indexing → retrieval → generation)
- Choosing an embedding model based on quality metrics (MTEB), dimension, speed, or multilingual support
- Optimizing retrieval quality with chunk size tuning, overlap, re-ranking, or hybrid search
- Comparing vector stores for prototype vs production (FAISS, ChromaDB, Qdrant)

## Embedding Quick Start

### Load Model and Encode

```python
from sentence_transformers import SentenceTransformer

# Load a model (auto-downloads from HuggingFace Hub)
model = SentenceTransformer("BAAI/bge-base-en-v1.5")

# Encode single text
embedding = model.encode("What is retrieval-augmented generation?")
print(f"Dimension: {embedding.shape}")  # (768,)

# Encode batch
texts = [
    "RAG combines retrieval with generation.",
    "Vector databases store embeddings for similarity search.",
    "Chunking documents improves retrieval precision.",
]
embeddings = model.encode(texts, show_progress_bar=True)
print(f"Shape: {embeddings.shape}")  # (3, 768)
```

### Batch Processing with GPU Acceleration

```python
from sentence_transformers import SentenceTransformer

# Force GPU usage
model = SentenceTransformer("BAAI/bge-base-en-v1.5", device="cuda")

# Large batch encoding with optimal settings
documents = [...]  # List of document chunks
embeddings = model.encode(
    documents,
    batch_size=256,          # Increase for GPU (default 32)
    show_progress_bar=True,
    normalize_embeddings=True,  # L2 normalize for cosine similarity
    convert_to_numpy=True,
)
```

### Normalize for Cosine Similarity

```python
# Option 1: Normalize at encode time (recommended)
embeddings = model.encode(texts, normalize_embeddings=True)

# Option 2: Normalize after encoding
import numpy as np
embeddings = embeddings / np.linalg.norm(embeddings, axis=1, keepdims=True)

# With normalized vectors, dot product == cosine similarity
# Use IndexFlatIP (inner product) in FAISS for fastest cosine search
```

**Validate:** `embedding.shape` returns expected dimension (e.g., `(768,)` for bge-base). If not → verify model name is correct and `sentence-transformers` is installed (`pip show sentence-transformers`).

> For model selection guidance (MTEB benchmarks, multilingual, dimension comparison), see [embedding-model-guide](references/embedding-model-guide.md)

## Vector Store Setup

### FAISS

```python
import faiss
import numpy as np

dimension = 768  # Must match embedding model dimension
index = faiss.IndexFlatIP(dimension)  # Inner product (use with normalized vectors)

# Insert embeddings
embeddings = np.array(embeddings, dtype="float32")
index.add(embeddings)
print(f"Total vectors: {index.ntotal}")

# Search
query_embedding = model.encode(["search query"], normalize_embeddings=True)
query_embedding = np.array(query_embedding, dtype="float32")
scores, indices = index.search(query_embedding, k=5)  # Top 5 results

# Persist to disk
faiss.write_index(index, "my_index.faiss")
index = faiss.read_index("my_index.faiss")
```

### ChromaDB

```python
import chromadb

# Persistent local storage
client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(
    name="documents",
    metadata={"hnsw:space": "cosine"},  # cosine similarity
)

# Insert documents with embeddings and metadata
collection.add(
    ids=["doc1", "doc2", "doc3"],
    embeddings=embeddings.tolist(),
    documents=["First document text", "Second document text", "Third document text"],
    metadatas=[{"source": "wiki"}, {"source": "arxiv"}, {"source": "wiki"}],
)

# Query with metadata filtering
results = collection.query(
    query_embeddings=[query_embedding.tolist()],
    n_results=5,
    where={"source": "wiki"},  # Filter by metadata
)
```

### Qdrant

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect to Qdrant (Docker: docker run -p 6333:6333 qdrant/qdrant)
client = QdrantClient(host="localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
)

# Insert points
points = [
    PointStruct(id=i, vector=emb.tolist(), payload={"text": text, "source": "wiki"})
    for i, (emb, text) in enumerate(zip(embeddings, texts))
]
client.upsert(collection_name="documents", points=points)

# Search with payload filtering
results = client.search(
    collection_name="documents",
    query_vector=query_embedding.tolist(),
    limit=5,
    query_filter={"must": [{"key": "source", "match": {"value": "wiki"}}]},
)
```

**Validate:** `index.ntotal` (FAISS), `collection.count()` (ChromaDB), or `client.get_collection("documents").points_count` (Qdrant) returns expected document count. If not → verify embeddings dtype is `float32` and dimension matches model output.

> For detailed setup including persistence, indexing options, and production config, see [vector-store-setup](references/vector-store-setup.md)

## RAG Pipeline Template

End-to-end RAG pipeline: document chunking → embedding → indexing → retrieval → generation.

### Step 1: Document Chunking

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,       # Characters per chunk
    chunk_overlap=50,     # Overlap between chunks
    separators=["\n\n", "\n", ". ", " ", ""],
)

documents = [...]  # Raw document texts
chunks = []
chunk_metadata = []
for doc_id, doc_text in enumerate(documents):
    doc_chunks = splitter.split_text(doc_text)
    for i, chunk in enumerate(doc_chunks):
        chunks.append(chunk)
        chunk_metadata.append({"doc_id": doc_id, "chunk_index": i})
```

### Step 2: Embed and Index

```python
from sentence_transformers import SentenceTransformer
import faiss
import numpy as np

model = SentenceTransformer("BAAI/bge-base-en-v1.5", device="cuda")
embeddings = model.encode(chunks, normalize_embeddings=True, batch_size=256)

# Build FAISS index
index = faiss.IndexFlatIP(embeddings.shape[1])
index.add(np.array(embeddings, dtype="float32"))

# Save index and chunks for later retrieval
faiss.write_index(index, "rag_index.faiss")
```

**Validate:** `index.ntotal == len(chunks)` confirms all chunks are indexed. If not → check for empty chunks or encoding errors in `model.encode()` output.

### Step 3: Retrieve

```python
def retrieve(query: str, k: int = 5) -> list[dict]:
    query_emb = model.encode([query], normalize_embeddings=True)
    scores, indices = index.search(np.array(query_emb, dtype="float32"), k)
    results = []
    for score, idx in zip(scores[0], indices[0]):
        results.append({
            "text": chunks[idx],
            "score": float(score),
            "metadata": chunk_metadata[idx],
        })
    return results
```

### Step 4: Generate with Retrieved Context

```python
from openai import OpenAI

# Connect to local LLM server (vLLM/TGI with OpenAI-compatible API)
client = OpenAI(base_url="http://localhost:8000/v1", api_key="not-needed")

def rag_query(question: str, k: int = 5) -> str:
    # Retrieve relevant chunks
    retrieved = retrieve(question, k=k)
    context = "\n\n---\n\n".join([r["text"] for r in retrieved])

    # Generate answer
    response = client.chat.completions.create(
        model="meta-llama/Llama-3.1-8B-Instruct",
        messages=[
            {"role": "system", "content": (
                "Answer the question based on the provided context. "
                "If the context doesn't contain enough information, say so. "
                "Cite relevant parts of the context in your answer."
            )},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"},
        ],
        temperature=0.1,
        max_tokens=1024,
    )
    return response.choices[0].message.content
```

**Validate:** `retrieve(question)` returns results with `score > 0.5` for relevant queries. If not → check embedding normalization, chunk size, or try a different embedding model.

> For advanced RAG patterns (multi-hop, query decomposition, context window management), see [rag-pipeline-patterns](references/rag-pipeline-patterns.md)

## Retrieval Optimization Checklist

```
Poor retrieval quality?
├─ Chunk size issues?
│   ├─ Too large (>1000 chars): Chunks contain mixed topics, diluting relevance
│   ├─ Too small (<200 chars): Chunks lack context, fragmented information
│   ├─ Recommended: Start with 512 chars, tune based on document type
│   └─ Tip: Use RecursiveCharacterTextSplitter with semantic separators
│
├─ Overlap strategy?
│   ├─ No overlap: Risk losing context at chunk boundaries
│   ├─ Recommended: 10-20% of chunk_size (e.g., 50-100 chars for 512 chunk)
│   └─ Tip: Increase overlap for documents with long cross-referencing paragraphs
│
├─ Re-ranking needed?
│   ├─ Problem: Bi-encoder retrieval is fast but imprecise for nuanced queries
│   ├─ Solution: Add cross-encoder re-ranker after initial retrieval
│   ├─ Pattern: Retrieve top-20 with bi-encoder → re-rank to top-5 with cross-encoder
│   └─ Model: cross-encoder/ms-marco-MiniLM-L-12-v2 (good speed/quality balance)
│
├─ Hybrid search (BM25 + vector)?
│   ├─ Problem: Vector search misses exact keyword matches
│   ├─ Solution: Combine BM25 (keyword) + vector (semantic) with score fusion
│   ├─ Libraries: rank_bm25 for BM25, reciprocal rank fusion for combining
│   └─ Tip: Weight BM25 higher for technical/code queries, vector higher for natural language
│
├─ Embedding model quality?
│   ├─ Check MTEB leaderboard for model quality benchmarks
│   ├─ Consider domain-specific models for specialized content
│   └─ See embedding-model-guide reference for model comparison
│
└─ Metadata filtering?
    ├─ Add metadata (source, date, category) to chunks at indexing time
    ├─ Filter by metadata before or during vector search
    └─ Reduces search space and improves relevance for structured corpora
```

> For detailed optimization techniques, see [retrieval-optimization](references/retrieval-optimization.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Embedding model nào cũng được, chọn cái nhỏ nhất cho nhanh" | Chất lượng retrieval phụ thuộc lớn vào model; luôn check MTEB leaderboard và chọn model phù hợp domain trước khi build pipeline |
| "Không cần normalize embeddings, cosine similarity tự xử lý" | FAISS `IndexFlatIP` yêu cầu L2-normalized vectors để dot product == cosine similarity; thiếu normalize → kết quả search sai hoàn toàn |
| "Chunk size 512 là chuẩn, không cần tune" | Chunk size tối ưu phụ thuộc vào document type; code cần chunk nhỏ hơn (~256), long-form text có thể cần lớn hơn (~1024); luôn evaluate retrieval quality |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to download embedding models or datasets from HuggingFace Hub | hf-hub-datasets | Handles snapshot_download, load_dataset, private repo access |
| Need to serve the LLM backend for RAG generation step | vllm-tgi-inference | Handles vLLM/TGI server setup with OpenAI-compatible API |
| Need to fine-tune an embedding model on domain-specific data | hf-transformers-trainer | Handles Trainer, LoRA, SFTTrainer for model fine-tuning |
| Need to install sentence-transformers, faiss-gpu, or resolve CUDA conflicts | python-ml-deps | Handles uv pip install, PyTorch CUDA, dependency resolution |

## References

- [Embedding Model Guide](references/embedding-model-guide.md) — Model selection guide comparing popular models by dimension, speed, quality metrics (MTEB), and multilingual support
  **Load when:** choosing an embedding model or comparing MTEB benchmarks for a specific domain or language
- [Vector Store Setup](references/vector-store-setup.md) — Detailed setup for FAISS, ChromaDB, Qdrant: index creation, document insertion, similarity search, persistence, production config
  **Load when:** configuring vector store persistence, production indexing options, or switching between FAISS/ChromaDB/Qdrant
- [RAG Pipeline Patterns](references/rag-pipeline-patterns.md) — Advanced RAG patterns: document chunking strategies, prompt templates, context window management, multi-hop retrieval
  **Load when:** implementing multi-hop retrieval, query decomposition, or optimizing RAG prompt templates
- [Retrieval Optimization](references/retrieval-optimization.md) — Chunk size tuning, overlap strategy, re-ranking with cross-encoders, hybrid search (BM25 + vector), metadata filtering
  **Load when:** retrieval quality is poor and need to tune chunk size, add re-ranking, or implement hybrid BM25+vector search
