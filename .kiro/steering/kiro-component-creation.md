---
inclusion: always
---

# Kiro Component Creation Guide

Khi tạo Steering, Skills, Hooks hoặc Powers cho Kiro, PHẢI tuân thủ các quy tắc sau.
Tham khảo chi tiết: #[[file:docs/kiro-compatible.md]]

## Chọn đúng loại component

| Cần gì? | Dùng gì? | Đặt ở đâu? |
|---------|----------|-------------|
| Rule/convention luôn có trong context | **Steering** (`always`) | `.kiro/steering/*.md` |
| Rule chỉ áp dụng cho file cụ thể | **Steering** (`fileMatch`) | `.kiro/steering/*.md` |
| Rule agent tự match theo prompt | **Steering** (`auto`) | `.kiro/steering/*.md` |
| Portable instruction package, share được | **Skill** | `.kiro/skills/<name>/SKILL.md` |
| Automation trigger theo IDE event | **Hook** | `.kiro/hooks/*.kiro.hook` |
| Bundle MCP tools + steering + hooks | **Power** | `POWER.md` + `mcp.json` + `steering/` |

## Steering Rules

- File: `.kiro/steering/<tên-kebab-case>.md`
- YAML frontmatter bắt buộc ở đầu file:

```yaml
---
inclusion: always | fileMatch | manual | auto
# fileMatchPattern: ["**/*.ts"]    # chỉ khi fileMatch
# name: tên-steering               # chỉ khi manual/auto
# description: mô tả ngắn          # chỉ khi auto
---
```

- Một file = một domain (api, testing, security...)
- Dùng natural language + code examples
- Có thể reference file: `#[[file:path/to/file]]`
- KHÔNG chứa secret/API key

## Skill Rules

- Cấu trúc thư mục:

```
.kiro/skills/<skill-name>/
├── SKILL.md          # bắt buộc
├── references/       # optional - docs chi tiết
├── scripts/          # optional - executable scripts
└── assets/           # optional - templates
```

- SKILL.md frontmatter bắt buộc:

```yaml
---
name: skill-name              # lowercase, hyphen, max 64 ký tự
description: Mô tả rõ ràng chứa keyword developer hay dùng. Use when...
license: MIT                  # optional
---
```

- Description phải chứa keyword rõ ràng + pattern "Use when..."
- SKILL.md ngắn gọn, chi tiết đặt trong `references/`
- Workspace scope cho project-specific, global cho personal workflow

## Hook Rules

- File: `.kiro/hooks/<tên-hook>.kiro.hook` (JSON)
- Schema bắt buộc:

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

- `patterns` chỉ dùng cho file events (fileEdited, fileCreated, fileDeleted)
- `toolTypes` chỉ dùng cho preToolUse/postToolUse. Valid categories: read, write, shell, web, spec, *
- Ưu tiên tạo qua Kiro UI (Agent Hooks panel) khi có thể

## Power Rules (advanced)

- Cấu trúc:

```
power-<name>/
├── POWER.md
├── mcp.json
└── steering/
    └── workflow-*.md
```

- POWER.md frontmatter: name, displayName, description, keywords (array)
- keywords phải chứa từ khóa domain để Kiro auto-match

## Skill Interconnection Requirements

Khi tạo hoặc sửa skill, PHẢI maintain interconnection map.
Tham khảo: #[[file:docs/skill-interconnection-map.md]]

1. **Scope boundary**: Mỗi skill PHẢI có "Does NOT handle:" với `→ skill-name` syntax
2. **Layer assignment**: Xác định skill thuộc layer nào (Application / Workflow / Serving / Infrastructure)
3. **Dependency matrix**: Update matrix trong interconnection map khi thêm skill mới
4. **Workflow chains**: Nếu skill tham gia pipeline phổ biến, thêm vào workflow chains
5. **Reverse update**: Khi thêm skill mới, check xem skills hiện tại có cần update scope boundary không

## Steering Domain Rules

Mỗi steering file = một domain. Không overlap.
Tham khảo: #[[file:docs/skill-creation-best-practices.md]]

Steering hiện có:
- `kiro-component-creation.md` (always) — Quy tắc tạo components
- `notebook-conventions.md` (fileMatch: *.ipynb) — Notebook editing
- `ml-training-workflow.md` (auto) — Training/fine-tuning conventions
- `inference-deployment.md` (auto) — Serving/deployment conventions
- `gpu-environment.md` (fileMatch: Dockerfile*, docker-compose*) — GPU container conventions
- `python-project-conventions.md` (auto) — Python project setup, uv, ruff, pytest

Khi tạo steering mới: check danh sách trên để tránh overlap domain.

## Checklist trước khi hoàn thành

- [ ] Đúng thư mục scope (workspace `.kiro/` vs global `~/.kiro/`)
- [ ] Frontmatter hợp lệ (đúng fields cho từng loại)
- [ ] Không chứa secret/API key
- [ ] Tên file kebab-case
- [ ] Với Hooks: event type và action type khớp nhau
- [ ] Với Skills: description chứa keyword + "Use when..." + scope boundary
- [ ] Với Skills: Update `docs/skill-interconnection-map.md` nếu thêm skill mới
- [ ] Với Steering: Không overlap domain với steering hiện có
- [ ] Với Powers: kiểm tra mcp.json env vars
