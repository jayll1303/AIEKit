# Docker Compose Local Dev Stack

> Load when: setting up local observability dev environment

## Quick Start Stack (Collector + Jaeger)

Minimal setup for local development — traces only.

```yaml
# docker-compose-otel.yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    ports:
      - "4317:4317"   # gRPC receiver
      - "4318:4318"   # HTTP receiver
      - "13133:13133" # health check
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # Jaeger UI
      - "4317"         # internal OTLP (collector → jaeger)
    environment:
      - COLLECTOR_OTLP_ENABLED=true
```

Collector config for this stack:
```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  batch:
    timeout: 1s

exporters:
  otlp/jaeger:
    endpoint: "jaeger:4317"
    tls: { insecure: true }
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger, debug]
```

To start:
```bash
docker compose -f docker-compose-otel.yaml up -d
```

**Validate:**
1. `curl http://localhost:13133` → collector health OK
2. `curl http://localhost:16686` → Jaeger UI loads
3. Send a traced request → trace appears in Jaeger UI

## Full Stack (Collector + Tempo + Prometheus + Grafana)

Production-like setup with metrics, traces, and dashboards.

```yaml
# docker-compose-otel-full.yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    ports:
      - "4317:4317"
      - "4318:4318"
      - "13133:13133"
      - "8889:8889"   # Prometheus metrics from collector
    volumes:
      - ./otel-collector-config-full.yaml:/etc/otelcol-contrib/config.yaml

  tempo:
    image: grafana/tempo:latest
    command: ["-config.file=/etc/tempo.yaml"]
    ports:
      - "3200:3200"   # Tempo API
    volumes:
      - ./tempo-config.yaml:/etc/tempo.yaml

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yaml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
```

Tempo config:
```yaml
# tempo-config.yaml
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc: { endpoint: 0.0.0.0:4317 }
storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
```

Prometheus config:
```yaml
# prometheus.yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']
```

Grafana datasources:
```yaml
# grafana-datasources.yaml
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    url: http://tempo:3200
    isDefault: true
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
```

Full collector config:
```yaml
# otel-collector-config-full.yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5ms, 10ms, 50ms, 100ms, 500ms, 1s]

processors:
  memory_limiter:
    limit_mib: 256
  batch:
    timeout: 1s

exporters:
  otlp/tempo:
    endpoint: "tempo:4317"
    tls: { insecure: true }
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [spanmetrics, otlp/tempo]
    metrics:
      receivers: [spanmetrics]
      processors: [batch]
      exporters: [prometheus]
```

To start:
```bash
docker compose -f docker-compose-otel-full.yaml up -d
```

**Validate:**
1. Jaeger/Tempo: traces visible at `http://localhost:3000` (Grafana → Explore → Tempo)
2. Prometheus: `http://localhost:9090` → query `duration_milliseconds_bucket`
3. Grafana: `http://localhost:3000` → both datasources connected

## App Configuration

Point your app's OTLP exporter to the collector:

| Setting | Value |
|---|---|
| OTLP gRPC endpoint | `http://localhost:4317` |
| OTLP HTTP endpoint | `http://localhost:4318/v1/traces` |
| Env var (standard) | `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317` |

Or set via environment variables (works with auto-instrumentation):
```bash
export OTEL_SERVICE_NAME=my-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
```
