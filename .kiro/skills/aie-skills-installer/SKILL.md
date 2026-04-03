---
name: aie-skills-installer
description: "Install AIE-Skills (AI/ML Engineering skills, steering, hooks) into any Kiro project. Use when installing, setting up, or copying ML skills to a new project, bootstrapping AI/ML workflow, or sharing skills across repos."
---

# AIE-Skills Installer

Install the AIE-Skills collection (17 ML/AI skills, steering files, hooks) into a target Kiro project.

## Scope

This skill handles: installing/copying AIE-Skills components into target projects.
Does NOT handle: creating new skills (→ skill-creator), editing existing skills, or configuring MCP servers.

## When to Use

- User wants to install AIE-Skills into their project
- User wants to bootstrap ML/AI workflow in a new Kiro workspace
- User wants to share/copy skills to another repo
- User says "install", "setup", "bootstrap", "copy skills"

## Installation Methods

### Method 1: Shell Script (preferred for CLI)

To install via the bundled script:

1. Clone or locate the AIE-Skills repo
2. Run: `bash <path-to-aie-skills>/.kiro/install.sh <target-directory>`
3. For global install: `bash <path-to-aie-skills>/.kiro/install.sh ~`

**Validate:** Target `.kiro/skills/` contains skill directories with `SKILL.md` files.

### Method 2: Agent-Driven Install (preferred when running inside Kiro)

To install as an agent, follow these steps:

#### Step 1: Identify Source and Target

- Source: the AIE-Skills repo `.kiro/` directory
- Target: the user's project root (or `~` for global)
- If source is the current workspace, use relative paths

**Validate:** Source `.kiro/skills/` exists and contains skill directories.

#### Step 2: Create Target Directories

Create these directories if they don't exist:
```
<target>/.kiro/skills/
<target>/.kiro/steering/
<target>/.kiro/hooks/
```

#### Step 3: Copy Components (non-destructive)

For each component type, SKIP if already exists at target:

**Skills** (copy entire directories recursively):
```
.kiro/skills/<skill-name>/  →  <target>/.kiro/skills/<skill-name>/
```
Each skill directory contains: `SKILL.md`, optional `references/`, `scripts/`, `assets/`.

**Steering** (copy .md files):
```
.kiro/steering/*.md  →  <target>/.kiro/steering/
```

**Hooks** (copy .kiro.hook files):
```
.kiro/hooks/*.kiro.hook  →  <target>/.kiro/hooks/
```

**Validate:** Count installed components, report summary.

#### Step 4: Report

Print summary:
```
Installed: X skills, Y steering, Z hooks
Skipped (already exist): A skills, B steering, C hooks
```

## Available Components

### Skills (17)

| Skill | Domain |
|-------|--------|
| arxiv-reader | Paper reading |
| docker-gpu-setup | GPU Docker |
| experiment-tracking | MLflow/W&B |
| freqtrade | Crypto trading |
| hf-hub-datasets | HuggingFace Hub |
| hf-transformers-trainer | LLM fine-tuning |
| k2-training-pipeline | Speech training |
| model-quantization | GGUF/GPTQ/AWQ |
| notebook-workflows | Jupyter/Colab |
| python-ml-deps | ML dependencies |
| python-project-setup | Python bootstrap |
| python-quality-testing | Testing/typing |
| sherpa-onnx | Offline speech |
| text-embeddings-inference | TEI serving |
| text-embeddings-rag | RAG pipelines |
| triton-deployment | Triton server |
| vllm-tgi-inference | LLM serving |

### Steering (2)

- `kiro-component-creation.md` (always) — Rules for creating Kiro components
- `notebook-conventions.md` (fileMatch: `**/*.ipynb`) — Notebook conventions

### Hooks (3)

- `update-readme-index` — Auto-update README on component edit
- `readme-index-on-create` — Auto-update README on component create
- `readme-index-on-delete` — Auto-update README on component delete

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Just copy SKILL.md, skip references/" | Skills need entire directory including references/ for full functionality |
| "Overwrite existing files" | NEVER overwrite — skip if target exists to preserve user customizations |
| "Install hooks by default" | Hooks are repo-specific (README index) — ask user before installing hooks |

## Troubleshooting

```
Install fails?
├─ Permission denied → Check write access to target directory
├─ Skills not showing in Kiro → Restart Kiro or reload window
└─ Steering not loading → Check frontmatter inclusion mode is valid
```
