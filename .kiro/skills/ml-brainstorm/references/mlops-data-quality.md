# MLOps Data Quality & Model Quality

> Decision tables + frameworks cho data quality assessment, validation, drift detection, model evaluation, subpopulation analysis.
> **Load when:** Brainstorming data quality, model metrics selection, drift response, hoặc evaluation strategy.

## 1. The Data Quality Crisis

- 92% of AI practitioners reported data quality issues causing project delays
- Data Scientists spend 80% of time on data preparation, only 20% on modeling
- Poor data → Flawed labels → Model errors → System failure (compounding effect)

## 2. Four Pillars of Data Quality

| Pillar | Question | Key Concerns |
|--------|----------|-------------|
| Accuracy | Is the data correct? | Random errors (typos, noise) vs Systematic errors (sensor drift, biased sampling) |
| Completeness | Is all required data there? | MCAR (safe to ignore) vs MAR (use observed to impute) vs MNAR (most dangerous) |
| Consistency | Is the data uniform? | Format, semantic, cross-source inconsistencies |
| Timeliness | Is the data fresh? | Match freshness to business requirements |

### Completeness Thresholds
- Critical features: > 99% required
- Important features: > 90% recommended
- Nice-to-have: > 70% acceptable

### Timeliness Spectrum

| Category | Latency | Use Case |
|----------|---------|----------|
| Real-time | < 1 sec | Fraud detection |
| Near real-time | < 1 min | Recommendations |
| Batch | < 24 h | Report generation |
| Stable | > 24 h | Archive analysis |

## 3. Data Validation Pyramid

```
Level 3: Semantic rules (business rules, cross-field validation)
Level 2: Statistical checks (distributions, ranges, patterns)
Level 1: Schema validation (types, nullability, constraints)
```

### Level 1: Schema Validation
- Column existence, data types, nullability, range constraints
- Tools: Great Expectations, Pandera

### Level 2: Statistical Validation
- KS Test for distribution shift (continuous)
- Chi-square Test for categorical distributions
- Z-score / IQR for outlier detection

### Level 3: Semantic Business Rules
- Cross-field: IF user_age < 18 THEN adult_content_allowed = False
- Temporal: registration_date <= first_rating_date
- Referential integrity: all foreign keys valid

## 4. Handling Missing Data

| Strategy | When to Use |
|----------|-------------|
| Deletion (listwise/pairwise) | MCAR, low missing rate. Caution: reduces sample size |
| Imputation (mean/median/KNN/model) | MAR, moderate missing rate |
| Indicator variable | Missingness is informative (add "is_missing" feature) |
| Special value encoding | Domain-specific placeholders (-999, "UNKNOWN") |

### Decision Tree
1. Is missingness informative? → Yes: Create indicator variable
2. Is missing rate low? → Yes: Delete rows
3. Is relationship complex? → Yes: ML-based imputation → No: Simple imputation

## 5. Outlier Treatment

| Strategy | When to Use |
|----------|-------------|
| Keep | Genuine rare events, valid extreme values |
| Remove | Data entry errors, equipment malfunction |
| Cap/Winsorize | Reduce influence, preserve row count |
| Transform | Skewed distributions, scale compression |
| Separate model | Different populations, domain-specific behavior |

**Detection methods:**
- Z-score: outlier if |z| > 3
- IQR: outlier if x < Q1 - 1.5×IQR or x > Q3 + 1.5×IQR

## 6. Data Drift Detection

### Types of Drift

| Type | Definition | Example |
|------|-----------|---------|
| Covariate drift | P(X) changes | User demographics shift over time |
| Concept drift | P(Y\|X) changes | What makes a movie "popular" changes |
| Label drift | P(Y) changes | Rating distribution shifts |

### Detection Methods
- KS Test — continuous features
- Chi-Square Test — categorical features
- Population Stability Index (PSI): `PSI = Σ (actual% - expected%) × ln(actual%/expected%)`

### PSI Interpretation & Response

| PSI | Severity | Action |
|-----|----------|--------|
| < 0.1 | Low | Log and monitor, no immediate action |
| 0.1–0.2 | Medium | Alert team, analyze impact, schedule retraining if degradation |
| > 0.2 | High | Immediate investigation, consider fallback model, trigger retraining |
| > 0.5 | Critical | Activate circuit breaker, switch to rule-based fallback, incident response |

## 7. Model Quality Metrics

### Classification

| Metric | Formula | When to Use |
|--------|---------|-------------|
| Precision | TP/(TP+FP) | FP is costly (spam filter, recommendations) |
| Recall | TP/(TP+FN) | FN is costly (medical diagnosis, fraud detection) |
| F1 | 2×P×R/(P+R) | Balanced need |
| Fβ | ((1+β²)×P×R)/(β²×P+R) | β<1: precision-heavy, β>1: recall-heavy |
| AUC-ROC | Area under ROC curve | Overall ranking quality |

### Regression

| Metric | Characteristic |
|--------|---------------|
| MAE | Robust to outliers, same units as target |
| MSE/RMSE | Penalizes large errors, sensitive to outliers |
| R² | Scale-independent (0 to 1), explained variance |

### Ranking (Recommendation Systems)

| Metric | Description |
|--------|-------------|
| Precision@K | Relevant items in top K / K |
| Recall@K | Relevant items in top K / total relevant |
| MAP | Average precision at each relevant position |
| NDCG | Normalized discounted cumulative gain (position-weighted) |

### Metric Selection Guide

| Problem Type | Data Balanced? | Outliers Matter? | Recommended |
|-------------|---------------|-----------------|-------------|
| Classification | Yes | — | Accuracy, F1 |
| Classification | No | — | AUC, F1 |
| Regression | — | Yes | MAE |
| Regression | — | No | RMSE, R² |
| Ranking | — | — | NDCG, MAP |

## 8. Model Evaluation Best Practices

- **Data splitting:** Train 60% / Val 20% / Test 20%
- **Avoid leakage:** Split BEFORE preprocessing. Time-based splits for temporal data
- **Stratified sampling:** Maintain class distribution across splits
- **Cross-validation:** K-fold for small datasets, time-series CV for temporal
- **Baseline comparison:** Always compare against random, majority class, simple heuristics

## 9. Subpopulation Analysis

Overall accuracy can hide critical failures in subgroups:

| Subgroup | Samples | Accuracy | Status |
|----------|---------|----------|--------|
| Age 18-34 | 5000 | 95% | Good |
| Age 35-54 | 3000 | 93% | Good |
| Age 55+ | 1500 | 85% | Warning |
| Age < 18 | 500 | 72% | Critical |

**Key insight:** "A system that never works for people under 5 feet tall is fundamentally broken" — Hulten

Always test across subpopulations, not just overall metrics.
