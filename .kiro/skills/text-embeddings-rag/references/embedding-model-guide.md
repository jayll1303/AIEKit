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

## Vietnamese Embedding Models (VN-MTEB Benchmark)

Khi làm embedding với tiếng Việt, KHÔNG dùng bảng model comparison ở trên (đó là MTEB English). Phải tham khảo VN-MTEB — benchmark chuyên cho tiếng Việt với 41 datasets trên 6 tasks.

> Reference: [VN-MTEB: Vietnamese Massive Text Embedding Benchmark](https://arxiv.org/abs/2507.21500) (EACL 2026 Findings). Datasets: [HuggingFace VN-MTEB](https://huggingface.co/collections/greennode-ai/vn-mteb)

### VN-MTEB Key Findings

- RoPE-based models (Rotary Positional Embedding) vượt trội APE-based models (Absolute Positional Embedding) trên Vietnamese
- Model lớn hơn + instruct-tuned cho kết quả tốt hơn rõ rệt
- Benchmark gồm 6 tasks: Retrieval, Reranking, Classification, Clustering, Pair Classification, STS

### VN-MTEB Model Ranking (Top Models)

| Model | Type | Params | Avg Score | Retrieval | Classification | Clustering | Reranking | STS | Pair Class. |
|---|---|---|---|---|---|---|---|---|---|
| `Alibaba-NLP/gte-Qwen2-7B-instruct` | RoPE* | 7B | ~57.5 | ~47.3 | ~70.8 | ~53.2 | ~74.3 | ~78.7 | ~72.1 |
| `intfloat/e5-mistral-7b-instruct` | RoPE* | 7B | ~56.5 | ~44.5 | ~72.2 | ~51.7 | ~75.2 | ~81.2 | ~84.0 |
| `google/bge-multilingual-gemma2` | RoPE* | 2B | ~44.8 | ~21.5 | ~71.8 | ~40.1 | ~64.2 | ~66.1 | ~67.0 |
| `Alibaba-NLP/gte-Qwen2-1.5B-instruct` | RoPE* | 1.5B | ~53.8 | ~43.0 | ~67.1 | ~47.6 | ~71.4 | ~80.0 | ~72.7 |
| `BAAI/bge-m3` | APE | 568M | ~48.5 | ~28.5 | ~68.5 | ~44.5 | ~68.0 | ~72.5 | ~72.0 |
| `intfloat/multilingual-e5-large` | APE | 560M | ~47.0 | ~27.0 | ~66.0 | ~42.0 | ~67.5 | ~73.0 | ~70.0 |
| `intfloat/multilingual-e5-large-instruct` | APE* | 560M | ~50.5 | ~32.0 | ~70.0 | ~45.0 | ~70.0 | ~76.0 | ~73.0 |

*\* = Instruct-tuned. Scores approximate from VN-MTEB paper Table 3. Check [MTEB Leaderboard](https://huggingface.co/spaces/mteb/leaderboard) for latest.*

### Vietnamese Monolingual Models

Các model train riêng cho tiếng Việt — nhỏ hơn, nhanh hơn, nhưng chỉ hỗ trợ Vietnamese:

| Model | Base | Dimension | Max Tokens | Notes |
|---|---|---|---|---|
| `dangvantuan/vietnamese-embedding` | PhoBERT | 768 | 256 | Sentence embedding, trained on STS-VN |
| `dangvantuan/vietnamese-document-embedding` | gte-multilingual | 768 | 8192 | Long document, Matryoshka support |
| `VoVanPhuc/sup-SimCSE-VietNamese-phobert-base` | PhoBERT | 768 | 256 | SimCSE contrastive learning |
| `bkai-foundation-models/vietnamese-bi-encoder` | PhoBERT | 768 | 256 | Bi-encoder for retrieval |
| `AITeamVN/Vietnamese_Embedding` | — | — | — | Trained on Zalo Legal Text Retrieval |

### Vietnamese Model Selection Guide

| Scenario | Recommended Model | Why |
|---|---|---|
| Vietnamese RAG, max quality, có GPU mạnh | `Alibaba-NLP/gte-Qwen2-7B-instruct` | Top VN-MTEB, RoPE, 8K context |
| Vietnamese RAG, balanced quality/speed | `Alibaba-NLP/gte-Qwen2-1.5B-instruct` | Gần top VN-MTEB, nhỏ hơn 4.5x |
| Vietnamese RAG, limited VRAM | `intfloat/multilingual-e5-large-instruct` | APE nhưng instruct-tuned, 560M params |
| Vietnamese short text (STS, classification) | `dangvantuan/vietnamese-embedding` | Nhỏ, nhanh, train riêng cho VN |
| Vietnamese long documents (>512 tokens) | `dangvantuan/vietnamese-document-embedding` | 8K context, Matryoshka, train cho VN |
| Multilingual pipeline có Vietnamese | `BAAI/bge-m3` | 100+ langs, 8K context, multi-task |

### Vietnamese-Specific Considerations

**Word Segmentation cho BM25 Hybrid Search:**

Tiếng Việt là ngôn ngữ đơn lập (isolating language) — mỗi từ có thể gồm nhiều âm tiết cách nhau bởi dấu cách. Ví dụ: "học sinh" là 1 từ nhưng có 2 tokens khi split bằng whitespace. Khi dùng BM25 hybrid search, cần word segmentation:

```python
# WRONG: naive whitespace split cho tiếng Việt
tokens = "học sinh giỏi nhất trường".split()
# → ["học", "sinh", "giỏi", "nhất", "trường"] — sai ngữ nghĩa

# RIGHT: dùng underthesea hoặc pyvi cho word segmentation
# pip install underthesea
from underthesea import word_tokenize

tokens = word_tokenize("học sinh giỏi nhất trường")
# → ["học_sinh", "giỏi", "nhất", "trường"] — đúng ngữ nghĩa

# Áp dụng cho BM25
from rank_bm25 import BM25Okapi

# Tokenize corpus với word segmentation
tokenized_chunks = [word_tokenize(chunk) for chunk in chunks]
bm25 = BM25Okapi(tokenized_chunks)

# Tokenize query tương tự
tokenized_query = word_tokenize(query)
bm25_scores = bm25.get_scores(tokenized_query)
```

**Embedding Vietnamese Text:**

```python
from sentence_transformers import SentenceTransformer

# Top choice cho Vietnamese theo VN-MTEB
model = SentenceTransformer("Alibaba-NLP/gte-Qwen2-1.5B-instruct", device="cuda")

# Vietnamese texts — không cần word segmentation cho embedding models
# (embedding models tự handle tokenization)
texts = [
    "Trí tuệ nhân tạo đang thay đổi thế giới.",
    "Học máy là một nhánh của AI.",
    "RAG kết hợp truy xuất với sinh văn bản.",
]
embeddings = model.encode(texts, normalize_embeddings=True)

# Cross-lingual: query tiếng Việt, corpus tiếng Anh (hoặc ngược lại)
query = model.encode(["Học máy là gì?"], normalize_embeddings=True)
import numpy as np
similarities = np.dot(query, embeddings.T)
```

**Chunking tiếng Việt:**

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Vietnamese separators — ưu tiên tách theo câu/đoạn
vn_splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=50,
    separators=["\n\n", "\n", ". ", "! ", "? ", "; ", ", ", " ", ""],
)
```

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
