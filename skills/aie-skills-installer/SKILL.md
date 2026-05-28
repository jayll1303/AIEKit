---
name: aie-skills-installer
description: "Analyze project and recommend relevant AIE-Skills. Use when installing, setting up ML skills, bootstrapping AI/ML workflow, or sharing skills across repos."
---

# AIE-Skills Smart Installer

Analyze a target project's codebase to recommend and install only the relevant AIE-Skills, avoiding unnecessary context bloat.

## Scope

This skill handles: analyzing target projects, recommending relevant skills, selective installation.
Does NOT handle: creating new skills (→ skill-creator), editing existing skills, configuring MCP servers.

## When to Use

- User wants to install AIE-Skills into their project
- User wants to bootstrap ML/AI workflow in a new workspace
- User says "install skills", "setup ML skills", "bootstrap AI workflow"
- User wants to know which skills are relevant for their project

## Core Workflow

### Step 1: Analyze Target Project

Scan the target project to build a technology profile:

1. Read `README.md`, `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements*.txt`, `Pipfile`, `environment.yml`
2. Scan for `Dockerfile*`, `docker-compose*`, `.dockerignore`
3. Check for `*.ipynb` notebooks
4. Scan `src/` or main code directories for import patterns
5. Check for existing `.kiro/skills/` (avoid duplicates)

**Validate:** Have at least 1 signal (deps file, code files, or README) to base recommendations on.

### Step 2: Match Skills by Signals

Use the detection table below to map project signals → recommended skills.

**Validate:** Each recommendation has at least 1 concrete signal from the project.

### Step 3: Present Recommendations

Present findings as:

```
## Project Analysis

Tech signals detected:
- [list concrete signals: deps, imports, files found]

## Recommended Skills (N)

| Skill | Why | Signals |
|-------|-----|---------|
| skill-name | reason | concrete evidence |

## Optional Skills (M)
(skills that MIGHT be useful but no strong signal)

## Not Recommended (K)
(skills with zero signals — do NOT install)
```

**Validate:** User confirms which skills to install before proceeding.

<HARD-GATE>
Do NOT install all skills by default.
Do NOT install without presenting recommendations first.
ALWAYS wait for user confirmation before installing.
</HARD-GATE>

### Step 4: Selective Install

For confirmed skills, use `npx skills add`:

```bash
# Install specific skills
npx skills add jayll1303/AIEKit --skill <skill1> --skill <skill2>

# Install all skills from repo
npx skills add jayll1303/AIEKit --all

# Install globally
npx skills add jayll1303/AIEKit --skill <skill1> -g
```

**Validate:** Only confirmed skills are installed. No extras.

## Skill Detection Table

| Skill | Detect by (any match) |
|-------|----------------------|
| python-project-setup | `pyproject.toml`, `setup.py`, `uv.lock`, any Python project |
| python-ml-deps | `torch`, `tensorflow`, `jax` in deps; CUDA references |
| python-quality-testing | `pytest`, `hypothesis`, `mypy`, `ruff` in deps/config |
| docker-gpu-setup | `Dockerfile*` + GPU/CUDA references; `nvidia` in docker-compose |
| hf-hub-datasets | `transformers`, `datasets`, `huggingface_hub` in deps/imports |
| hf-transformers-trainer | `Trainer`, `TrainingArguments`, `SFTTrainer`, `trl` in deps/imports |
| unsloth-training | `unsloth` in deps/imports |
| model-quantization | `bitsandbytes`, `auto_gptq`, `autoawq`, `llama.cpp` refs, GGUF mentions |
| vllm-tgi-inference | `vllm` in deps; `text-generation-inference` in Docker |
| sglang-serving | `sglang` in deps/imports |
| llama-cpp-inference | `llama-cpp-python`, `llama.cpp` refs, GGUF files |
| ollama-local-llm | `ollama` in deps/scripts/docs; Modelfile present |
| tensorrt-llm | `tensorrt_llm`, `trtllm` in deps/imports/scripts |
| triton-deployment | `tritonclient`, `model_repository/`, `config.pbtxt` |
| text-embeddings-inference | `tei`, embedding server refs in Docker/scripts |
| text-embeddings-rag | `faiss`, `chromadb`, `qdrant`, `sentence-transformers` in deps |
| experiment-tracking | `mlflow`, `wandb`, `tensorboard` in deps/imports |
| notebook-workflows | `*.ipynb` files present |
| ultralytics-yolo | `ultralytics` in deps; `yolo` in imports/scripts |
| k2-training-pipeline | `k2`, `icefall`, `lhotse` in deps/imports |
| sherpa-onnx | `sherpa-onnx`, `sherpa_onnx` in deps/imports |
| paddleocr | `paddleocr`, `paddlepaddle` in deps/imports |
| freqtrade | `freqtrade` in deps; `IStrategy` in code |
| arxiv-reader | arxiv URLs in docs/code; research paper workflow |
| ml-brainstorm | Multiple competing approaches detected (e.g., both vLLM and TGI refs, both LoRA and full fine-tune code); early planning stage; user asks "nên dùng gì" or "compare approaches" |

## Infrastructure Skills — Auto-include Logic

Some infrastructure skills should be auto-recommended when higher-layer skills are selected:

```
python-ml-deps    → auto-recommend if ANY ML skill is selected
python-project-setup → auto-recommend if target has no pyproject.toml yet
docker-gpu-setup  → auto-recommend if ANY serving skill + Dockerfile present
hf-hub-datasets   → auto-recommend if ANY HF-based skill is selected
```

## Installation Methods

### Method 1: Agent-Driven via npx skills (preferred)

Follow Steps 1-3 above, then execute:

```bash
# Install specific skills
npx skills add jayll1303/AIEKit --skill ultralytics-yolo --skill paddleocr

# Install all
npx skills add jayll1303/AIEKit --all

# Install globally (across all projects)
npx skills add jayll1303/AIEKit --skill ultralytics-yolo -g
```

The agent should:
1. Analyze project (Steps 1-3)
2. Get user confirmation
3. Run `npx skills add jayll1303/AIEKit --skill <skill1> --skill <skill2>`
4. Verify skills are installed in `.kiro/skills/` (or agent-specific directory)

### Method 2: User CLI

```bash
# Install all skills
npx skills add jayll1303/AIEKit

# Install specific skills
npx skills add jayll1303/AIEKit --skill ultralytics-yolo --skill paddleocr

# List available skills
npx skills add jayll1303/AIEKit --list

# Install globally
npx skills add jayll1303/AIEKit -g
```

> **Smart installer vs CLI:** Use this skill in your agent to get project-specific recommendations. The smart installer analyzes your codebase and recommends only skills that have concrete signals.

## Power Detection Table

Powers are optional MCP integrations. Only recommend when strong signals exist AND user confirms.

| Power | Detect by | Prerequisites |
|-------|-----------|---------------|
| power-huggingface | `transformers`, `datasets`, `huggingface_hub` in deps; HF model refs in code | HF_TOKEN env var or HF CLI login |
| power-gpu-monitor | NVIDIA GPU present; CUDA refs in deps/Docker; ML training/serving skills selected | Python + mcp-system-monitor installed |
| power-sentry | `sentry-sdk`, `@sentry/node`, `@sentry/react` in deps; Sentry DSN in env/config | Node.js 18+ for npx; Sentry account |

### Power Install Workflow

1. After skill recommendations, present powers separately:
   ```
   ## Optional Powers (MCP Integrations)
   
   Powers provide external tool access but require auth setup.
   MCP servers are disabled by default — enable after configuring credentials.
   
   | Power | Why | Setup needed |
   |-------|-----|-------------|
   | power-name | signal found | what user needs to do |
   ```
2. Wait for explicit user confirmation
3. Copy power directory to `<target>/.kiro/powers/<power-name>/`
4. Powers ship with `"disabled": true` in mcp.json — remind user to:
   - Configure credentials (API key, login, etc.)
   - Set `"disabled": false` in mcp.json when ready

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Install everything to be safe" | Wastes context window. Only install what project needs. |
| "Skip analysis, just ask user" | User may not know all 25 skills. Analysis provides informed recommendations. |
| "No Python deps found, skip all" | Check README, code files, Docker — deps file isn't the only signal. |
| "Install hooks too" | Hooks are repo-specific (README indexing). Ask first. |
| "Install powers by default" | Powers require MCP auth/API keys. Only install when user explicitly confirms and understands setup. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to brainstorm which ML approach before choosing skills | ml-brainstorm | ML decision-making helps pick the right skill chain |
| After installing, need to set up Python project structure | python-project-setup | Bootstrap pyproject.toml, ruff, pytest |
| After installing, need to resolve CUDA/PyTorch deps | python-ml-deps | Handles uv pip install with CUDA version resolution |

## Troubleshooting

```
No signals detected?
├─ Empty/new project → Ask user about planned tech stack, recommend starter set
├─ Non-Python project → Most AIE-Skills are Python-focused, inform user
└─ Monorepo → Analyze each sub-project separately

Skills not showing after install?
├─ Reload Kiro window
├─ Check .kiro/skills/<name>/SKILL.md exists
└─ Check frontmatter is valid YAML
```
