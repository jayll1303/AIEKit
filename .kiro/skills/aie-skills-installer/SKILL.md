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
- User wants to bootstrap ML/AI workflow in a new Kiro workspace
- User says "install skills", "setup ML skills", "bootstrap AI workflow"
- User wants to know which skills are relevant for their project
- User already ran `install.sh` (which installs only 6 core skills by default) and wants project-specific recommendations for additional skills

> **Note:** `install.sh` now installs only the **Core_Set** (6 skills) by default: `aie-skills-installer`, `python-project-setup`, `python-ml-deps`, `hf-hub-datasets`, `docker-gpu-setup`, `notebook-workflows`. Users can expand with `--profile <name>` or `--all`. This smart installer complements the CLI by analyzing the project and recommending specific skills beyond the Core_Set based on concrete signals found in the codebase.

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

For confirmed skills only:

1. Copy skill directories: `<source>/.kiro/skills/<name>/` → `<target>/.kiro/skills/<name>/`
2. Copy relevant steering files (see steering mapping below)
3. Skip hooks unless user explicitly requests them (hooks are repo-specific)
4. Report summary

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

## Steering Mapping

Install steering files based on which skills are selected:

| Steering | Install when skills include |
|----------|-----------------------------|
| `python-project-conventions.md` | python-project-setup, python-quality-testing |
| `ml-training-workflow.md` | hf-transformers-trainer, unsloth-training, k2-training-pipeline, experiment-tracking |
| `inference-deployment.md` | vllm-tgi-inference, sglang-serving, triton-deployment, tensorrt-llm, llama-cpp-inference, ollama-local-llm |
| `gpu-environment.md` | docker-gpu-setup |
| `notebook-conventions.md` | notebook-workflows |
| `kiro-component-creation.md` | Always (if installing any skill) |

## Infrastructure Skills — Auto-include Logic

Some infrastructure skills should be auto-recommended when higher-layer skills are selected:

```
python-ml-deps    → auto-recommend if ANY ML skill is selected
python-project-setup → auto-recommend if target has no pyproject.toml yet
docker-gpu-setup  → auto-recommend if ANY serving skill + Dockerfile present
hf-hub-datasets   → auto-recommend if ANY HF-based skill is selected
```

## Installation Methods

### Method 1: Agent-Driven (preferred in Kiro)

Follow Steps 1-4 above. Copy only confirmed skill directories recursively.

### Method 2: Shell Script

`install.sh` now supports tiered installation:

```bash
# Core only (6 skills — default)
bash install.sh

# Core + specific profile
bash install.sh --profile llm

# Combine profiles
bash install.sh --profile llm,inference

# All 30 skills
bash install.sh --all

# Include Powers (MCP integrations)
bash install.sh -p
```

Available profiles: `llm`, `inference`, `speech`, `cv`, `rag`, `backend`

> **Smart installer vs CLI:** After running `install.sh` (which gives you the core foundation), use this skill in Kiro to get project-specific recommendations for additional skills. The smart installer analyzes your codebase and recommends only skills that have concrete signals, complementing the profile-based CLI approach.

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
