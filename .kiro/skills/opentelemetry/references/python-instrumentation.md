# Python Instrumentation

## Zero-Code Auto-Instrumentation

Fastest path — no code changes required:

```bash
# Install
pip install opentelemetry-distro opentelemetry-exporter-otlp

# Auto-detect installed libraries and install matching instrumentors
opentelemetry-bootstrap -a install

# Run with auto-instrumentation
opentelemetry-instrument \
  --service_name my-api \
  --exporter_otlp_endpoint http://localhost:4317 \
  --exporter_otlp_protocol grpc \
  uvicorn src.main:app --host 0.0.0.0 --port 8000
```

Auto-instrumented libraries: FastAPI, Flask, Django, requests, httpx, aiohttp, SQLAlchemy, psycopg2, asyncpg, redis, celery, grpc, boto3, and more.

**Validate:** Send request → Jaeger shows spans for HTTP handler + DB queries + external calls.

## Programmatic SDK Setup (More Control)

```python
# src/telemetry.py — import this FIRST in main.py
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

def init_telemetry(service_name: str, otlp_endpoint: str = "http://localhost:4317"):
    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.0.0",
        "deployment.environment": "production",
    })

    # Traces
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint))
    )
    trace.set_tracer_provider(tracer_provider)

    # Metrics
    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=otlp_endpoint),
        export_interval_millis=60000,
    )
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
```

## FastAPI Integration

```python
# src/main.py
from src.telemetry import init_telemetry
init_telemetry("my-api")  # MUST be before FastAPI import if using auto-instrumentation

from fastapi import FastAPI, Request
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry import trace

app = FastAPI()
FastAPIInstrumentor.instrument_fastapi_instance(app)

tracer = trace.get_tracer(__name__)

@app.post("/orders")
async def create_order(request: Request):
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.type", "standard")
        order = await process_order()
        span.set_attribute("order.id", order.id)
        span.add_event("order_created", {"order.total": order.total})
        return {"order_id": order.id}
```

## Manual Spans — Best Practices

```python
tracer = trace.get_tracer(__name__)

# Pattern 1: Context manager (preferred)
async def process_payment(order_id: str, amount: float):
    with tracer.start_as_current_span("process_payment") as span:
        span.set_attribute("payment.order_id", order_id)
        span.set_attribute("payment.amount", amount)
        try:
            result = await payment_gateway.charge(amount)
            span.set_attribute("payment.status", "success")
            return result
        except PaymentError as e:
            span.set_status(trace.StatusCode.ERROR, str(e))
            span.record_exception(e)
            raise

# Pattern 2: Explicit start/end (when context manager doesn't fit)
async def batch_process(items: list):
    span = tracer.start_span("batch_process")
    span.set_attribute("batch.size", len(items))
    try:
        for item in items:
            await process_item(item)
    except Exception as e:
        span.set_status(trace.StatusCode.ERROR, str(e))
        span.record_exception(e)
        raise
    finally:
        span.end()  # ALWAYS end in finally
```

## Log Correlation

Inject trace_id and span_id into logs for trace-log navigation:

```python
import logging
from opentelemetry import trace

class OTelLogHandler(logging.Handler):
    def emit(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            record.trace_id = format(ctx.trace_id, '032x')
            record.span_id = format(ctx.span_id, '016x')

# With structlog
import structlog

def add_otel_context(logger, method_name, event_dict):
    span = trace.get_current_span()
    ctx = span.get_span_context()
    if ctx.is_valid:
        event_dict["trace_id"] = format(ctx.trace_id, '032x')
        event_dict["span_id"] = format(ctx.span_id, '016x')
    return event_dict

structlog.configure(processors=[add_otel_context, structlog.dev.ConsoleRenderer()])
```

**Validate:** Log output contains `trace_id` field. Click trace_id in Jaeger → see correlated logs.

## Custom Metrics

```python
from opentelemetry import metrics

meter = metrics.get_meter(__name__)

# Counter
request_counter = meter.create_counter(
    "app.requests.total",
    description="Total requests processed",
)

# Histogram
latency_histogram = meter.create_histogram(
    "app.request.duration",
    unit="ms",
    description="Request processing duration",
)

# Usage in endpoint
@app.post("/orders")
async def create_order():
    request_counter.add(1, {"endpoint": "/orders", "method": "POST"})
    start = time.time()
    result = await process()
    latency_histogram.record((time.time() - start) * 1000, {"endpoint": "/orders"})
    return result
```

## Semantic Conventions for Python

```python
from opentelemetry.semconv.trace import SpanAttributes
from opentelemetry.semconv.resource import ResourceAttributes

# Resource attributes
Resource.create({
    ResourceAttributes.SERVICE_NAME: "order-service",
    ResourceAttributes.SERVICE_VERSION: "2.1.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
})

# Span attributes — use semconv constants
span.set_attribute(SpanAttributes.HTTP_REQUEST_METHOD, "POST")
span.set_attribute(SpanAttributes.HTTP_RESPONSE_STATUS_CODE, 200)
span.set_attribute(SpanAttributes.DB_SYSTEM, "postgresql")

# Custom attributes — use app. prefix
span.set_attribute("app.order.id", order_id)
span.set_attribute("app.payment.method", "credit_card")
```

## Flask / Django Quick Setup

```python
# Flask
from opentelemetry.instrumentation.flask import FlaskInstrumentor
FlaskInstrumentor().instrument_app(app)

# Django — add to settings.py INSTALLED_APPS or use auto-instrumentation
# opentelemetry-instrument --service_name my-django python manage.py runserver
```

## Graceful Shutdown

```python
from opentelemetry.sdk.trace import TracerProvider

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    # Flush pending spans before shutdown
    provider = trace.get_tracer_provider()
    if isinstance(provider, TracerProvider):
        provider.shutdown()
```
