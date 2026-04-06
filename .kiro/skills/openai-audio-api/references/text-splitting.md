# Text Splitting for Streaming

Sentence splitting is critical for streaming — it determines latency and audio quality.

## Implementation

```python
import re

# Split at sentence boundaries
_SENTENCE_END = re.compile(
    r"(?<=[.!?])\s+(?=[A-Z\u4e00-\u9fff\u3040-\u30ff\u00C0-\u024F\u1E00-\u1EFF])"
    r"|(?<=[。！？])"
)

# Patterns that should NOT be treated as sentence boundaries
_FALSE_ENDS = re.compile(
    r"\d+\.\d+"           # Decimals: 3.14
    r"|v\d+\.\d+"         # Versions: v2.1.0
    r"|[A-Z][a-z]{0,3}\." # Abbreviations: Dr., Inc.
    r"|\w+\.\w{2,6}(?:/|\s|$)"  # URLs: example.com
)

def split_sentences(text: str, max_chars: int = 400) -> list[str]:
    if not text or not text.strip():
        return []
    text = text.strip()
    if len(text) <= max_chars:
        return [text]

    raw = _SENTENCE_END.split(text)
    raw = [s.strip() for s in raw if s.strip()]
    if not raw:
        return [text]

    # Merge back false-boundary splits
    merged = []
    i = 0
    while i < len(raw):
        current = raw[i]
        while i + 1 < len(raw):
            match = None
            for m in _FALSE_ENDS.finditer(current):
                match = m
            if match and match.end() >= len(current) - 2:
                current = current + " " + raw[i + 1]
                i += 1
            else:
                break
        merged.append(current)
        i += 1

    # Apply max_chars chunking
    chunks = []
    current = ""
    for sentence in merged:
        if not current:
            current = sentence
        elif len(current) + 1 + len(sentence) <= max_chars:
            current += " " + sentence
        else:
            chunks.append(current)
            current = sentence
    if current:
        chunks.append(current)

    # Split oversized chunks at word boundaries
    result = []
    for chunk in chunks:
        if len(chunk) <= max_chars:
            result.append(chunk)
        else:
            result.extend(_split_at_words(chunk, max_chars))
    return [c for c in result if c.strip()]

def _split_at_words(text: str, max_chars: int) -> list[str]:
    words = text.split()
    parts, current = [], ""
    for word in words:
        if not current:
            current = word
        elif len(current) + 1 + len(word) <= max_chars:
            current += " " + word
        else:
            parts.append(current)
            current = word
    if current:
        parts.append(current)
    return parts
```

## Key Design Decisions

1. Split at natural sentence boundaries (. ! ? + CJK endings)
2. Avoid false splits (decimals, versions, abbreviations, URLs)
3. Merge short sentences into chunks up to max_chars
4. Fall back to word-boundary splitting for oversized chunks
5. max_chars=400 balances latency vs synthesis quality
