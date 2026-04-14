# Route Optimization Guide

Optimize route matching accuracy and performance.

## When to Load

Load when: routes not matching correctly, tuning thresholds, or designing utterances.

## Utterance Design Principles

### Quantity

| Route Complexity | Recommended Utterances |
|------------------|------------------------|
| Simple intent | 5-7 |
| Complex/nuanced | 10-15 |
| Overlapping domains | 15-20 |

### Diversity

Cover semantic variations, not just paraphrases:

```python
# ❌ Bad - too similar
weather_route = Route(
    name="weather",
    utterances=[
        "what's the weather?",
        "what is the weather?",
        "tell me the weather",
        "show me the weather",
    ],
)

# ✅ Good - diverse semantic coverage
weather_route = Route(
    name="weather",
    utterances=[
        "what's the weather like today?",
        "is it going to rain?",
        "should I bring an umbrella?",
        "how hot is it outside?",
        "will it snow tomorrow?",
        "what's the forecast for this weekend?",
        "is it sunny in Paris?",
    ],
)
```

### Edge Cases

Include boundary cases to improve precision:

```python
politics_route = Route(
    name="politics",
    utterances=[
        # Core political topics
        "what do you think about the president?",
        "tell me about the election",
        # Edge cases that SHOULD match
        "government policy on healthcare",
        "congressional voting records",
        # Negative examples (add to different route or leave unmatched)
    ],
)
```

## Score Threshold Tuning

### Understanding Thresholds

- Higher threshold = more strict matching (fewer false positives)
- Lower threshold = more lenient matching (fewer false negatives)

```python
# Check similarity scores
results = sr.retrieve_multiple_routes("test query")
for r in results:
    print(f"{r.name}: {r.similarity_score}")
```

### Setting Custom Thresholds

```python
# Per-route threshold
route = Route(
    name="sensitive_topic",
    utterances=["..."],
    score_threshold=0.85,  # Higher = more strict
)

# Global threshold via encoder
encoder = OpenAIEncoder(score_threshold=0.7)
```

### Threshold Guidelines

| Use Case | Recommended Threshold |
|----------|----------------------|
| General chatbot | 0.7-0.75 |
| Guardrails (block topics) | 0.8-0.85 |
| Function calling | 0.75-0.8 |
| High-precision classification | 0.85-0.9 |

## Handling Overlapping Routes

When routes have semantic overlap:

### Option 1: Merge Routes

```python
# Instead of separate routes
greetings = Route(name="greetings", utterances=["hello", "hi"])
farewells = Route(name="farewells", utterances=["goodbye", "bye"])

# Merge into one
social = Route(
    name="social",
    utterances=["hello", "hi", "goodbye", "bye", "how are you"],
)
```

### Option 2: Use retrieve_multiple_routes

```python
results = sr.retrieve_multiple_routes(query)
if len(results) > 1 and results[0].similarity_score - results[1].similarity_score < 0.05:
    # Ambiguous - handle specially
    print("Multiple routes matched closely")
```

### Option 3: Add Discriminating Utterances

```python
# Add utterances that clearly distinguish routes
tech_support = Route(
    name="tech_support",
    utterances=[
        "my computer won't start",
        "how do I reset my password",
        "the app is crashing",
        # Discriminating: clearly NOT sales
        "I need help fixing this bug",
        "technical issue with my account",
    ],
)

sales = Route(
    name="sales",
    utterances=[
        "I want to buy a subscription",
        "what are your pricing plans",
        "can I get a discount",
        # Discriminating: clearly NOT support
        "I'm interested in purchasing",
        "how much does it cost",
    ],
)
```

## Testing Routes

### Manual Testing

```python
test_cases = [
    ("what's the weather?", "weather"),
    ("hello there", "chitchat"),
    ("random unrelated query", None),
]

for query, expected in test_cases:
    result = sr(query)
    status = "✓" if result.name == expected else "✗"
    print(f"{status} '{query}' → {result.name} (expected: {expected})")
```

### Batch Evaluation

```python
def evaluate_routes(sr, test_cases):
    correct = 0
    for query, expected in test_cases:
        result = sr(query)
        if result.name == expected:
            correct += 1
        else:
            print(f"FAIL: '{query}' → {result.name} (expected: {expected})")
    
    accuracy = correct / len(test_cases)
    print(f"\nAccuracy: {accuracy:.2%}")
    return accuracy
```

## Route Layer Optimization

### Reduce Latency

1. Use FastEmbedEncoder for fastest local inference
2. Limit utterances to essential examples
3. Use LocalIndex for development

### Improve Accuracy

1. Add more diverse utterances
2. Tune score_threshold per route
3. Use HybridRouter for keyword + semantic matching

### Production Checklist

- [ ] Test with real user queries (not just designed examples)
- [ ] Verify edge cases and boundary conditions
- [ ] Set appropriate thresholds per route
- [ ] Use persistent index (Pinecone/Qdrant) for reliability
- [ ] Monitor unmatched queries (None results) for new route opportunities
- [ ] Regularly update utterances based on actual usage patterns

## Debugging Low Scores

```python
# Get detailed scores for debugging
results = sr.retrieve_multiple_routes(query)

if not results:
    print("No routes matched - query too different from all utterances")
elif results[0].similarity_score < 0.5:
    print(f"Low confidence match: {results[0].similarity_score}")
    print("Consider adding similar utterances to the route")
```

## Common Pitfalls

| Problem | Solution |
|---------|----------|
| Route never matches | Add more diverse utterances, lower threshold |
| Wrong route matches | Add discriminating utterances, raise threshold |
| Multiple routes match equally | Merge routes or add distinguishing examples |
| Slow routing | Use FastEmbed, reduce utterance count |
| Inconsistent results | Use deterministic encoder settings |
