# MLOps Architecture & System Design

> Decision tables + patterns cho ML system architecture, pipeline design, data flow, scalability, infrastructure.
> **Load when:** Brainstorming ML system architecture, pipeline patterns, monolith vs microservice, batch vs stream, hoặc infrastructure choices.

## 1. Why Architecture Matters

- 85% of ML projects never reach production
- Architecture issues account for 40% of production failures
- Poorly designed systems cost 10x more to fix later
- ML code is only 5-10% of a production system (Sculley et al., NeurIPS 2015)

## 2. ML System vs Traditional Software

| Feature | Traditional Software | ML Systems |
|---------|---------------------|------------|
| Development | Code → Build → Test → Deploy → Monitor | Data + Code + Model → Build → Test → Deploy → Monitor → Retrain |
| Behavior | Deterministic | Probabilistic |
| Specifications | Clear | Learned |
| Data Dependencies | Minimal | Continuous |

## 3. Components of Production ML System

```
Data Pipeline → Feature Store → Training Pipeline → Model Registry → Serving Infrastructure → Monitoring System
     ↑                                                                                              |
     └──────────────────────── Continuous Feedback & Iteration ─────────────────────────────────────┘
```

## 4. Architectural Quality Attributes ("ilities")

| Attribute | Concerns |
|-----------|----------|
| Performance | Latency, Throughput |
| Reliability | Availability, Fault tolerance |
| Scalability | Horizontal, Vertical, Data scale |
| Maintainability | Modularity, Testability, Debuggability |
| Security | Data privacy, Model security |

**Trade-off triangle:** Cost vs Performance vs Reliability — optimize for 2, rarely all 3.

## 5. ML Pipeline Patterns

### Pipeline Properties
- Reproducibility: Same input → Same output
- Modularity: Independent, replaceable steps
- Observability: Logging and monitoring at each step
- Automation: Triggered by events or schedules

### Pattern 1: Simple Pipeline (Single Model)

```
Data source → Model service → Prediction output
```

| Use When | Avoid When |
|----------|------------|
| Single use case | Multiple models needed |
| Small-medium scale | Complex feature sharing |
| Simple feature engineering | High scalability requirements |
| Fast iteration needed | Real-time feature computation |

### Pattern 2: Feature Store

```
Batch source ──┐                  ┌── Training pipeline
               ├→ Feature Store ──┤
Stream source ─┘   (Offline+Online) └── Inference pipeline
```

**Benefits:** Feature reuse, training-serving consistency, reduced skew, centralized governance.
**Tools:** Feast, Hopsworks, Tecton

### Pattern 3: Lambda Architecture

```
              ┌─ Batch layer (accuracy) ──→ Batch View ─┐
Data source ──┤                                         ├→ Merge → Serving
              └─ Speed layer (low latency) → RT View ───┘
```

**Trade-offs:** High accuracy + low latency, but code duplication, complex maintenance, higher cost.

### Pattern 4: Kappa Architecture

```
Data source → Replayable Event Log (Kafka) → Stream processing → RT View → Serving
```

**Trade-offs:** Simpler than Lambda, single processing path, but limited for complex historical queries.

### Lambda vs Kappa Decision

| Factor | Lambda | Kappa |
|--------|--------|-------|
| Query complexity | Complex aggregations | Simpler queries |
| Data freshness | Eventual consistency OK | Real-time required |
| Team size | Large | Small |
| Development speed | Slower | Faster |
| Cost | Higher | Lower |

**Rule of thumb:** Start with Kappa. Move to Lambda when you need complex historical queries or strict consistency.

## 6. Monolithic vs Microservice

### Monolithic ML

```
Data processing → Feature Engineering → Model training → Model serving → Monitoring → DB
```

| Pros | Cons |
|------|------|
| Simple to develop | Hard to scale independently |
| Easy to test | Single point of failure |
| Low latency (in-process) | Technology lock-in |
| Simple deployment | Long deployment cycle |

### Microservice ML

```
Data service ──┐                    ┌── Data DB
Feature service ├── Message Bus ────┤── Feature DB
Training service┤   (Kafka)         ├── Model DB
Serving service ┘                   └── Metrics DB
         └── All → Monitoring & Observability (Prometheus, Grafana, ELK) ──┘
```

| Pros | Cons |
|------|------|
| Independent scaling | Network latency |
| Technology flexibility | Complex debugging |
| Fault isolation | Data consistency challenges |
| Faster deployments | Operational overhead |

### ML-Specific Microservice Patterns

| Pattern | Description | Use When |
|---------|-------------|----------|
| Model-as-a-Service | Each model in separate service | Independent model lifecycles |
| Gateway + Model Pool | Single entry routes to model pool | Multiple models, unified API |
| Ensemble Service | Combines multiple models | Need aggregated predictions |

### Decision Framework

| Start Monolithic When | Move to Microservices When |
|----------------------|---------------------------|
| Team < 5 engineers | Multiple teams, different models |
| Single use case/model | Different scaling per component |
| Need fast iteration | Independent deployment cycles |
| Low traffic | High availability requirements |
| Unclear requirements | Clear service boundaries |

**Most common: Hybrid** — Monolithic training + Microservice serving + Shared feature store.

## 7. Batch vs Stream Processing

### Batch Processing
- Schedule: Daily/Weekly/Monthly
- Latency: Hours to days
- Volume: TB to PB
- Use cases: Model training, historical features, batch predictions, data quality validation

### Stream Processing
- Latency: Milliseconds to seconds
- Volume: Millions events/sec
- Use cases: Real-time recommendations, fraud detection, live features, model monitoring

### Comparison

| Dimension | Batch | Stream |
|-----------|-------|--------|
| Latency | Hours/Days | ms/seconds |
| Throughput | Very high | High |
| Cost | Lower | Higher |
| Complexity | Easy (reprocess) | Complex (checkpoints) |
| Data completeness | Complete | May miss events |
| State management | Stateless | Stateful |

### Feature Freshness Decision Matrix

| Feature Type | Update Frequency | Use Cases |
|-------------|-----------------|-----------|
| Static | Weekly/Monthly | User demographics, metadata |
| Batch | Hourly/Daily | Watch history, 7-day aggregates |
| Near real-time | Minutes | Recent activity, session context |
| Real-time | Seconds/ms | Current location, device info |

**Key insight:** Match freshness to business value. More fresh = more compute cost. Only pay for freshness you need.

## 8. Scalability

### Scaling Dimensions
- Prediction scale (requests/sec)
- Data scale (TB/PB)
- Model scale (model size/complexity)
- Feature scale (#features × #entities)

### Scaling ML Serving

| Pattern | Description | Use When |
|---------|-------------|----------|
| Replicate servers | Load balancer → multiple identical servers | Standard scaling |
| Model sharding | Split large model across servers | Large embedding tables, LLMs |
| Sharding + Cache | Cache layer before sharded model | Repeated queries, large models |

### Scaling ML Training

| Pattern | Description | Use When |
|---------|-------------|----------|
| Data parallelism | Split data across workers, aggregate gradients | Large datasets |
| Model parallelism | Split model layers across GPUs | Very large models (Transformers, LLMs) |

## 9. Infrastructure Choices

### Cloud vs On-Premise vs Hybrid

| Factor | Cloud | On-Premise | Hybrid |
|--------|-------|-----------|--------|
| Scaling | Elastic | Manual | Combination |
| Cost model | Pay-as-you-go | Predictable | Mixed |
| Control | Less | Full | Balanced |
| Data sovereignty | Depends on region | Full | Managed |
| Best for | General compute | Sensitive data | Training on-prem, serving cloud |

### Edge vs Cloud

| Dimension | Cloud | Edge |
|-----------|-------|------|
| Latency | 50-500ms | <10ms |
| Connectivity | Required | Optional |
| Privacy | Data leaves | Data stays |
| Model size | Any | Constrained |
| Updates | Easy | Complex |

### Infrastructure Decision Tree
1. Strict data sovereignty? → Yes: On-premise/Private cloud
2. Latency < 10ms? → Yes: Edge deployment
3. Otherwise → Cloud (Managed: SageMaker/Vertex AI, or DIY: Kubeflow/MLflow)

## 10. Design Patterns

| Pattern | Description | Tools |
|---------|-------------|-------|
| Model as Service | REST/gRPC API endpoint | FastAPI, TF Serving, BentoML, Seldon |
| Feature Store | Centralized feature management | Feast, Hopsworks, Tecton |
| Model Registry | Version control + lifecycle | MLflow, SageMaker Registry |
| A/B Testing | Route users to model variants | Load balancer + metrics collection |
| Canary Deployment | Gradual rollout (5% → 25% → 50% → 100%) | K8s, Istio |
| Shadow Mode | New model runs parallel, predictions not used | Compare without user impact |

## 11. Case Study Lessons

### Uber Michelangelo
- Centralized Feature Store (Palette) → feature reuse, reduced duplication
- Unified Offline/Online Pipelines → eliminated training-serving skew
- Model Repository with full lineage → reproducibility, debugging, compliance
- Result: Models deployed in hours instead of months, 10x increase in experiments/month

### Spotify Event Delivery
- Event-driven architecture: decouple producers from consumers
- Hybrid batch + stream: match processing to business requirement
- Managed services (Cloud Pub/Sub) over self-managed Kafka
- Data quality at the source: validate early, schema enforcement
- Separate topics per event type for efficient processing
