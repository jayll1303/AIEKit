# Results Self-Check Protocol

Before reporting or comparing experiment results, verify ALL items. Adapted from harness engineering principles — skipping checks leads to wasted reruns and false conclusions.

<HARD-GATE>
Do NOT present experiment results to user before completing this checklist.
Do NOT claim "training complete" without verifying metrics are logged correctly.
</HARD-GATE>

## Correctness Checks
- [ ] Metrics computed on correct data split (test, not train/val — unless intentional)
- [ ] Baseline numbers compared against match same conditions (dataset version, split, metric variant)
- [ ] Metric variant matches what's expected (e.g., token-level F1 vs answer-level F1, case-sensitive vs insensitive)
- [ ] Multi-seed results reported as mean±std (not cherry-picked best seed)

## Reproducibility Checks
- [ ] All hyperparameters logged (not just final metrics — include lr, batch_size, epochs, seed)
- [ ] Config/TrainingArguments saved as artifact alongside metrics
- [ ] Model checkpoint or adapter saved and linked to the run
- [ ] Environment info logged (GPU type, CUDA version, package versions)

## Consistency Checks
- [ ] No hardcoded hyperparameters in source code that differ from logged params
- [ ] Run name is descriptive and follows naming convention
- [ ] Experiment name groups related runs correctly

## Documentation Checks
- [ ] Run is visible in tracking UI (MLflow/W&B dashboard)
- [ ] Comparison with previous runs uses same metric and conditions
- [ ] Any anomalies or unexpected results noted in run description/tags
