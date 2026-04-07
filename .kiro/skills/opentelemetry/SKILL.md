---
name: opentelemetry
description: "Instrument apps with OpenTelemetry for distributed tracing, metrics, and logs. Use when setting up OTel SDK, auto-instrumenting Python/Node.js, configuring Collector pipelines, or choosing sampling."
---

# OpenTelemetry Instrumentation & Observability

Vendor-neutral observability setup: instrument Python/Node.js apps, configure OTel Collector pipelines, choose sampling strategies, and deploy to production.

## Scope

This skill handles:
- Auto + manual instrumentation for Python (FastAPI, Flask, Django) and Node.js (Express, NestJS)
- OTel SDK initialization and configuration
- Semantic conventions and attribute naming
- Context propagation (W3C Trace Context, baggage)
- OTel Collector configuration (receivers, processors, exporters, pipelines)
- Sampling strategies (head-based, tail-based, probabilistic, rate-limiting, composite)
- Collector deployment patterns (agent, gateway, hierarchical, sidecar)
- Docker Compose local dev stack (Collector + Jaeger/Tempo)
- Kubernetes deployment (DaemonSet, Deployment, Helm)
- Trace-metric-log correlation
- Performance optimization (batching, compression, circuit breakers)
- Troubleshooting missing/dropped telemetry

Does NOT handle:
- Vendor-specific backend setup (Datadog agent, New Relic config) → vendor docs
- Go/Java/Rust instrumentation → language-specific OTel docs
- Custom Collector development (building custom receivers/processors) → OTel contrib repo
- eBPF-based auto-instrumentation → specialized tooling
- Error tracking with Sentry (→ power-sentry)
- FastAPI project structure and patterns (→ fastapi-at-scale)
- Docker GPU container setup (→ docker-gpu-setup)

## When to Use

- Adding observability (traces, metrics, logs) to a Python or Node.js service
- Setting up OTel Collector as telemetry pipeline
- Choosing between head-based and tail-based sampling
- Deploying collectors on Kubernetes (DaemonSet vs Gateway)
- Debugging missing traces, silent data drops, or "unknown_service"
- Setting up local dev observability stack (Collector + Jaeger)
- Correlating traces with logs and metrics (RED metrics, service graphs)

## Instrumentation Approach Decision Table

| Scenario | Approach | Key Action |
|---|---|---|
| Quick start, standard frameworks | Auto-instrumentation only | Install OTel packages, zero code changes |
| Need business context on spans | Auto + manual | Auto for infra, manual spans for business logic |
| Custom protocols or libraries | Manual only | Create tracer, start/end spans explicitly |
| Existing Sentry/Datadog, migrating | Auto + bridge exporter | OTel SDK alongside existing agent, gradual migration |

## Sampling Strategy Decision Table

| Goal | Strategy | Where | Config |
|---|---|---|---|
| Simple, low overhead | Head-based probabilistic | SDK | `TraceIdRatioBased(0.1)` = 10% |
| Control volume during spikes | Head-based rate-limiting | SDK | Max N traces/sec |
| Keep 100% errors + slow traces | Tail-based | Collector | `tail_sampling` processor |
| Production at scale | Composite (head + tail) | SDK + Collector | Head filters volume, tail keeps important |

**Rule:** Generate metrics BEFORE sampling → metrics stay accurate even when traces are sampled out.

## Collector Deployment Decision Table

| Environment | Pattern | K8s Resource | When |
|---|---|---|---|
| Local dev | Single collector | Docker Compose | Development, testing |
| Small cluster (<20 services) | Agent only | DaemonSet | Simple setup, node-level collection |
| Medium cluster | Gateway only | Deployment (replicas) | Central aggregation, tail sampling |
| Large cluster (50+ services) | Hierarchical (agent + gateway) | DaemonSet + Deployment | Production recommended |
| Per-app isolation needed | Sidecar | Pod container | Team ownership, strict isolation |

## Quick Start: Python (FastAPI)

```python
# 1. Install
# pip install opentelemetry-distro opentelemetry-exporter-otlp
# opentelemetry-bootstrap -a install

# 2. tracing.py — init BEFORE importing FastAPI
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

resource = Resource.create({"service.name": "my-api", "service.version": "1.0.0"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)

# 3. Instrument FastAPI
from fastapi import FastAPI
app = FastAPI()
FastAPIInstrumentor.instrument_fastapi_instance(app)
```

**Validate:** Send request → check Jaeger UI at `http://localhost:16686` → trace appears with service name.

> For zero-code auto-instrumentation, manual spans, log correlation, and metrics setup, see [Python Instrumentation](references/python-instrumentation.md)

## Quick Start: Node.js (Express)

```javascript
// 1. Install
// npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node
//             @opentelemetry/exporter-trace-otlp-http

// 2. tracing.js — MUST be loaded FIRST via --require
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({ [ATTR_SERVICE_NAME]: 'my-api' }),
  traceExporter: new OTLPTraceExporter(),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();

// 3. Run: node --require ./tracing.js app.js
```

**Validate:** `curl http://localhost:3000/health` → trace appears in Jaeger with correct service name.

> For manual spans, context propagation, metrics, and Express/NestJS patterns, see [Node.js Instrumentation](references/nodejs-instrumentation.md)

## Collector Pipeline Quick Reference

```yaml
# otel-collector-config.yaml — production essentials
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  memory_limiter:          # MUST be FIRST processor
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128
  batch:
    timeout: 5s
    send_batch_size: 8192

exporters:
  otlp:
    endpoint: "tempo:4317"
    tls: { insecure: true }  # local dev only
    sending_queue:
      enabled: true
      queue_size: 5000
    retry_on_failure:
      enabled: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]  # order matters!
      exporters: [otlp]
```

**Validate:** `curl -v http://localhost:4318/v1/traces` returns 200 (empty OK). Collector logs show no errors.

> For full pipeline config, tail sampling, PII redaction, multi-backend routing, see [Collector Configuration](references/collector-configuration.md)

## Top 10 Common Mistakes

| # | Mistake | Impact | Fix |
|---|---------|--------|-----|
| 1 | SDK init AFTER library imports | Spans silently missing | Init OTel FIRST: `--require tracing.js` (Node), top of entry point (Python) |
| 2 | Missing `service.name` | Backend shows "unknown_service" | Set in Resource: `Resource.create({"service.name": "..."})` |
| 3 | Wrong OTLP port | Cryptic protocol errors | 4317 = gRPC, 4318 = HTTP. Match exporter protocol to port |
| 4 | Component defined but not in pipeline | Component silently unused | Every receiver/processor/exporter MUST appear in `service.pipelines` |
| 5 | No `memory_limiter` processor | Collector OOM on traffic spike | Add as FIRST processor in every pipeline |
| 6 | Unclosed spans | Memory leak, spans never exported | Always `span.end()` in finally block or context manager |
| 7 | High-cardinality span names | Backend overwhelmed | Variable data → attributes, not span names. `get_user` not `get_user_123` |
| 8 | Debug exporter in production | Disk full, collector crash | Remove debug exporter. Use OTLP exporter only |
| 9 | No sending queue | Backend outage = data loss | Enable `sending_queue` + `retry_on_failure` on exporters |
| 10 | SimpleSpanProcessor in prod | Blocks app thread on export | Use `BatchSpanProcessor` (default in most SDKs) |

## Troubleshooting

```
Traces not appearing in backend?
├─ Check SDK init order
│   ├─ Node.js: --require tracing.js BEFORE app.js?
│   └─ Python: OTel init before FastAPI/Flask import?
│
├─ Check service.name set?
│   └─ If "unknown_service" → add Resource with service.name
│
├─ Check Collector receiving data?
│   ├─ Collector logs: "Received spans" messages?
│   ├─ Port correct? (4317 gRPC / 4318 HTTP)
│   └─ Firewall/network blocking OTLP port?
│
├─ Check Collector pipeline config?
│   ├─ All components listed in service.pipelines?
│   ├─ Processor order correct? (memory_limiter first)
│   └─ Exporter endpoint reachable from Collector?
│
├─ Spans created but not exported?
│   ├─ span.end() called? (check error paths)
│   ├─ BatchSpanProcessor (not Simple)?
│   └─ Sampler not dropping everything? (check ratio)
│
└─ Collector dropping data?
    ├─ memory_limiter kicking in? → increase limit_mib
    ├─ sending_queue full? → increase queue_size
    └─ Backend slow? → check exporter timeout, enable retry
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Auto-instrumentation covers everything" | Auto covers HTTP/DB/messaging. Business logic needs manual spans. Always combine both. |
| "I'll add tracing later" | OTel SDK init must happen FIRST. Retrofitting is painful — add from day one. |
| "One collector config fits all" | Dev needs debug exporter, prod needs memory_limiter + queue + sampling. Separate configs. |
| "Sample everything at 100%" | At scale, 100% traces = massive storage cost. Use tail sampling to keep errors + slow, sample normal. |
| "Span names should be descriptive with IDs" | High-cardinality names kill backends. Use generic names + attributes for variable data. |
| "Direct-to-backend export is simpler" | Collector provides buffering, retry, sampling, PII redaction. Always use Collector in production. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Setting up FastAPI project structure | fastapi-at-scale | Project patterns, then add OTel instrumentation |
| Need Python project setup (uv, ruff) | python-project-setup | Bootstrap project, add OTel deps |
| Installing OTel Python packages with uv | python-ml-deps | Resolve dependency conflicts |
| Containerizing Collector + app | docker-gpu-setup | Docker Compose, GPU passthrough |
| Error tracking alongside tracing | power-sentry | Sentry SDK coexists with OTel |
| Building audio API that needs tracing | openai-audio-api | Audio API patterns + OTel instrumentation |

## References

- [Python Instrumentation](references/python-instrumentation.md) — Auto/manual instrumentation, FastAPI/Flask/Django, log correlation, metrics
  **Load when:** instrumenting Python services
- [Node.js Instrumentation](references/nodejs-instrumentation.md) — Auto/manual instrumentation, Express/NestJS, context propagation, metrics
  **Load when:** instrumenting Node.js services
- [Collector Configuration](references/collector-configuration.md) — Full pipeline config, processors, tail sampling, PII redaction, multi-backend
  **Load when:** setting up or tuning OTel Collector
- [Sampling Strategies](references/sampling-strategies.md) — Head/tail/composite sampling, cost optimization, metrics-before-sampling
  **Load when:** choosing or configuring sampling
- [Kubernetes Deployment](references/kubernetes-deployment.md) — DaemonSet, Gateway, Helm chart, auto-instrumentation operator
  **Load when:** deploying OTel on Kubernetes
- [Docker Compose Local Dev](references/docker-compose-local-dev.md) — Local stack templates: Collector + Jaeger/Tempo + Prometheus + Grafana
  **Load when:** setting up local observability dev environment
