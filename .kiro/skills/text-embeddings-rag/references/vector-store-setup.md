# Vector Store Setup

Detailed setup guides for FAISS, ChromaDB, and Qdrant covering index creation, document insertion, similarity search, persistence, and production configuration.

## FAISS

### Installation

```bash
# CPU only
pip install faiss-cpu

# GPU accelerated (requires CUDA)
pip install faiss-gpu
```

### Index Types

| Index Type | Use Case | Speed | Memory | Accuracy |
|---|---|---|---|---|
| `IndexFlatL2` | Exact L2 search, small datasets | Slow (brute force) | Low | 100% |
| `IndexFlatIP` | Exact inner product, normalized vectors = cosine | Slow (brute force) | Low | 100% |
| `IndexIVFFlat` | Approximate search, medium datasets | Fast | Medium | ~95-99% |
| `IndexIVFPQ` | Approximate search, large datasets, compressed | Very fast | Very low | ~90-95% |
| `IndexHNSWFlat` | Approximate search, high recall | Fast | High | ~98-99% |

### Basic Usage (Flat Index)

```python
import faiss
import numpy as np

dimension = 768
index = faiss.IndexFlatIP(dimension)  # Inner product (cosine with normalized vectors)

# Add vectors
vectors = np.random.randn(10000, dimension).astype("float32")
faiss.normalize_L2(vectors)  # Normalize for cosine similarity
index.add(vectors)

print(f"Total vectors: {index.ntotal}")  # 10000

# Search
query = np.random.randn(1, dimension).astype("float32")
faiss.normalize_L2(query)
scores, indices = index.search(query, k=10)

# scores[0] = similarity scores (descending)
# indices[0] = vector IDs (0-indexed)
```

### IVF Index (Approximate, Faster)

```python
import faiss
import numpy as np

dimension = 768
nlist = 100  # Number of Voronoi cells (clusters)

# IVF requires training
quantizer = faiss.IndexFlatIP(dimension)
index = faiss.IndexIVFFlat(quantizer, dimension, nlist, faiss.METRIC_INNER_PRODUCT)

# Train on representative data
training_data = np.random.randn(50000, dimension).astype("float32")
faiss.normalize_L2(training_data)
index.train(training_data)

# Add vectors (must be done after training)
index.add(training_data)

# Search with nprobe tuning (higher = more accurate, slower)
index.nprobe = 10  # Search 10 out of 100 cells (default: 1)
scores, indices = index.search(query, k=10)
```

**nprobe tuning guide**:
- `nprobe=1`: Fastest, lowest recall (~70-80%)
- `nprobe=10`: Good balance (~95% recall)
- `nprobe=50`: High recall (~99%), slower
- `nprobe=nlist`: Equivalent to brute force (100% recall)

### GPU-Accelerated Search

```python
import faiss

# Move index to GPU
gpu_resource = faiss.StandardGpuResources()
gpu_index = faiss.index_cpu_to_gpu(gpu_resource, 0, cpu_index)  # GPU 0

# Search on GPU (same API)
scores, indices = gpu_index.search(query, k=10)

# Multi-GPU
gpu_index = faiss.index_cpu_to_all_gpus(cpu_index)
```

### Persistence

```python
# Save
faiss.write_index(index, "my_index.faiss")

# Load
index = faiss.read_index("my_index.faiss")
```

### ID Mapping

FAISS uses sequential integer IDs by default. To map to custom IDs:

```python
# Wrap index with ID map
index_flat = faiss.IndexFlatIP(dimension)
index = faiss.IndexIDMap(index_flat)

# Add with custom IDs
custom_ids = np.array([1001, 1002, 1003], dtype="int64")
index.add_with_ids(vectors, custom_ids)

# Search returns custom IDs
scores, ids = index.search(query, k=5)
```

## ChromaDB

### Installation

```bash
pip install chromadb
```

### Embedded Mode (Local, No Server)

```python
import chromadb

# In-memory (ephemeral)
client = chromadb.Client()

# Persistent storage (recommended)
client = chromadb.PersistentClient(path="./chroma_data")

# Create or get collection
collection = client.get_or_create_collection(
    name="documents",
    metadata={"hnsw:space": "cosine"},  # Distance metric: cosine, l2, ip
)
```

### Client-Server Mode (Production)

```bash
# Start ChromaDB server
docker run -d --name chromadb \
  -p 8000:8000 \
  -v ./chroma_data:/chroma/chroma \
  chromadb/chroma:latest
```

```python
import chromadb

client = chromadb.HttpClient(host="localhost", port=8000)
collection = client.get_or_create_collection("documents")
```

### Insert Documents

```python
# Add with pre-computed embeddings
collection.add(
    ids=["doc_001", "doc_002", "doc_003"],
    embeddings=[[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]],
    documents=["First document text", "Second document text", "Third document text"],
    metadatas=[
        {"source": "wiki", "date": "2024-01-15", "category": "science"},
        {"source": "arxiv", "date": "2024-02-20", "category": "ml"},
        {"source": "wiki", "date": "2024-03-10", "category": "science"},
    ],
)

# Update existing documents
collection.update(
    ids=["doc_001"],
    embeddings=[[0.11, 0.22, ...]],
    documents=["Updated first document text"],
)

# Upsert (insert or update)
collection.upsert(
    ids=["doc_004"],
    embeddings=[[0.7, 0.8, ...]],
    documents=["Fourth document text"],
)
```

### Query with Metadata Filtering

```python
# Basic similarity search
results = collection.query(
    query_embeddings=[[0.1, 0.2, ...]],
    n_results=5,
)

# Filter by metadata
results = collection.query(
    query_embeddings=[[0.1, 0.2, ...]],
    n_results=5,
    where={"source": "wiki"},
)

# Complex filters
results = collection.query(
    query_embeddings=[[0.1, 0.2, ...]],
    n_results=5,
    where={
        "$and": [
            {"source": {"$eq": "wiki"}},
            {"date": {"$gte": "2024-01-01"}},
        ]
    },
)

# Filter by document content
results = collection.query(
    query_embeddings=[[0.1, 0.2, ...]],
    n_results=5,
    where_document={"$contains": "machine learning"},
)
```

### Collection Management

```python
# List collections
collections = client.list_collections()

# Get collection info
print(collection.count())  # Number of documents
print(collection.peek())   # Preview first few documents

# Delete documents
collection.delete(ids=["doc_001", "doc_002"])

# Delete collection
client.delete_collection("documents")
```

## Qdrant

### Installation

```bash
# Python client
pip install qdrant-client

# Start Qdrant server with Docker
docker run -d --name qdrant \
  -p 6333:6333 -p 6334:6334 \
  -v ./qdrant_storage:/qdrant/storage \
  qdrant/qdrant:latest
```

### Connect and Create Collection

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

# Connect to server
client = QdrantClient(host="localhost", port=6333)

# Or use in-memory mode (no server needed, for testing)
# client = QdrantClient(":memory:")

# Create collection
client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(
        size=768,
        distance=Distance.COSINE,
    ),
    # Optional: enable on-disk storage for large collections
    # optimizers_config={"memmap_threshold": 20000},
)
```

### Insert Points

```python
from qdrant_client.models import PointStruct

# Single batch insert
points = [
    PointStruct(
        id=i,
        vector=embedding.tolist(),
        payload={
            "text": text,
            "source": "wiki",
            "date": "2024-01-15",
            "category": "science",
        },
    )
    for i, (embedding, text) in enumerate(zip(embeddings, texts))
]

client.upsert(collection_name="documents", points=points)

# Batch insert for large datasets
BATCH_SIZE = 1000
for i in range(0, len(points), BATCH_SIZE):
    batch = points[i : i + BATCH_SIZE]
    client.upsert(collection_name="documents", points=batch)
```

### Search with Payload Filtering

```python
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range

# Basic search
results = client.search(
    collection_name="documents",
    query_vector=query_embedding.tolist(),
    limit=5,
)

# Search with payload filter
results = client.search(
    collection_name="documents",
    query_vector=query_embedding.tolist(),
    limit=5,
    query_filter=Filter(
        must=[
            FieldCondition(key="source", match=MatchValue(value="wiki")),
            FieldCondition(key="date", range=Range(gte="2024-01-01")),
        ]
    ),
)

# Access results
for result in results:
    print(f"ID: {result.id}, Score: {result.score}")
    print(f"Text: {result.payload['text']}")
```

### Collection Management

```python
# Collection info
info = client.get_collection("documents")
print(f"Points: {info.points_count}")
print(f"Vectors: {info.vectors_count}")

# List collections
collections = client.get_collections()

# Delete points
client.delete(
    collection_name="documents",
    points_selector=[0, 1, 2],  # Point IDs to delete
)

# Delete collection
client.delete_collection("documents")
```

### Production Configuration

```python
from qdrant_client.models import OptimizersConfigDiff, HnswConfigDiff

# Optimize for large collections
client.update_collection(
    collection_name="documents",
    optimizer_config=OptimizersConfigDiff(
        memmap_threshold=20000,      # Use memory-mapped storage above this count
        indexing_threshold=20000,     # Build HNSW index above this count
    ),
    hnsw_config=HnswConfigDiff(
        m=16,                        # Number of edges per node (higher = better recall, more memory)
        ef_construct=100,            # Construction-time search width (higher = better index quality)
    ),
)
```

## Comparison Summary

| Feature | FAISS | ChromaDB | Qdrant |
|---|---|---|---|
| Deployment | Library (in-process) | Embedded or client-server | Client-server (Docker) |
| Metadata filtering | No (external) | Yes (built-in) | Yes (built-in, advanced) |
| Document storage | No (external) | Yes (built-in) | Yes (payload) |
| Persistence | File-based | File-based | File-based + WAL |
| GPU acceleration | Yes (faiss-gpu) | No | No |
| Distributed | No | No | Yes (sharding + replication) |
| Max scale | ~1B vectors (single node) | ~10M vectors | ~100M+ vectors (distributed) |
| API | Python only | Python + REST | REST + gRPC + Python |
| Best for | Maximum speed, research | Quick prototyping, metadata queries | Production, scalability |
