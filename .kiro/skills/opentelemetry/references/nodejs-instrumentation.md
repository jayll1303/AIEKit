# Node.js OpenTelemetry Instrumentation

> Load when: instrumenting Node.js services (Express, NestJS, Fastify)

## Auto-Instrumentation (Zero-Code)

### Setup

To auto-instrument a Node.js app:
1. Install packages:
   ```bash
   npm install @opentelemetry/sdk-node \
     @opentelemetry/auto-instrumentations-node \
     @opentelemetry/exporter-trace-otlp-http \
     @opentelemetry/exporter-metrics-otlp-http
   ```
2. Create `tracing.js`:
   ```javascript
   const { NodeSDK } = require('@opentelemetry/sdk-node');
   const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
   const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
   const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
   const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
   const { Resource } = require('@opentelemetry/resources');
   const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

   const sdk = new NodeSDK({
     resource: new Resource({
       [ATTR_SERVICE_NAME]: 'my-service',
       [ATTR_SERVICE_VERSION]: '1.0.0',
     }),
     traceExporter: new OTLPTraceExporter({ url: 'http://localhost:4318/v1/traces' }),
     metricReader: new PeriodicExportingMetricReader({
       exporter: new OTLPMetricExporter({ url: 'http://localhost:4318/v1/metrics' }),
     }),
     instrumentations: [getNodeAutoInstrumentations()],
   });
   sdk.start();

   process.on('SIGTERM', () => sdk.shutdown());
   ```
3. Run: `node --require ./tracing.js app.js`

**Validate:** Request to any endpoint → trace appears in Jaeger with service name and HTTP spans.

### What Auto-Instrumentation Covers

| Library | Spans Created |
|---|---|
| express / fastify / koa | HTTP server spans (method, route, status) |
| http / https | Outgoing HTTP client spans |
| pg / mysql2 / mongodb | Database query spans |
| ioredis / redis | Redis command spans |
| amqplib / kafkajs | Messaging spans |
| grpc | gRPC client/server spans |

## Manual Instrumentation

### Custom Spans

To add business logic spans:
```javascript
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('my-service');

async function processOrder(order) {
  return tracer.startActiveSpan('process-order', async (span) => {
    try {
      span.setAttribute('order.id', order.id);
      span.setAttribute('order.total', order.total);
      const result = await executeOrder(order);
      span.setStatus({ code: 1 }); // OK
      return result;
    } catch (err) {
      span.setStatus({ code: 2, message: err.message }); // ERROR
      span.recordException(err);
      throw err;
    } finally {
      span.end(); // MUST call end()
    }
  });
}
```

**Validate:** Custom span appears nested under parent HTTP span in Jaeger.

### Context Propagation

W3C Trace Context propagates automatically for HTTP. For custom propagation:
```javascript
const { context, propagation } = require('@opentelemetry/api');

// Inject into outgoing headers (e.g., message queue)
const headers = {};
propagation.inject(context.active(), headers);
// headers now contains 'traceparent' and 'tracestate'

// Extract from incoming headers
const ctx = propagation.extract(context.active(), incomingHeaders);
context.with(ctx, () => {
  // spans created here are linked to the extracted trace
});
```

## Metrics

To create custom metrics:
```javascript
const { metrics } = require('@opentelemetry/api');
const meter = metrics.getMeter('my-service');

const requestCounter = meter.createCounter('http.requests.total', {
  description: 'Total HTTP requests',
});
const latencyHistogram = meter.createHistogram('http.request.duration', {
  description: 'Request duration in ms',
  unit: 'ms',
});

// In request handler:
requestCounter.add(1, { 'http.method': 'GET', 'http.route': '/api/users' });
latencyHistogram.record(durationMs, { 'http.method': 'GET' });
```

## Log Correlation

To inject trace context into logs (pino example):
```javascript
const { trace } = require('@opentelemetry/api');

function getTraceContext() {
  const span = trace.getActiveSpan();
  if (!span) return {};
  const ctx = span.spanContext();
  return { trace_id: ctx.traceId, span_id: ctx.spanId };
}

// With pino:
const logger = require('pino')();
app.use((req, res, next) => {
  req.log = logger.child(getTraceContext());
  next();
});
```

**Validate:** Log entries contain `trace_id` field → click in Grafana → jumps to trace.

## NestJS-Specific Patterns

For NestJS, auto-instrumentation works out of the box. For custom spans in services:
```typescript
import { trace } from '@opentelemetry/api';

@Injectable()
export class OrderService {
  private tracer = trace.getTracer('order-service');

  async create(dto: CreateOrderDto) {
    return this.tracer.startActiveSpan('OrderService.create', async (span) => {
      try {
        span.setAttribute('order.items_count', dto.items.length);
        // ... business logic
        return result;
      } finally {
        span.end();
      }
    });
  }
}
```

## ESM Support

For ES modules (`"type": "module"` in package.json):
```bash
node --import ./tracing.mjs app.mjs
```

Convert `tracing.js` to use `import` syntax and rename to `tracing.mjs`.
