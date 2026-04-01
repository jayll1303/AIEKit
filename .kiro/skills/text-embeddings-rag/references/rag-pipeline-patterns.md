# RAG Pipeline Patterns

Advanced RAG patterns covering document chunking strategies, prompt templates, context window management, and multi-stage retrieval architectures.

## Document Chunking Strategies

### Fixed-Size Chunking

Simplest approach — split by character count with overlap.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=50,
    separators=["\n\n", "\n", ". ", " ", ""],
    length_function=len,
)

chunks = splitter.split_text(document_text)
```

**When to use**: General-purpose, works well for most document types.

### Semantic Chunking

Split at natural semantic boundaries (paragraphs, sections, sentences).

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Markdown-aware splitting
markdown_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=100,
    separators=[
        "\n## ",    # H2 headers
        "\n### ",   # H3 headers
        "\n\n",     # Paragraphs
        "\n",       # Lines
        ". ",       # Sentences
        " ",        # Words
    ],
)

# Code-aware splitting
code_splitter = RecursiveCharacterTextSplitter.from_language(
    language="python",
    chunk_size=1000,
    chunk_overlap=100,
)
```

**When to use**: Structured documents (Markdown, code, HTML) where preserving section boundaries matters.

### Token-Based Chunking

Split by token count (matches LLM context windows more precisely).

```python
from langchain.text_splitter import TokenTextSplitter

splitter = TokenTextSplitter(
    encoding_name="cl100k_base",  # GPT-4/Llama tokenizer
    chunk_size=256,               # Tokens, not characters
    chunk_overlap=25,
)

chunks = splitter.split_text(document_text)
```

**When to use**: When precise token budget control matters (e.g., fitting N chunks into a fixed context window).

### Parent-Child Chunking

Index small chunks for precise retrieval, but return the parent (larger) chunk for context.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Parent chunks (large, for context)
parent_splitter = RecursiveCharacterTextSplitter(chunk_size=2000, chunk_overlap=200)
parent_chunks = parent_splitter.split_text(document_text)

# Child chunks (small, for retrieval)
child_splitter = RecursiveCharacterTextSplitter(chunk_size=400, chunk_overlap=50)

parent_child_map = {}
for parent_id, parent in enumerate(parent_chunks):
    children = child_splitter.split_text(parent)
    for child in children:
        parent_child_map[child] = parent_id

# Index child chunks, but retrieve parent chunks
# 1. Search child index → get child IDs
# 2. Map child IDs → parent IDs
# 3. Return parent chunks as context
```

**When to use**: When small chunks retrieve well but lack sufficient context for generation.

### Chunking Size Guidelines

| Document Type | Recommended Chunk Size | Overlap | Notes |
|---|---|---|---|
| General text / articles | 512 chars | 50 chars | Good default starting point |
| Technical documentation | 800-1000 chars | 100 chars | Preserve code blocks and explanations |
| Legal / regulatory | 1000-1500 chars | 150 chars | Preserve clause context |
| Code files | 500-800 chars | 100 chars | Use language-aware splitter |
| Chat / Q&A pairs | Per message/pair | 0 | Natural boundaries, no splitting needed |
| Short-form (tweets, logs) | Per item | 0 | Each item is a chunk |

## Prompt Templates

### Basic RAG Prompt

```python
SYSTEM_PROMPT = """Answer the question based on the provided context.
If the context doesn't contain enough information to answer, say "I don't have enough information to answer this question."
Cite relevant parts of the context in your answer."""

USER_PROMPT = """Context:
{context}

Question: {question}"""
```

### RAG with Source Attribution

```python
SYSTEM_PROMPT = """Answer the question based on the provided context.
Each context chunk is labeled with a source ID. Cite sources using [Source: ID] format.
If the context doesn't contain the answer, say so."""

def format_context_with_sources(retrieved_chunks: list[dict]) -> str:
    formatted = []
    for chunk in retrieved_chunks:
        source_id = chunk["metadata"].get("source_id", chunk["id"])
        formatted.append(f"[Source: {source_id}]\n{chunk['text']}")
    return "\n\n---\n\n".join(formatted)

USER_PROMPT = """Context:
{formatted_context}

Question: {question}

Provide a detailed answer with source citations."""
```

### Conversational RAG (Multi-Turn)

```python
SYSTEM_PROMPT = """You are a helpful assistant that answers questions based on provided context.
Use the conversation history to understand follow-up questions.
Always base your answers on the provided context."""

def build_conversational_prompt(
    question: str,
    context: str,
    history: list[dict],
) -> list[dict]:
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # Add conversation history
    for turn in history[-4:]:  # Keep last 4 turns to manage context window
        messages.append({"role": "user", "content": turn["question"]})
        messages.append({"role": "assistant", "content": turn["answer"]})

    # Current question with context
    messages.append({
        "role": "user",
        "content": f"Context:\n{context}\n\nQuestion: {question}",
    })
    return messages
```

### Query Rewriting for Better Retrieval

```python
REWRITE_PROMPT = """Given the conversation history and a follow-up question, rewrite the question to be a standalone question that captures the full intent.

Conversation history:
{history}

Follow-up question: {question}

Standalone question:"""

def rewrite_query(question: str, history: list[dict], llm_client) -> str:
    history_text = "\n".join(
        f"User: {t['question']}\nAssistant: {t['answer']}" for t in history[-3:]
    )
    response = llm_client.chat.completions.create(
        model="meta-llama/Llama-3.1-8B-Instruct",
        messages=[{"role": "user", "content": REWRITE_PROMPT.format(
            history=history_text, question=question
        )}],
        temperature=0.0,
        max_tokens=200,
    )
    return response.choices[0].message.content.strip()
```

## Context Window Management

### Token Budget Allocation

For a model with N tokens context window, allocate budget:

| Component | Budget | Example (8K context) |
|---|---|---|
| System prompt | 5-10% | ~500 tokens |
| Conversation history | 10-20% | ~1200 tokens |
| Retrieved context | 50-70% | ~4800 tokens |
| Generation headroom | 15-25% | ~1500 tokens |

### Dynamic Context Fitting

```python
import tiktoken

def fit_chunks_to_budget(
    chunks: list[dict],
    max_tokens: int = 4000,
    model: str = "cl100k_base",
) -> list[dict]:
    """Select chunks that fit within token budget, prioritized by relevance score."""
    encoder = tiktoken.get_encoding(model)
    selected = []
    total_tokens = 0

    for chunk in chunks:  # Assumed sorted by relevance (highest first)
        chunk_tokens = len(encoder.encode(chunk["text"]))
        if total_tokens + chunk_tokens > max_tokens:
            break
        selected.append(chunk)
        total_tokens += chunk_tokens

    return selected
```

### Stuffing vs Map-Reduce

**Stuffing** (default): Concatenate all retrieved chunks into a single prompt.
- Pros: Simple, single LLM call
- Cons: Limited by context window, may include irrelevant chunks
- Best for: Short contexts, fast responses

**Map-Reduce**: Process each chunk separately, then combine answers.
```python
def map_reduce_rag(question: str, chunks: list[dict], client) -> str:
    # Map: Extract relevant info from each chunk
    partial_answers = []
    for chunk in chunks:
        response = client.chat.completions.create(
            model="meta-llama/Llama-3.1-8B-Instruct",
            messages=[
                {"role": "system", "content": "Extract information relevant to the question from the given text. If not relevant, say 'Not relevant'."},
                {"role": "user", "content": f"Text: {chunk['text']}\n\nQuestion: {question}"},
            ],
            temperature=0.0,
            max_tokens=300,
        )
        answer = response.choices[0].message.content
        if "not relevant" not in answer.lower():
            partial_answers.append(answer)

    # Reduce: Combine partial answers
    combined = "\n\n".join(partial_answers)
    response = client.chat.completions.create(
        model="meta-llama/Llama-3.1-8B-Instruct",
        messages=[
            {"role": "system", "content": "Synthesize the following partial answers into a comprehensive response."},
            {"role": "user", "content": f"Partial answers:\n{combined}\n\nOriginal question: {question}"},
        ],
        temperature=0.1,
        max_tokens=1024,
    )
    return response.choices[0].message.content
```
- Pros: Handles large document sets, no context window limit
- Cons: Multiple LLM calls, slower, higher cost
- Best for: Large corpora, comprehensive answers

## Multi-Stage Retrieval

### Two-Stage: Retrieve + Re-rank

```python
from sentence_transformers import CrossEncoder

# Stage 1: Fast bi-encoder retrieval (top-20)
query_emb = bi_encoder.encode([query], normalize_embeddings=True)
scores, indices = index.search(query_emb, k=20)
candidates = [{"text": chunks[i], "score": s} for s, i in zip(scores[0], indices[0])]

# Stage 2: Precise cross-encoder re-ranking (top-5)
cross_encoder = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-12-v2")
pairs = [(query, c["text"]) for c in candidates]
rerank_scores = cross_encoder.predict(pairs)

# Sort by re-rank score
for i, score in enumerate(rerank_scores):
    candidates[i]["rerank_score"] = float(score)
candidates.sort(key=lambda x: x["rerank_score"], reverse=True)
top_results = candidates[:5]
```

### Multi-Query Retrieval

Generate multiple query variations to improve recall:

```python
def multi_query_retrieve(question: str, k: int = 5) -> list[dict]:
    # Generate query variations with LLM
    response = client.chat.completions.create(
        model="meta-llama/Llama-3.1-8B-Instruct",
        messages=[{
            "role": "user",
            "content": f"Generate 3 different search queries for: {question}\nReturn one query per line.",
        }],
        temperature=0.7,
    )
    queries = [question] + response.choices[0].message.content.strip().split("\n")

    # Retrieve for each query and deduplicate
    all_results = {}
    for q in queries:
        results = retrieve(q, k=k)
        for r in results:
            key = r["metadata"]["doc_id"], r["metadata"]["chunk_index"]
            if key not in all_results or r["score"] > all_results[key]["score"]:
                all_results[key] = r

    # Return top-k by score
    return sorted(all_results.values(), key=lambda x: x["score"], reverse=True)[:k]
```
