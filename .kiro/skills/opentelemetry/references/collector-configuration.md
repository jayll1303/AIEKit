# OTel Collector Configuration

> Load when: setting up or tuning OTel Collector pipelines

## Architecture

```
App → [Receiver] → [Processor₁ → Processor₂ → ...] → [Exporter] → Backend
```

Every component MUST appear in `service.pipelines` or it's silently ignored.

## Full Production Config Template

```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
  prometheus:
    config:
      scrape_configs:
        - job_name: 'app-metrics'
          scrape_interval: 15s
          static_configs:
            - targets: ['app:8080']

processors:
  # MUST be FIRST — prevents OOM
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  # Enrich/redact attributes
  attributes/add-env:
    actions:
      - key: deployment.environment
        value: production
        action: upsert

  # PII redaction
  attributes/redact:
    actions:
      - key: http.request.header.authorization
        action: delete
      - key: db.query.text
        action: hash

  # Batch before export — reduces network overhead
  batch:
    timeout: 5s
    send_batch_size: 8192
    send_batch_max_size: 16384

  # Tail sampling (stateful — needs gateway deployment)
  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow-traces
        type: latency
        latency: { threshold_ms: 2000 }
      - name: probabilistic-sample
        type: probabilistic
        probabilistic: { sampling_percentage: 10 }

exporters:
  otlp/tempo:
    endpoint: "tempo:4317"
    tls: { insecure: true }
    sending_queue:
      enabled: true
      queue_size: 5000
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

  otlp/metrics:
    endpoint: "prometheus:4317"
    tls: { insecure: true }

  debug:
    verbosity: basic  # REMOVE in production

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  zpages:
    endpoint: 0.0.0.0:55679

service:
  extensions: [health_check, zpages]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, attributes/add-env, attributes/redact, tail_sampling, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch]
      exporters: [otlp/metrics]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, attributes/redact, batch]
      exporters: [otlp/tempo]
```

**Validate:** `curl http://localhost:13133` returns OK (health check). `curl http://localhost:55679/debug/tracez` shows zpages.

## Processor Order Rules

Order in pipeline array = execution order. Critical ordering:

```
memory_limiter → attributes → tail_sampling → batch → exporter
```

| Position | Processor | Why |
|---|---|---|
| FIRST | memory_limiter | Prevent OOM before any processing |
| EARLY | attributes (enrich/redact) | Data available for sampling decisions |
| MIDDLE | tail_sampling | Needs complete traces, before batching |
| LAST | batch | Aggregate before network send |

## Multi-Backend Routing

To send traces to multiple backends:
```yaml
exporters:
  otlp/tempo:
    endpoint: "tempo:4317"
  otlp/datadog:
    endpoint: "datadog-agent:4317"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo, otlp/datadog]  # fan-out to both
```

## Connector: Span Metrics

Generate RED metrics (Rate, Error, Duration) from traces automatically:
```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5ms, 10ms, 25ms, 50ms, 100ms, 500ms, 1s, 5s]
    dimensions:
      - name: http.method
      - name: http.route

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [spanmetrics, otlp/tempo]  # connector as exporter
    metrics/spanmetrics:
      receivers: [spanmetrics]              # connector as receiver
      exporters: [otlp/metrics]
```

## Common Config Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Component not in pipeline | No data flows, no error | Add to `service.pipelines` |
| Wrong port (4317 vs 4318) | Connection refused or protocol error | 4317=gRPC, 4318=HTTP |
| `memory_limiter` not first | OOM on traffic spike | Move to first position |
| `tail_sampling` without enough memory | Traces dropped silently | Increase `num_traces`, add memory |
| Missing `sending_queue` | Data loss on backend outage | Enable queue + retry |
| `debug` exporter in prod | Disk full | Remove or set `verbosity: basic` |
| `tls.insecure: true` in prod | Unencrypted traffic | Configure proper TLS certs |
