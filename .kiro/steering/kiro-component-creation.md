---
inclusion: always
description: Quy tắc tạo Kiro components (Steering, Skills, Hooks, Powers). Luôn có trong context để đảm bảo tuân thủ cấu trúc và conventions.
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

### Hai loại Power

| Loại | Có mcp.json? | Khi nào dùng |
|------|-------------|--------------|
| **Guided MCP Power** | ✅ Có | Document MCP server + workflows |
| **Knowledge Base Power** | ❌ Không | Pure docs: CLI guide, best practices, troubleshooting |

### Cấu trúc thư mục

```
power-<name>/                    # hoặc <name>/ — prefix "power-" optional
├── POWER.md                     # bắt buộc
├── mcp.json                     # chỉ cho Guided MCP Power
└── steering/                    # optional, chỉ khi >500 lines hoặc workflows độc lập
    └── workflow-*.md
```

### POWER.md Frontmatter

Chỉ có 5 fields hợp lệ — KHÔNG dùng version, tags, repository, license:

```yaml
---
name: "power-name"              # required, kebab-case, KHÔNG prefix "power-"
displayName: "Human Readable"   # required, Title Case
description: "Max 3 câu."       # required, ngắn gọn
keywords: ["specific", "terms"] # optional, 5-7 keywords, tránh từ quá chung
author: "Author Name"           # optional nhưng recommended
---
```

### Naming Convention

- Default: `{tool-name}` (e.g., `huggingface`, `terraform`)
- Chỉ split khi workflows hoàn toàn độc lập: `{tool-name}-{workflow}` (e.g., `supabase-local-dev`)
- Tên kebab-case, không prefix `power-` trong field `name`

### Keyword Rules

- 5-7 keywords specific cho domain
- TRÁNH keywords quá chung: "test", "debug", "data", "api", "help" → gây false activation
- Ưu tiên từ khóa cụ thể: "postgresql" thay vì "database", "huggingface" thay vì "model"

### Khi nào tạo steering/ directory

- POWER.md > 500 lines
- Có workflows độc lập mà user không cần load cùng lúc
- Mặc định: giữ mọi thứ trong POWER.md, chỉ split khi thực sự cần

### Steering files trong Power

- KHÔNG cần frontmatter (khác với `.kiro/steering/` files)
- Được load on-demand qua `readSteering` action, không phải auto-inclusion
- Đặt tên mô tả: `workflow-model-discovery.md`, `troubleshooting.md`

### mcp.json Rules

- Chỉ chứa MCP server config, KHÔNG chứa metadata (metadata ở POWER.md frontmatter)
- `autoApprove`: chỉ list read-only/safe tools
- `disabledTools`: chỉ disable khi user đồng ý explicitly
- Env vars dùng `${VAR_NAME}` syntax cho sharing

### MCP Config Placeholders (cho sharing)

Nếu mcp.json có giá trị user-specific (API keys, paths), PHẢI:
1. Thay bằng placeholder: `YOUR_API_KEY_HERE`, `PLACEHOLDER_PATH`
2. Thêm section "MCP Config Placeholders" trong POWER.md giải thích cách lấy từng giá trị
3. Mỗi placeholder cần: tên, mô tả, hướng dẫn cụ thể cách lấy

### Granularity — Khi nào split Power

Mặc định: KHÔNG split. Giữ single power.

Chỉ split khi TẤT CẢ điều kiện đúng:
1. Workflows hoàn toàn độc lập, không bao giờ dùng cùng nhau
2. Khác environment (local vs remote, dev vs prod)
3. User chỉ cần 1 workflow tại 1 thời điểm
4. Có strong conviction rằng split cải thiện usability

### POWER.md Recommended Sections

1. Overview — power làm gì, tại sao hữu ích
2. Onboarding — prerequisites, installation, setup
3. Available Tools — list tools với mô tả ngắn (Guided MCP)
4. Common Workflows — step-by-step cho use cases chính
5. Connected Skills — bảng liên kết sang skills liên quan
6. MCP Config Placeholders — hướng dẫn thay placeholder (nếu có)
7. Troubleshooting — common errors + solutions
8. Anti-Patterns — những gì KHÔNG nên làm

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
- [ ] Với Powers: chỉ dùng 5 frontmatter fields hợp lệ (name, displayName, description, keywords, author)
- [ ] Với Powers: description max 3 câu, keywords specific (không quá chung)
- [ ] Với Powers: steering files trong power KHÔNG có frontmatter
- [ ] Với Powers: mcp.json chỉ chứa server config, không metadata
- [ ] Với Powers: có MCP Config Placeholders section nếu mcp.json có user-specific values
- [ ] Với Powers: autoApprove chỉ list safe/read-only tools
