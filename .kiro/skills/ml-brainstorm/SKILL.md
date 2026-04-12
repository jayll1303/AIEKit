---
name: ml-brainstorm
description: "Brainstorm ML/AI decisions: training strategy, model selection, serving engine, quantization, pipeline architecture. Use when comparing approaches, evaluating tradeoffs, or planning ML workflows"
---

# ML Brainstorm

Brainstorm và tư vấn ML/AI technical decisions trước khi implement. Scan project context, evaluate multiple approaches, recommend best path, và chain trực tiếp đến AIEKit skill workflows.

## Scope

This skill handles:
- ML/AI technical decision brainstorming (training, serving, quantization, pipeline, infra)
- Comparing approaches với pros/cons/tradeoffs dựa trên project context
- Project-aware recommendations qua codebase scanning (deps, imports, Docker, notebooks)
- Generating decision reports với skill chain recommendations trong `./plans/`

Does NOT handle:
- Implementing any solution (→ specific domain skills listed in chain output)
- Installing skills (→ aie-skills-installer)
- Generic non-ML brainstorming (software architecture, UI/UX, business logic)
- Creating new skills (→ skill-creator)

## When to Use

- User cần chọn giữa training approaches (full fine-tune vs LoRA vs QLoRA vs Unsloth)
- User cần chọn serving engine (vLLM vs TGI vs SGLang vs Ollama vs TensorRT)
- User cần chọn quantization method (GGUF vs GPTQ vs AWQ vs bitsandbytes)
- User cần thiết kế ML pipeline (RAG vs fine-tune, batch vs streaming)
- User cần quyết định infrastructure (single vs multi-GPU, Docker vs bare metal)
- User nói "nên dùng gì", "so sánh", "approach nào tốt hơn", "tradeoff"
- Project đang ở giai đoạn early planning, chưa commit vào approach cụ thể

## Decision Domains

| Domain | Typical Questions | Chains To |
|--------|-------------------|-----------|
| Training Strategy | Full fine-tune vs LoRA vs QLoRA? SFT vs DPO vs GRPO? Unsloth hay standard? | hf-transformers-trainer, unsloth-training, experiment-tracking |
| Model Selection | Model size vs VRAM budget? Architecture choice? Pretrained vs from scratch? | hf-hub-datasets |
| Serving Engine | vLLM vs TGI vs SGLang vs Ollama vs TensorRT? Single vs multi-GPU? | vllm-tgi-inference, sglang-serving, ollama-local-llm, tensorrt-llm, triton-deployment, llama-cpp-inference |
| Quantization | GGUF vs GPTQ vs AWQ vs bitsandbytes? Bit level? Quality vs size? | model-quantization |
| Pipeline Architecture | RAG vs fine-tune? Monolith vs microservice? Embedding model choice? | text-embeddings-rag, text-embeddings-inference, fastapi-at-scale |
| Infrastructure | GPU selection? Docker setup? Experiment tracking? CI/CD? | docker-gpu-setup, experiment-tracking, python-ml-deps, opentelemetry |
| Requirements & Goals | Business metrics vs model metrics? Goals hierarchy? Success criteria? Trade-offs? | ref: [mlops-requirements.md](references/mlops-requirements.md) |
| Data Quality & Drift | Data validation strategy? Drift detection? Missing data handling? Outlier treatment? | ref: [mlops-data-quality.md](references/mlops-data-quality.md) |
| Architecture & System Design | Batch vs stream? Monolith vs microservice? Feature store? Lambda vs Kappa? Scalability? | ref: [mlops-architecture.md](references/mlops-architecture.md) |
| Deployment Strategy | Blue-Green vs Canary vs Rolling? Rollback plan? LLMOps? Cost optimization? | ref: [mlops-deployment.md](references/mlops-deployment.md) |
| Fairness & Responsible AI | Bias detection? Fairness metrics? Explainability? Responsible AI compliance? | ref: [mlops-fairness.md](references/mlops-fairness.md) |

## Core Workflow

### Phase 1: Context Gathering

Scan project để hiểu constraints trước khi brainstorm:

1. Read `pyproject.toml`, `requirements*.txt`, `setup.py` — detect ML frameworks đang dùng
2. Scan `Dockerfile*`, `docker-compose*` — detect GPU/serving setup
3. Check `*.ipynb` notebooks — detect experiment patterns
4. Scan code imports — detect models, libraries, patterns đang dùng
5. Check `.kiro/skills/` — biết user đã có skills nào
6. Ask clarifying questions nếu thiếu critical info:
   - GPU hardware + VRAM available
   - Dataset size + format
   - Quality requirements vs speed/cost constraints
   - Production vs research context
   - Business metrics + success criteria (goals hierarchy)
   - Data quality concerns (drift, missing data, freshness)
   - Deployment constraints (latency SLA, rollback requirements, team size)
   - Fairness/compliance requirements (protected groups, regulatory)

**Validate:** Có ít nhất 1 signal (deps, code, hoặc user answer) trước khi sang Phase 2.

### Phase 2: Analysis

1. Map user question → decision domain(s) từ bảng trên
2. Load decision matrices từ [references/decision-matrices.md](references/decision-matrices.md)
3. For MLOps domains (requirements, data quality, architecture, deployment, fairness), load corresponding reference file
4. Evaluate 2-3 viable approaches:
   - Mỗi approach: pros, cons, VRAM estimate, complexity, production-readiness
   - For deployment: include rollback strategy + blast radius analysis
   - For data quality: include validation pyramid level + drift response plan
   - For architecture: include scalability dimension + cost trade-off
   - Dùng VRAM estimator script nếu cần: `python scripts/vram_estimator.py --model-size <B> --method <method>`
5. Web search cho benchmarks/papers mới nếu cần (model comparisons, latest releases)
6. Dùng sequential-thinking cho complex multi-factor analysis

**Validate:** Mỗi approach có ít nhất 1 pro và 1 con. Không recommend approach mà không có evidence.

<HARD-GATE>
Do NOT skip to recommendation without evaluating at least 2 approaches.
Do NOT recommend without checking VRAM constraints against project hardware.
Do NOT implement anything — this skill ONLY brainstorms and advises.
</HARD-GATE>

### Phase 3: Recommendation

Present findings và recommend:

1. Tradeoff matrix (table format)
2. Recommended approach với rationale
3. Skill chain — link trực tiếp đến AIEKit skill + section cụ thể
4. Risks + mitigation

**Skill Chain Output Format:**

```markdown
## Recommended Approach: [tên approach]

[Rationale ngắn gọn]

### Skill Chain — Next Steps

1. **[Step name]** → Activate `skill-name`
   - Section: [tên section trong skill]
   - Key config: [config quan trọng]

2. **[Step name]** → Activate `skill-name`
   - Section: [tên section trong skill]
   - Key config: [config quan trọng]
```

### Phase 4: Report

1. Write markdown report → `./plans/<date>-<topic>/brainstorm-report.md`
2. Report includes: problem statement, approaches evaluated, tradeoff matrix, recommendation, skill chain, risks
3. Ask user: "Muốn tạo implementation plan chi tiết không?"

## Collaboration Tools

| Tool | Khi nào dùng |
|------|-------------|
| Web search | Tìm benchmarks, papers, model comparisons, latest releases |
| Sequential thinking | Complex multi-factor analysis (VRAM + quality + speed + cost) |
| Skill cross-reference | Pull decision tables từ AIEKit skills, link đến workflows |

## Troubleshooting

```
Brainstorm không hiệu quả?
├─ User question quá vague
│   ├─ Ask: "GPU nào? Bao nhiêu VRAM?"
│   ├─ Ask: "Dataset bao lớn? Format gì?"
│   └─ Ask: "Production hay research?"
│
├─ Không đủ context từ project
│   ├─ Scan thêm: README.md, docs/, notebooks
│   ├─ Check git history cho recent changes
│   └─ Ask user trực tiếp về tech stack
│
├─ Decision domain không rõ
│   ├─ Map question → domain table ở trên
│   ├─ Nếu cross-domain → break thành sub-questions
│   └─ Prioritize: infrastructure → training → serving
│
└─ User muốn implement ngay
    ├─ Remind: skill này chỉ brainstorm
    ├─ Point đến skill chain output
    └─ User activate domain skill trực tiếp
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "User hỏi chung chung, recommend hết" | Scan project context trước. Recommend chỉ approaches có signal từ project |
| "Skip analysis, đưa answer luôn" | Brainstorming = process. PHẢI present alternatives + tradeoffs trước khi recommend |
| "Recommend approach mà không link skill" | Mỗi recommendation PHẢI chain đến specific AIEKit skill + section |
| "Tự implement luôn sau khi brainstorm" | Skill này CHỈ brainstorm. Implementation là việc của domain skills |
| "VRAM không quan trọng, recommend approach tốt nhất" | VRAM là constraint #1 trong ML. Luôn check hardware trước khi recommend |
| "Chỉ recommend 1 approach" | Luôn present ≥2 approaches. User cần thấy tradeoffs để quyết định |
| "Model accuracy cao = project thành công" | Model metrics ≠ Business success. Luôn map model → leading indicators → business goals |
| "Data sạch rồi, không cần validate" | Data quality là continuous process. Check 4 pillars + drift detection |
| "Deploy xong là xong" | 70-80% effort là maintenance. Plan rollback, monitoring, retraining triggers |
| "Fairness không quan trọng" | Removing protected attributes ≠ fair. Check proxy features + subpopulation performance |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| User confirm approach, cần install thêm skills | aie-skills-installer | Scan + install skills cần thiết cho chosen approach |
| Brainstorm xong, cần fine-tune model | hf-transformers-trainer | Standard HF Trainer workflows |
| Brainstorm xong, cần fast fine-tune single GPU | unsloth-training | 2x faster, 70% less VRAM |
| Brainstorm xong, cần quantize model | model-quantization | GGUF/GPTQ/AWQ/bitsandbytes workflows |
| Brainstorm xong, cần serve model | vllm-tgi-inference | vLLM/TGI server launch + config |
| Brainstorm xong, cần RAG pipeline | text-embeddings-rag | Embedding + vector DB + retrieval |
| Cần VRAM estimate chi tiết | Run `scripts/vram_estimator.py` | Deterministic VRAM calculation |

## References

- [Decision Matrices](references/decision-matrices.md) — Aggregated decision tables từ all AIEKit skills: training, quantization, serving, RAG vs fine-tune, infrastructure, requirements, data quality, architecture, deployment, fairness
  **Load when:** Brainstorming bất kỳ ML/AI decision nào — file này chứa summary tables + cross-reference links đến full tables trong skill gốc

- [MLOps Requirements](references/mlops-requirements.md) — Goals hierarchy, metrics mapping, error handling strategies, trade-off frameworks, risk analysis (FMEA)
  **Load when:** Defining success metrics, planning error handling, analyzing trade-offs, requirements engineering

- [MLOps Data Quality](references/mlops-data-quality.md) — 4 pillars of data quality, validation pyramid, drift detection (PSI), missing data handling, outlier treatment, model evaluation metrics
  **Load when:** Assessing data quality, choosing model metrics, planning drift response, evaluation strategy

- [MLOps Architecture](references/mlops-architecture.md) — Pipeline patterns (Lambda/Kappa), monolith vs microservice, batch vs stream, feature store, scalability, infrastructure choices
  **Load when:** Designing ML system architecture, choosing pipeline pattern, infrastructure decisions

- [MLOps Deployment](references/mlops-deployment.md) — Blue-Green/Canary/Rolling strategies, serving patterns, rollback, performance optimization, LLMOps, RAG vs fine-tune
  **Load when:** Planning deployment strategy, serving pattern selection, LLM production, cost optimization

- [MLOps Fairness](references/mlops-fairness.md) — Bias types, fairness definitions, explainability techniques (SHAP/LIME), responsible AI checklist, fairness tools
  **Load when:** Evaluating fairness, bias mitigation, model interpretability, responsible AI compliance
