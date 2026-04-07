# Kubernetes OTel Collector Deployment

> Load when: deploying OTel Collector on Kubernetes

## Deployment Pattern Decision

| Pattern | K8s Resource | When to Use |
|---|---|---|
| Agent | DaemonSet | Node-level metrics, log collection, local batching |
| Gateway | Deployment (replicas) | Central aggregation, tail sampling, multi-backend |
| Sidecar | Pod container | Per-app isolation, team ownership |
| Hierarchical | DaemonSet + Deployment | Production recommended (agent + gateway) |

## Agent Mode (DaemonSet)

One collector per node. Collects node metrics, receives app telemetry, batches locally.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector-agent
  namespace: observability
spec:
  selector:
    matchLabels:
      app: otel-collector-agent
  template:
    metadata:
      labels:
        app: otel-collector-agent
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:latest
          ports:
            - containerPort: 4317  # gRPC
            - containerPort: 4318  # HTTP
          volumeMounts:
            - name: config
              mountPath: /etc/otelcol-contrib/config.yaml
              subPath: config.yaml
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: config
          configMap:
            name: otel-agent-config
```

Agent config — forward to gateway:
```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  memory_limiter:
    limit_mib: 256
    spike_limit_mib: 64
  batch:
    timeout: 5s
    send_batch_size: 4096

exporters:
  otlp:
    endpoint: "otel-collector-gateway.observability:4317"
    tls: { insecure: true }

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

**Validate:** `kubectl logs -l app=otel-collector-agent -n observability` shows "Everything is ready" and "Received spans".

## Gateway Mode (Deployment)

Central collector with replicas. Handles tail sampling, multi-backend routing.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  replicas: 2
  selector:
    matchLabels:
      app: otel-collector-gateway
  template:
    metadata:
      labels:
        app: otel-collector-gateway
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:latest
          ports:
            - containerPort: 4317
          volumeMounts:
            - name: config
              mountPath: /etc/otelcol-contrib/config.yaml
              subPath: config.yaml
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 4Gi
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  selector:
    app: otel-collector-gateway
  ports:
    - port: 4317
      targetPort: 4317
      name: grpc
```

**Validate:** `kubectl get pods -l app=otel-collector-gateway -n observability` shows 2/2 Running.

## Hierarchical Pattern (Production Recommended)

```
Apps → Agent (DaemonSet) → Gateway (Deployment) → Backend
         local batch          tail sampling
         low latency          central aggregation
```

Deploy both Agent DaemonSet + Gateway Deployment. Agent forwards to Gateway service.

## Helm Chart (OpenTelemetry Operator)

To install via Helm:
```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Install Collector
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace observability --create-namespace \
  --set mode=daemonset \
  --set config.receivers.otlp.protocols.grpc.endpoint="0.0.0.0:4317" \
  -f values.yaml
```

## Auto-Instrumentation Operator

The OTel Operator can auto-inject instrumentation into pods via annotations:

```bash
# Install operator
helm install otel-operator open-telemetry/opentelemetry-operator \
  --namespace observability
```

Create Instrumentation resource:
```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
  namespace: default
spec:
  exporter:
    endpoint: http://otel-collector-agent.observability:4318
  propagators:
    - tracecontext
    - baggage
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
```

Annotate pods for auto-injection:
```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
    # or: instrumentation.opentelemetry.io/inject-nodejs: "true"
```

**Validate:** Pod restarts with init container injecting OTel SDK. Traces appear without code changes.

## Resource Sizing Guide

| Role | CPU Request | Memory Request | Memory Limit |
|---|---|---|---|
| Agent (DaemonSet) | 200m | 256Mi | 512Mi |
| Gateway (no tail sampling) | 500m | 512Mi | 2Gi |
| Gateway (with tail sampling) | 1000m | 2Gi | 4Gi |

Scale gateway replicas based on throughput. Monitor collector metrics for queue saturation.
