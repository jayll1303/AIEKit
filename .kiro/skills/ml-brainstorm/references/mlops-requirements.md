# MLOps Requirements Engineering & Goals

> Decision tables + frameworks cho requirements engineering, goals hierarchy, error handling, trade-offs trong ML systems.
> **Load when:** Brainstorming requirements, defining success metrics, planning error handling, hoặc analyzing trade-offs.

## 1. Why Requirements Engineering Matters

"ML is Requirements Engineering" — Christian Kästner, CMU

- Model accuracy ≠ Business success
- Technical metrics ≠ User satisfaction
- Lab performance ≠ Production performance
- Among 150 successful ML models at Booking.com, many had high accuracy but did not generate business value (Bernardi et al., KDD 2019)

## 2. ML Systems vs Traditional Software

| Feature | Traditional Software | ML Systems |
|---------|---------------------|------------|
| Reasoning | Specification → Code (deductive) | Data → Model (inductive) |
| Requirements | Precise requirements | No exact spec |
| Behavior | Deterministic | Probabilistic |
| Correctness | Provable correctness | Statistical guarantees |

**Consequences:**
- No single "correct" output
- Mistakes are unavoidable
- Requirements MUST include how to handle failures

## 3. Requirements Decomposition

`REQ = ASM ∧ SPEC`
- Wrong ASM → REQ cannot be achieved even if SPEC is correct

| Component | Description | Example |
|-----------|-------------|---------|
| REQ (Requirement) | Real world goal | Control smarthome using voice |
| ASM (Assumption) | Environment constraint | Microphone captures voice within 3m |
| SPEC | System responsibility | ASR model achieves WER < 5% in standard environment |

## 4. Types of Requirements

### Functional Requirements — What the system should DO
- Predict movie recommendation
- Detect spam emails
- Recognize faces in images

### Non-Functional Requirements — How WELL the system should perform
- Performance: Latency, Throughput
- Scalability: Users, Data volume
- Reliability: Uptime, Accuracy

### ML-Specific Quality Attributes

| Quality Attribute | ML-Specific Concerns |
|-------------------|---------------------|
| Accuracy | Model performance on different subpopulations |
| Fairness | Bias across demographic groups |
| Robustness | Behavior under adversarial inputs, data drift |
| Interpretability | Ability to explain predictions |
| Privacy | Data protection, model inversion attacks |
| Reproducibility | Same data + same code = same model? |

## 5. Key Questions for ML Requirements

### Problem Definition
- What is the actual problem? Is ML necessary?
- How is success defined?

### Data Requirements
- What data is available? Quality?
- Are labels available? Labeling cost?
- Privacy constraints?

### Operational Requirements
- Latency: Real-time vs Batch?
- Throughput requirements?
- Availability SLA?

### Error Handling
- Acceptable error rates?
- Cost of False Positives vs False Negatives?
- Recovery mechanisms when model fails?

## 6. Goals Hierarchy (4 Levels)

```
ORGANIZATIONAL OBJECTIVE (Revenue, Profit)
    └─ LEADING INDICATORS (Engagement, NPS)
        └─ USER OUTCOMES (Task success, UX)
            └─ MODEL PROPERTIES (Accuracy, F1, AUC)
```

| Level | Description | Example (Movie Rec) | Measurement |
|-------|-------------|---------------------|-------------|
| Organizational | Business outcomes | Increase subscription revenue | Revenue per user per month |
| Leading Indicators | Signals of future success | Increase user engagement | Time spent, sessions/week |
| User Outcomes | User achieves their goal | Find movies they want | % users watch recommended movie |
| Model Properties | Technical performance | Predict accurately | NDCG, MAP, Click-through rate |

**Key Insight:** Model has high accuracy but does NOT ensure business success!

### The Disconnect Problem (Booking.com)
"Offline metric improvements showed no correlation with business metric improvements, except where the offline metric is almost exactly the business metric"
- CTR ↑ but Conversion ↓ (Paradox of Choice)
- AUC ↑ but Revenue/Customer unchanged
- RMSE ↓ but User Satisfaction unchanged

## 7. Measuring Goals — 3-Step Method

1. **Measure:** Define WHAT to measure — "User satisfaction with recommendations"
2. **Data:** Define WHERE data comes from — "Post-viewing survey + implicit feedback"
3. **Operationalization:** Define HOW to compute — "% of 5-star ratings in last 30 days"

**Checklist per metric:**
- Reproducible? (Same result each time)
- Actionable? (Can be improved)
- Timely? (Fast enough)

## 8. Precision-Recall Trade-off — Operating Point Selection

| Use Case | Priority | Threshold Strategy |
|----------|----------|-------------------|
| Spam Filter | 99% Precision | Accept lower recall |
| Medical Screening | 99% Recall | Accept lower precision |
| Content Moderation | Balance | Based on cost of each error |

**Decision Framework:**
1. Define cost of FP and FN
2. Estimate base rates
3. Set threshold to minimize expected total cost
4. Monitor and adjust in production

## 9. Planning for Mistakes

### Types of ML Mistakes

| Type | Description | Example |
|------|-------------|---------|
| Random | Scattered across population | 90% accuracy = 1 in 10 wrong |
| Focused | Concentrated in subpopulations | Works for most, fails for specific groups |
| Systematic | Consistent error patterns | Due to training data bias |
| Other | Unpredictable, inexplicable | 99.9% correct, then wildly wrong |

### Error Handling Strategies

| Strategy | Description |
|----------|-------------|
| Guardrails | Hard rules to prevent crazy outputs |
| Fallback | Default safe behavior when uncertain |
| Human in the Loop | Escalate when confidence low |
| Redundancy | Multiple models with voting |
| Graceful Degradation | Reduced functionality > total failure |
| Undo Mechanism | Allow users to reverse actions |

### Forcefulness Spectrum (UX Design)

| Level | Action | Example |
|-------|--------|---------|
| Annotate | Subtle indicator only | Energy warning on watch |
| Prompt | Ask user "Would you like?" | Smart reply options |
| Suggest | Recommend with easy dismiss | "Because you watched..." |
| Auto | Take action silently | Gmail smart compose |
| Enforce | Override user choice | Spam blocking |

Choose based on: confidence level, cost of mistakes, recoverability.

## 10. Trade-offs in ML Systems

### Common Trade-offs
- Accuracy ↔ Latency (better model = more computation)
- Accuracy ↔ Interpretability (complex models harder to explain)
- Accuracy ↔ Fairness (optimizing accuracy may increase bias)
- Privacy ↔ Personalization (better personalization needs more data)
- Precision ↔ Recall (can't maximize both simultaneously)

### Trade-off Decision Framework
1. Identify all relevant quality attributes
2. Prioritize: "Latency < 100ms is MUST, Accuracy > 90% is WANT"
3. Quantify experimentally: "10% accuracy gain costs 50ms latency"
4. Make explicit decisions and document
5. Revisit as requirements evolve

### Latency Impact
- +30% latency → -0.5% conversion rate
- At scale: 0.5% conversion loss = millions in lost revenue

## 11. Risk Analysis Tools

### Fault Tree Analysis
Map top-level failure → root causes:
- System fail → Model fails (data bad, training bug, drift) | Infra fails | Network issue | User error

### FMEA (Failure Mode and Effects Analysis)

| Component | Failure Mode | Effect | Severity | Likelihood | Detection | RPN | Mitigation |
|-----------|-------------|--------|----------|------------|-----------|-----|------------|
| ASR Model | High WER | Wrong command | 7 | 4 | 3 | 84 | Confirmation dialog |
| NLU | Intent misclass | Wrong action | 8 | 3 | 4 | 96 | Undo mechanism |
| Backend | Timeout | No response | 6 | 3 | 2 | 36 | Fallback local |

RPN = Severity × Likelihood × Detection → Focus on highest RPN first.
