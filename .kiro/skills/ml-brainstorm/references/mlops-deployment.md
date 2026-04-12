# MLOps Deployment Strategies

> Decision tables + frameworks cho deployment strategies, serving patterns, rollback, performance optimization, LLMOps.
> **Load when:** Brainstorming deployment strategy, serving pattern selection, rollback planning, LLM production, hoặc performance optimization.

## 1. Why Deployment Matters

- 87% of ML projects never reach production
- Model accuracy in lab ≠ performance in production
- Deployment accounts for 70-80% of effort in ML lifecycle
- Deployment is NOT the end — maintenance continues after

## 2. Deployment Strategies

### Strategy Comparison

| Aspect | Blue-Green | Canary | Rolling |
|--------|-----------|--------|---------|
| Rollback speed | Instant | Fast | Slow |
| Resource usage | 2x infrastructure | ~1.1x | 1x |
| User impact | All at once | Gradual, limited | Gradual, mixed |
| Complexity | Simple | Complex | Medium |
| Real user testing | No (pre-switch) | Yes (continuous) | Limited |
| Best for | Critical systems | Large scale, risk-averse | Resource-constrained |

### Blue-Green
- Two identical environments, switch 100% traffic at once
- Pros: Zero downtime, instant rollback, full testing before switch
- Cons: 2x infrastructure, no gradual rollout, higher cost

### Canary — Progressive Rollout
- Phase 1: 5% → Phase 2: 25% → Phase 3: 50% → Phase 4: 100%
- Rollback: any phase → back to 0%
- Pros: Real user validation, limited blast radius, early problem detection
- Cons: Complex orchestration, requires good monitoring, slower full deployment

### Rolling
- Update instances one by one: take out → update → check → add back → repeat
- Pros: No extra infrastructure, zero downtime, resource efficient
- Cons: Slow rollback, mixed versions during rollout, reduced capacity during update

## 3. Model Serving Patterns

| Pattern | Latency | Use Cases |
|---------|---------|-----------|
| Online (REST/gRPC) | 10-50ms | Real-time recommendations, fraud detection, chatbots |
| Batch prediction | Minutes | Daily predictions, reporting, bulk processing |
| Edge deployment | 1-10ms | Mobile apps, IoT, offline capability |

### REST vs gRPC

| Feature | REST | gRPC |
|---------|------|------|
| Protocol | HTTP/1.1 | HTTP/2 |
| Format | JSON | Protocol Buffers |
| Latency overhead | 10-50ms | 2-10ms |
| Advantage | Browser-compatible | Performance, streaming |

### Batch Prediction
- Pre-compute at scale, serve via lookup (<5ms)
- Schedule: nightly, hourly
- When: predictions don't need real-time, large datasets, complex models, cost optimization

### Edge Deployment
- Frameworks: TensorFlow Lite, ONNX Runtime, Core ML, TensorRT
- Benefits: ultra-low latency, works offline, data privacy
- Challenges: model size limits, update distribution, hardware constraints

## 4. Environment Pipeline

```
Development → Staging → Production
```

| Gate | Checks |
|------|--------|
| Dev → Staging | Unit tests pass, code review, lint/security |
| Staging → Prod | Integration tests, performance tests, manual approval |

### Configuration Layers
1. Infrastructure: server address, DB connections
2. Application: log levels, API timeouts, cache TTL
3. Model: model version/path, prediction thresholds, feature flags
4. Secrets: API keys, passwords, encryption keys (special handling)

### Feature Flags
- Enable safe deployment with runtime "kill switches"
- Use cases: gradual rollout, A/B testing, kill switch, beta features

## 5. Rollback Strategies

"Plan for failure from day one" — Hulten

| Scenario | Detection | Response Target |
|----------|-----------|----------------|
| Critical bug / crash | Error rate spike, health checks | < 1 minute |
| Performance degradation | Latency increase, throughput drop | < 5 minutes |
| Model quality drop | Prediction metrics decline | < 30 minutes |
| Business metric impact | Conversion/revenue drop | < 1 hour |

**Best practices:**
- Keep at least 3 previous versions available
- Test rollback procedure regularly
- Automate rollback triggers based on metrics
- Document rollback procedure in runbook
- Rule of thumb: if you can't rollback within 5 minutes, improve your strategy

## 6. Performance Optimization

### Key Metrics

| Metric | Target |
|--------|--------|
| P50 latency | Median response time |
| P95 latency | 95% of requests faster |
| P99 latency | < 200ms |
| CPU utilization | 60-80% |
| Memory | < 80% |
| GPU utilization | > 80% |
| Availability 99.9% | 8.76 hrs downtime/year |
| Availability 99.99% | 52.6 min downtime/year |

### Model Optimization Techniques

| Technique | Description | Benefit |
|-----------|-------------|---------|
| Quantization | FP32→FP16 (2x), FP32→INT8 (4x) | Quality loss typically < 1% |
| Pruning | Remove unnecessary weights | 50-90% sparsity achievable |
| Knowledge Distillation | Train smaller "student" from "teacher" | 10-100x smaller models |
| ONNX/TensorRT | Hardware-optimized inference | 2-5x speedup typical |

### Caching
- Target hit rate: 80-95%
- Cache options: Redis, Memcached
- Invalidate when model updates or data changes
- Hit: <1ms latency, Miss: 50ms+ (run model → store in cache)

### Load Balancing

| Strategy | Best For |
|----------|----------|
| Round robin | Homogeneous servers |
| Least connections | Varying request times (ML) |
| Weighted | Heterogeneous servers |
| Consistent hashing | Caching efficiency |

**Health probes:**
- Liveness: "Is process running?" → restart if fails
- Readiness: "Can it accept traffic?" → remove from LB if fails
- Startup: "Has it initialized?" → wait for slow model loading

## 7. LLMOps — Production LLM Systems

### LLM vs Traditional ML

| Aspect | Traditional ML | LLM Systems |
|--------|---------------|-------------|
| Model size | MB-GB | 10GB-1TB+ |
| Inference time | Milliseconds | Seconds |
| Cost per request | $0.0001 | $0.01-$0.10 |
| Output type | Structured | Free-form text |
| Testing | Unit tests, accuracy | Subjective, hard to measure |
| Failure mode | Wrong prediction | Hallucination (confident lies) |

### LLM Deployment Decision Matrix

| Use Case | API-Based | Self-Hosted | Hybrid |
|----------|-----------|-------------|--------|
| Startup/POC | ⭐⭐⭐ Best | ⭐⭐ | ⭐⭐ |
| Enterprise (sensitive) | ⭐ | ⭐⭐⭐ Best | ⭐⭐⭐ Best |
| High-volume consumer | ⭐ | ⭐⭐⭐ Best | ⭐⭐ |
| Low-latency required | ⭐⭐ | ⭐⭐⭐ Best | ⭐⭐⭐ Best |
| Multi-region global | ⭐⭐⭐ Best | ⭐ | ⭐⭐ |

### LLM Cost Optimization

**Cost reality:** 1M requests/day × 500 tokens avg = ~$15,000/day (GPT-4)

| Strategy | Savings | Description |
|----------|---------|-------------|
| Caching (semantic + exact) | 30-50% | Store similar query responses |
| Model tiering | 60-80% | Simple→GPT-3.5 (20x cheaper), Complex→GPT-4 |
| Prompt optimization | 10-30% | Fewer tokens, concise language, compress context |

### Context Window Management
- Allocation (8K example): System prompt 6% / RAG context 38% / History 25% / Query 6% / Response buffer 25%
- Overflow strategies: summarize history, sliding window, prioritize relevant RAG chunks

### LLM-Specific Monitoring

| Category | Metrics |
|----------|---------|
| Quality | Relevance, coherence, factuality, citation accuracy, user satisfaction |
| Safety | Toxicity score, bias detection, prompt injection, PII leakage |
| Operational | Latency (P50/P95/P99), token usage, cost/request, error rate, cache hit rate |
| Business | Task completion, user engagement, escalation rate, revenue impact |

### Safety Guardrails Architecture

| Layer | Position | Controls |
|-------|----------|----------|
| Input guardrails | Before LLM | Prompt injection detection, topic blocklist, PII detection, rate limiting |
| System guardrails | In LLM | System prompt constraints, constitutional AI principles |
| Output guardrails | After LLM | Toxicity classifier, factuality check, PII redaction, response filtering |

### RAG vs Fine-tuning vs Prompt Engineering

| Aspect | Fine-tuning | Prompt Engineering | RAG |
|--------|------------|-------------------|-----|
| Cost | $$ (GPU, data) | $ (tokens) | $ (embed, vector DB) |
| Update frequency | Days-weeks | Minutes | Real-time |
| Data needs | 1000s+ examples | Few examples | Any docs |
| Best for | Style/tone, domain adapt | Quick experiments | Dynamic, factual data |
| Hallucination risk | Still possible | Moderate | Lowest (grounded) |

**Decision:** Need up-to-date facts → RAG. Need specific style → Fine-tune. Quick iteration → Prompt Engineering. Best results → Combine all three.

## 8. Production Lessons

### Netflix
- System thinking > Model accuracy (0.1% accuracy improvement means nothing if system can't scale)
- $1M winning algorithm was NEVER deployed (800+ models too complex for production)
- Separation of compute-intensive training (AWS) from ultra-low-latency serving (CDN)

### Knight Capital ($440M lost in 45 minutes)
- No deployment procedures → manual process, no peer review
- Silent failure → deployment script failed on 1 of 8 servers
- Dead code not removed → old code activated by reused flag
- No alert system → 97 error emails ignored
- Lessons: automate deployment, remove dead code, automated alerting, kill switches, test in production-like env

### ChatGPT Production
- Streaming is essential (perceived latency 100ms vs actual 5-30s)
- Model tiering saves costs (not every query needs GPT-4)
- Safety is multi-layered (no single solution)
- Freemium drives adoption, API monetization is major revenue
