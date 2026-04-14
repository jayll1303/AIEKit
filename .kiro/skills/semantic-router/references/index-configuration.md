# Index Configuration

Indexes store and retrieve route embeddings. Choose based on persistence and scale needs.

## When to Load

Load when: setting up production indexes, configuring Pinecone/Qdrant/Postgres, or troubleshooting sync issues.

## LocalIndex (Default)

In-memory, ephemeral. Good for development and testing.

```python
from semantic_router.index import LocalIndex

index = LocalIndex()

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=index,  # Optional, LocalIndex is default
)
```

**Limitations:**
- Lost when application restarts
- Limited by available memory
- Single-process only

## PineconeIndex

Cloud-hosted, persistent, scalable.

```python
import os
from semantic_router.index import PineconeIndex

os.environ["PINECONE_API_KEY"] = "your-api-key"

index = PineconeIndex(
    index_name="semantic-router",
    dimensions=1536,  # MUST match encoder output dimension
    # Optional:
    # environment="us-east-1-aws",
    # metric="cosine",  # or "euclidean", "dotproduct"
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=index,
    auto_sync="remote",  # Push routes to Pinecone
)
```

**Encoder Dimensions:**
| Encoder | Dimensions |
|---------|------------|
| OpenAIEncoder (text-embedding-ada-002) | 1536 |
| OpenAIEncoder (text-embedding-3-small) | 1536 |
| OpenAIEncoder (text-embedding-3-large) | 3072 |
| CohereEncoder (embed-english-v3.0) | 1024 |
| HuggingFaceEncoder (all-MiniLM-L6-v2) | 384 |
| FastEmbedEncoder (default) | 384 |

## QdrantIndex

Self-hosted or Qdrant Cloud.

```python
from semantic_router.index import QdrantIndex

# Local Qdrant
index = QdrantIndex(
    url="http://localhost:6333",
    collection_name="semantic-router",
)

# Qdrant Cloud
index = QdrantIndex(
    url="https://xxx.qdrant.io",
    api_key="your-qdrant-api-key",
    collection_name="semantic-router",
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=index,
    auto_sync="remote",
)
```

## PostgresIndex

Use existing Postgres with pgvector extension.

```python
from semantic_router.index import PostgresIndex

index = PostgresIndex(
    connection_string="postgresql://user:pass@localhost:5432/db",
    table_name="semantic_routes",
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=index,
    auto_sync="remote",
)
```

**Prerequisites:**
1. Install pgvector extension: `CREATE EXTENSION vector;`
2. Install semantic-router with postgres: `pip install "semantic-router[postgres]"`

## HybridLocalIndex

Combines dense (semantic) and sparse (keyword) embeddings.

```python
from semantic_router.index import HybridLocalIndex
from semantic_router.routers import HybridRouter
from semantic_router.encoders import OpenAIEncoder, AurelioSparseEncoder

dense_encoder = OpenAIEncoder()
sparse_encoder = AurelioSparseEncoder()  # Requires AURELIO_API_KEY

index = HybridLocalIndex()

router = HybridRouter(
    encoder=dense_encoder,
    sparse_encoder=sparse_encoder,
    routes=routes,
    index=index,
    alpha=0.5,  # Balance: 0=dense only, 1=sparse only
)
```

## Auto-Sync Configuration

| Mode | Direction | Use Case |
|------|-----------|----------|
| `"local"` | Remote → Local | Load existing routes from remote |
| `"remote"` | Local → Remote | Push new routes to remote |
| `None` | No sync | Manual control |

```python
# Push local routes to remote index
sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    index=pinecone_index,
    auto_sync="remote",
)

# Pull routes from remote index
sr = SemanticRouter(
    encoder=encoder,
    routes=[],  # Empty, will be populated from remote
    index=pinecone_index,
    auto_sync="local",
)
```

## Adding Routes After Initialization

```python
# Add single route
new_route = Route(name="greetings", utterances=["Hello", "Hi there"])
sr.add(new_route)  # Auto-syncs if auto_sync is set

# Add multiple routes
sr.add([route1, route2])
```

## Index Methods

All indexes implement:

```python
# Add embeddings
index.add(embeddings, routes, utterances)

# Search for similar vectors
results = index.query(query_embedding, top_k=5)

# Remove routes
index.delete(route_name)

# Get index info
info = index.describe()

# Check readiness
is_ready = index.is_ready()
```

## Troubleshooting

```
Dimension mismatch error?
├─ Check encoder output dimension
├─ Verify index dimensions parameter matches
└─ Recreate index with correct dimensions

Sync not working?
├─ Verify API keys are set correctly
├─ Check auto_sync mode ("local" vs "remote")
├─ Ensure index.is_ready() returns True
└─ Check network connectivity to remote service

Slow queries?
├─ Use remote index for large route sets
├─ Consider HybridRouter for better precision
└─ Reduce number of utterances per route if excessive
```
