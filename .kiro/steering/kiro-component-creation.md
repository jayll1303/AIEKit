---
inclusion: always
description: Rules for creating Kiro components (Steering, Skills, Hooks, Powers). Always in context to ensure compliance with structure and conventions.
---

# Kiro Component Creation Guide

When creating Steering, Skills, Hooks, or Powers for Kiro, you MUST follow these rules.
See details: #[[file:docs/kiro-compatible.md]]

## Choose the Right Component Type

| Need | Use | Location |
|------|-----|----------|
| Rule/convention always in context | **Steering** (`always`) | `.kiro/steering/*.md` |
| Rule only applies to specific files | **Steering** (`fileMatch`) | `.kiro/steering/*.md` |
| Rule agent auto-matches by prompt | **Steering** (`auto`) | `.kiro/steering/*.md` |
| Portable instruction package, shareable | **Skill** | `.kiro/skills/<name>/SKILL.md` |
| Automation trigger on IDE event | **Hook** | `.kiro/hooks/*.kiro.hook` |
| Bundle MCP tools + steering + hooks | **Power** | `POWER.md` + `mcp.json` + `steering/` |

## Steering Rules

- File: `.kiro/steering/<kebab-case-name>.md`
- YAML frontmatter required at file start:

```yaml
---
inclusion: always | fileMatch | manual | auto
# fileMatchPattern: ["**/*.ts"]    # only for fileMatch
# name: steering-name              # only for manual/auto
# description: short description   # only for auto
---
```

- One file = one domain (api, testing, security...)
- Use natural language + code examples
- Can reference files: `#[[file:path/to/file]]`
- Do NOT include secrets/API keys

## Skill Rules

- Directory structure:

```
.kiro/skills/<skill-name>/
├── SKILL.md          # required
├── references/       # optional - detailed docs
├── scripts/          # optional - executable scripts
└── assets/           # optional - templates
```

- SKILL.md frontmatter required:

```yaml
---
name: skill-name              # lowercase, hyphen, max 64 chars
description: Clear description with keywords developers commonly use. Use when...
license: MIT                  # optional
---
```

- Description must contain clear keywords + "Use when..." pattern
- Keep SKILL.md concise; put details in `references/`
- Workspace scope for project-specific, global for personal workflow

## Hook Rules

- File: `.kiro/hooks/<hook-name>.kiro.hook` (JSON)
- Required schema:

```json
{
  "name": "string (required)",
  "version": "string (required)",
  "description": "string (optional)",
  "when": {
    "type": "fileEdited | fileCreated | fileDeleted | userTriggered | promptSubmit | agentStop | preToolUse | postToolUse | preTaskExecution | postTaskExecution",
    "patterns": ["*.ts"],
    "toolTypes": ["write"]
  },
  "then": {
    "type": "askAgent | runCommand",
    "prompt": "string (for askAgent)",
    "command": "string (for runCommand)"
  }
}
```

- `patterns` only for file events (fileEdited, fileCreated, fileDeleted)
- `toolTypes` only for preToolUse/postToolUse. Valid categories: read, write, shell, web, spec, *
- Prefer creating via Kiro UI (Agent Hooks panel) when possible

## Power Rules (advanced)

### Two Types of Powers

| Type | Has mcp.json? | When to use |
|------|--------------|-------------|
| **Guided MCP Power** | Yes | Document MCP server + workflows |
| **Knowledge Base Power** | No | Pure docs: CLI guide, best practices, troubleshooting |

### Directory Structure

```
power-<name>/                    # or <name>/ — "power-" prefix optional
├── POWER.md                     # required
├── mcp.json                     # only for Guided MCP Power
└── steering/                    # optional, only when >500 lines or independent workflows
    └── workflow-*.md
```

### POWER.md Frontmatter

Only 5 valid fields — do NOT use version, tags, repository, license:

```yaml
---
name: "power-name"              # required, kebab-case, NO "power-" prefix
displayName: "Human Readable"   # required, Title Case
description: "Max 3 sentences." # required, concise
keywords: ["specific", "terms"] # optional, 5-7 keywords, avoid overly generic terms
author: "Author Name"           # optional but recommended
---
```

### Naming Convention

- Default: `{tool-name}` (e.g., `huggingface`, `terraform`)
- Only split when workflows are completely independent: `{tool-name}-{workflow}` (e.g., `supabase-local-dev`)
- Kebab-case name, no `power-` prefix in the `name` field

### Keyword Rules

- 5-7 domain-specific keywords
- AVOID overly generic keywords: "test", "debug", "data", "api", "help" → cause false activation
- Prefer specific terms: "postgresql" over "database", "huggingface" over "model"

### When to Create steering/ Directory

- POWER.md > 500 lines
- Has independent workflows users don't need loaded simultaneously
- Default: keep everything in POWER.md, only split when truly needed

### Steering Files in Powers

- Do NOT need frontmatter (unlike `.kiro/steering/` files)
- Loaded on-demand via `readSteering` action, not auto-inclusion
- Use descriptive names: `workflow-model-discovery.md`, `troubleshooting.md`

### mcp.json Rules

- Contains only MCP server config, NOT metadata (metadata goes in POWER.md frontmatter)
- `autoApprove`: only list read-only/safe tools
- `disabledTools`: only disable when user explicitly agrees
- Env vars use `${VAR_NAME}` syntax for sharing

### MCP Config Placeholders (for sharing)

If mcp.json has user-specific values (API keys, paths), you MUST:
1. Replace with placeholder: `YOUR_API_KEY_HERE`, `PLACEHOLDER_PATH`
2. Add "MCP Config Placeholders" section in POWER.md explaining how to get each value
3. Each placeholder needs: name, description, specific instructions on how to obtain it

### Granularity — When to Split Powers

Default: do NOT split. Keep as a single power.

Only split when ALL conditions are true:
1. Workflows are completely independent, never used together
2. Different environments (local vs remote, dev vs prod)
3. User only needs 1 workflow at a time
4. Strong conviction that splitting improves usability

### POWER.md Recommended Sections

1. Overview — what the power does, why it's useful
2. Onboarding — prerequisites, installation, setup
3. Available Tools — list tools with short descriptions (Guided MCP)
4. Common Workflows — step-by-step for main use cases
5. Connected Skills — table linking to related skills
6. MCP Config Placeholders — placeholder replacement guide (if applicable)
7. Troubleshooting — common errors + solutions
8. Anti-Patterns — what NOT to do

## Skill Interconnection Requirements

When creating or editing a skill, you MUST maintain the interconnection map.
See: #[[file:docs/skill-interconnection-map.md]]

1. **Scope boundary**: Every skill MUST have "Does NOT handle:" with `→ skill-name` syntax
2. **Layer assignment**: Determine which layer the skill belongs to (Application / Workflow / Serving / Infrastructure)
3. **Dependency matrix**: Update matrix in interconnection map when adding a new skill
4. **Workflow chains**: If skill participates in a common pipeline, add to workflow chains
5. **Reverse update**: When adding a new skill, check if existing skills need their scope boundaries updated

## Steering Domain Rules

One steering file = one domain. No overlap.
See: #[[file:docs/skill-creation-best-practices.md]]

Existing steering files:
- `kiro-component-creation.md` (always) — Component creation rules
- `notebook-conventions.md` (fileMatch: *.ipynb) — Notebook editing
- `ml-training-workflow.md` (auto) — Training/fine-tuning conventions
- `inference-deployment.md` (auto) — Serving/deployment conventions
- `gpu-environment.md` (fileMatch: Dockerfile*, docker-compose*) — GPU container conventions
- `python-project-conventions.md` (auto) — Python project setup, uv, ruff, pytest

When creating new steering: check the list above to avoid domain overlap.

## Checklist Before Completion

- [ ] Correct directory scope (workspace `.kiro/` vs global `~/.kiro/`)
- [ ] Valid frontmatter (correct fields for each type)
- [ ] No secrets/API keys
- [ ] Filename in kebab-case
- [ ] For Hooks: event type and action type match
- [ ] For Skills: description contains keywords + "Use when..." + scope boundary
- [ ] For Skills: Update `docs/skill-interconnection-map.md` if adding new skill
- [ ] For Steering: No domain overlap with existing steering
- [ ] For Powers: only use 5 valid frontmatter fields (name, displayName, description, keywords, author)
- [ ] For Powers: description max 3 sentences, specific keywords (not overly generic)
- [ ] For Powers: steering files in powers do NOT have frontmatter
- [ ] For Powers: mcp.json contains only server config, no metadata
- [ ] For Powers: has MCP Config Placeholders section if mcp.json has user-specific values
- [ ] For Powers: autoApprove only lists safe/read-only tools
