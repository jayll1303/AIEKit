# Sampling Strategies

> Load when: choosing or configuring sampling for OTel traces

## Why Sample?

At scale, 100% trace collection = massive storage + processing cost. Sampling reduces volume while keeping important traces (errors, slow requests).

**Critical rule:** Generate metrics BEFORE sampling. Metrics must reflect 100% of traffic, not just sampled traces.

## Strategy Comparison

| Strategy | Decision Point | Stateful? | Keeps Errors? | Overhead | Best For |
|---|---|---|---|---|---|
| Head probabilistic | Trace start | No | Random | Very low | Dev, low-traffic |
| Head rate-limiting | Trace start | No | Random | Low | Traffic spike control |
| Tail-based | After trace complete | Yes | Yes (100%) | Medium-high | Production, error-sensitive |
| Composite | Both | Partial | Yes | Medium | Large-scale production |

## Head-Based Sampling (SDK-side)

### Probabilistic

Samples a fixed percentage of traces. Simple, stateless, low overhead.

Python:
```python
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

sampler = TraceIdRatioBased(0.1)  # 10% of traces
provider = TracerProvider(sampler=sampler, resource=resource)
```

Node.js:
```javascript
const { TraceIdRatioBasedSampler } = require('@opentelemetry/sdk-trace-base');

const sdk = new NodeSDK({
  sampler: new TraceIdRatioBasedSampler(0.1), // 10%
  // ...
});
```

**Validate:** Send 100 requests → ~10 traces appear in backend.

### Rate-Limiting

Caps traces per second. Useful during traffic spikes.

Python:
```python
from opentelemetry.sdk.trace.sampling import RateLimitingSampler

sampler = RateLimitingSampler(max_traces_per_second=100)
```

### Parent-Based (Default)

Respects parent span's sampling decision. Root spans use inner sampler.

```python
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

sampler = ParentBased(root=TraceIdRatioBased(0.1))
# If parent is sampled → child is sampled
# If no parent → use TraceIdRatioBased(0.1)
```

## Tail-Based Sampling (Collector-side)

Collector buffers complete traces, then decides. Keeps 100% of errors and slow traces.

**Requirement:** Collector must run as Gateway (Deployment), not Agent (DaemonSet). Needs memory for buffering.

```yaml
# In collector config
processors:
  tail_sampling:
    decision_wait: 10s          # wait for trace to complete
    num_traces: 100000          # max traces in memory
    policies:
      # Keep ALL errors
      - name: errors-policy
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Keep ALL slow traces (>2s)
      - name: latency-policy
        type: latency
        latency:
          threshold_ms: 2000

      # Sample 10% of remaining normal traces
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

      # Always keep specific operations
      - name: critical-operations
        type: string_attribute
        string_attribute:
          key: http.route
          values: ["/api/payments", "/api/auth"]
```

**Validate:** Send mix of normal + error requests → ALL errors appear in backend, ~10% of normal traces.

### Memory Sizing for Tail Sampling

```
Memory needed ≈ num_traces × avg_spans_per_trace × avg_span_size
Example: 100,000 traces × 10 spans × 1KB = ~1GB buffer
```

Set `memory_limiter` accordingly:
```yaml
processors:
  memory_limiter:
    limit_mib: 2048        # 2GB total
    spike_limit_mib: 512
  tail_sampling:
    num_traces: 100000
```

## Composite Strategy (Production Recommended)

Combine head + tail for cost-effective production sampling:

```
SDK (head): ParentBased(TraceIdRatioBased(0.5))  → 50% pass through
Collector (tail): Keep errors + slow from that 50% → final ~5-15% stored
```

This gives:
- 50% reduction at source (less network, less collector load)
- 100% error/slow retention from the 50% that passes
- ~5-15% total storage vs 100% collection

## Metrics Before Sampling

**Critical:** Span metrics connector MUST be placed BEFORE tail_sampling in pipeline:

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [spanmetrics, otlp/tempo]  # spanmetrics BEFORE backend
    traces/sampled:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters: [otlp/tempo]
```

This ensures metrics reflect 100% of traffic even when traces are sampled.

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| 100% sampling in production | Storage cost explodes | Use tail sampling, keep errors + slow |
| Tail sampling on DaemonSet | Traces split across nodes | Use Gateway deployment for tail sampling |
| Sampling before metrics | Metrics inaccurate | Generate metrics first, then sample |
| Same ratio for all services | Critical services under-sampled | Per-service sampling policies |
| No `decision_wait` tuning | Incomplete traces sampled wrong | Set to max expected trace duration |
