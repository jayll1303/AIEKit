# MLOps Fairness & Responsible AI

> Decision tables + frameworks cho bias detection, fairness definitions, explainability techniques, responsible AI checklist.
> **Load when:** Brainstorming fairness, bias mitigation, model interpretability, hoặc responsible AI compliance.

## 1. Types of ML Bias

| Bias Type | Description | Example |
|-----------|-------------|---------|
| Historical | Training data reflects past discrimination | Hiring data from biased human decisions |
| Representation | Data doesn't represent all populations | Facial recognition trained mostly on light-skinned faces |
| Measurement | Features/labels measured differently across groups | "Quality" defined by majority preferences |
| Aggregation | One-size-fits-all model ignores subgroup differences | Medical model trained on adults used for kids |

## 2. Fairness Definitions (Often Conflicting)

| Definition | Formula | Meaning |
|-----------|---------|---------|
| Demographic Parity | P(Ŷ=1\|A=0) = P(Ŷ=1\|A=1) | Equal positive prediction rates across groups |
| Equalized Odds | P(Ŷ=1\|Y=y,A=0) = P(Ŷ=1\|Y=y,A=1) for y∈{0,1} | Equal TPR and FPR across groups |
| Equal Opportunity | P(Ŷ=1\|Y=1,A=0) = P(Ŷ=1\|Y=1,A=1) | Equal TPR across groups (relaxed equalized odds) |
| Individual Fairness | — | Similar individuals treated similarly |

**Key insight:** These definitions often conflict — you cannot satisfy all simultaneously. Choose based on domain and stakeholder priorities.

## 3. Case Study: Amazon Hiring AI (2014-2017)

**Goal:** Automate resume screening. **Result:** Scrapped after bias found.

### Root Cause
- Trained on 10 years of resume data from tech industry (80% male)
- Model learned to penalize "women's" keywords, downgrade women's colleges, favor "masculine" language
- Gender wasn't a direct feature, but proxy features encoded it

### Lessons
1. **Clean data ≠ Fair data** — data that perfectly represents biased decisions trains a biased model
2. **Removing protected attributes isn't enough** — proxy discrimination through correlated features
3. **Fairness testing is crucial** — test for disparate impact, audit feature importance for proxies
4. **Human oversight required** — AI shouldn't make final high-stakes decisions alone

## 4. Interpretability Spectrum

From high interpretability (glass box) to low (black box):

```
Linear Regression → Decision Tree → Random Forest → Gradient Boosting → Deep Neural Networks
  ↑ Easier to explain                                                    ↑ Often more accurate
  ↑ Regulatory friendly                                                  ↑ Better for complex patterns
  ↑ Debug easily                                                         ↓ "Why?" is hard
```

**Key question:** "Should we use interpretable models instead of trying to explain black boxes after the fact?" — Cynthia Rudin

## 5. Explainability Techniques

### Global Explanations (Model-level)

| Technique | Description |
|-----------|-------------|
| Feature Importance | Which features matter most overall |
| Partial Dependence Plots | How output changes with input |
| Global Surrogate | Train interpretable model to mimic black box |

### Local Explanations (Prediction-level)

| Technique | Description |
|-----------|-------------|
| SHAP Values | Shapley-based feature contributions per prediction |
| LIME | Local Interpretable Model-agnostic Explanations — fits simple model locally |
| Feature Attribution | Prediction = Base + Σ(Feature contributions) |

**Example — Credit Score:**
- Base prediction: 650
- Income effect: +50
- Debt ratio: -30
- Employment: +20
- Age of credit: +10
- Final prediction: 700

## 6. Fairness & Explainability Tools

### Fairness Toolkits

| Tool | Key Features |
|------|-------------|
| IBM AI Fairness 360 | 70+ metrics, bias detection, mitigation algorithms |
| Fairlearn (Microsoft) | Mitigation algorithms, sklearn integration |
| Aequitas (UChicago) | Audit toolkit, bias reports |

### Explainability Tools

| Tool | Key Features |
|------|-------------|
| SHAP | Shapley values, works with any model |
| LIME | Local surrogates, model-agnostic |
| InterpretML | Glass-box models, unified API |

### Monitoring Tools

| Tool | Key Features |
|------|-------------|
| Evidently AI | Data drift + fairness monitoring |
| WhyLabs | ML observability platform |
| Arize | Model performance + fairness tracking |

## 7. Responsible AI Checklist

### Data Collection & Preparation
- [ ] Documented data sources and collection methods
- [ ] Analyzed representation across demographic groups
- [ ] Checked for historical bias in labels
- [ ] Created data documentation (datasheets)

### Model Development
- [ ] Selected appropriate fairness metrics
- [ ] Tested model on diverse subpopulations
- [ ] Evaluated trade-offs between accuracy and fairness
- [ ] Considered inherently interpretable models first

### Deployment
- [ ] Implemented model explanations (SHAP/LIME)
- [ ] Set up fairness monitoring dashboards
- [ ] Established human review for high-stakes decisions
- [ ] Created appeals process for affected individuals

### Monitoring & Maintenance
- [ ] Monitoring fairness metrics in production
- [ ] Tracking drift in protected group outcomes
- [ ] Regular audits by diverse teams
- [ ] Feedback loops with affected communities
