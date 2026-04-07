# Sentry Kiro Component — Research Report

> Phân tích best practices và đề xuất cách xây dựng Kiro component cho Sentry integration.

## 1. Sentry Ecosystem Overview

Sentry cung cấp 2 mảng chính mà developer cần agent hỗ trợ:

| Mảng | Mô tả | Agent cần gì |
|------|--------|--------------|
| **SDK Integration** | Setup, config, error capture, tracing, breadcrumbs, source maps | Instructions cách init, config patterns, best practices |
| **MCP Server** | Remote MCP server tại `https://mcp.sentry.dev/mcp` — query issues, events, projects, Seer AI | MCP tools access + workflow guidance |

## 2. Sentry MCP Server — Đã có official

Sentry có official MCP server (`getsentry/sentry-mcp`) với:
- Remote hosted (OAuth) hoặc local stdio (`npx @sentry/mcp-server`)
- 16 tool calls bao gồm:
  - `list_projects` — list projects trong org
  - `list_project_issues` — list issues của project
  - `get_sentry_issue` — chi tiết issue (by ID hoặc URL)
  - `resolve_short_id` — resolve issue bằng short ID
  - `get_sentry_event` — chi tiết event
  - `list_issue_events` — list events của issue
  - `list_error_events_in_project` — list error events
  - `create_project` — tạo project mới
  - `list_organization_replays` — list session replays
  - Seer integration — AI root cause analysis + fix suggestions
- OAuth authentication (sentry.io) hoặc access token (self-hosted)
- Scoping: có thể restrict theo org/project

## 3. Đề Xuất Component Type

### Option A: Guided MCP Power (RECOMMENDED)

```
power-sentry/
├── POWER.md              # Overview + SDK patterns + MCP workflows
├── mcp.json              # Sentry MCP server config
└── steering/
    ├── workflow-debugging.md      # Debug issues workflow
    └── workflow-sdk-setup.md      # SDK setup patterns
```

**Lý do chọn Power thay vì Skill:**
1. Sentry MCP server là official, production-ready — Power wrap MCP tools + guidance
2. Developer cần CẢ HAI: SDK setup knowledge + MCP tools để query issues
3. Power cho phép bundle MCP config + steering workflows
4. Không cần tự build MCP server — dùng official remote endpoint

### Option B: Skill only (nếu không muốn MCP)

Chỉ cung cấp SDK integration patterns, không có MCP tools.
→ Hạn chế: agent không query được Sentry data trực tiếp.

### Option C: Power + Skill combo

Power cho MCP + debugging workflows, Skill riêng cho SDK patterns.
→ Quá phức tạp, vi phạm KISS. Power đã đủ chứa cả hai.

**Kết luận: Option A — Guided MCP Power là hợp lý nhất.**

## 4. Nội Dung POWER.md Cần Cover

### 4.1 SDK Integration Patterns (Knowledge Base)

| Topic | Chi tiết |
|-------|---------|
| **Init Configuration** | DSN, environment, release, sampleRate, tracesSampleRate, beforeSend, beforeBreadcrumb |
| **Platform-specific setup** | JavaScript (browser + Node.js), Python (Django/FastAPI/Flask), React, Next.js, Vue |
| **Error Capture** | captureException, captureMessage, scope management, context enrichment |
| **Performance/Tracing** | Transaction, spans, custom instrumentation, sampling strategies |
| **Breadcrumbs** | Auto vs manual, filtering, custom breadcrumbs |
| **Source Maps** | Upload via CLI, CI/CD integration, release association |
| **Filtering & Sampling** | beforeSend, ignoreErrors, denyUrls, allowUrls, rate limiting |
| **PII Scrubbing** | beforeSend filtering, data scrubbing config, GDPR compliance |
| **Release Tracking** | sentry-cli releases, deploy tracking, commit association |
| **Alert Configuration** | Issue alerts, metric alerts, Slack/email integration |

### 4.2 MCP Debugging Workflows

| Workflow | Steps |
|----------|-------|
| **Fix issue from URL** | Paste Sentry URL → get_sentry_issue → analyze stack trace → propose fix |
| **Triage production errors** | list_project_issues → filter by frequency/impact → prioritize |
| **Root cause analysis** | get_sentry_issue → Seer analysis → get fix suggestion |
| **Compare releases** | list_error_events_in_project → filter by release → compare error rates |
| **Setup new project** | create_project → get DSN → generate SDK init code |

### 4.3 Anti-Patterns

| Sai | Đúng |
|-----|------|
| `tracesSampleRate: 1.0` in production | 0.05-0.25 tùy traffic |
| Hardcode DSN trong source | Dùng env var `SENTRY_DSN` |
| Capture mọi error không filter | Dùng `beforeSend` + `ignoreErrors` |
| Không set `release` | Luôn set release để track regression |
| Không upload source maps | Upload trong CI/CD pipeline |
| Gửi PII (email, IP) không scrub | Dùng `beforeSend` để strip PII |

## 5. MCP Config

### Remote (recommended — sentry.io users)

```json
{
  "mcpServers": {
    "sentry": {
      "url": "https://mcp.sentry.dev/mcp"
    }
  }
}
```

Kiro chưa support OAuth remote MCP natively → cần dùng stdio bridge:

### Stdio (local — works everywhere)

```json
{
  "mcpServers": {
    "sentry": {
      "command": "npx",
      "args": ["@sentry/mcp-server@latest"],
      "env": {},
      "autoApprove": [
        "list_projects",
        "list_project_issues",
        "get_sentry_issue",
        "get_sentry_event",
        "list_issue_events",
        "list_error_events_in_project",
        "resolve_short_id",
        "list_organization_replays"
      ]
    }
  }
}
```

### Self-hosted

```json
{
  "mcpServers": {
    "sentry": {
      "command": "npx",
      "args": [
        "@sentry/mcp-server@latest",
        "--access-token=YOUR_SENTRY_ACCESS_TOKEN",
        "--host=YOUR_SENTRY_HOST"
      ],
      "env": {},
      "autoApprove": [
        "list_projects",
        "list_project_issues",
        "get_sentry_issue",
        "get_sentry_event"
      ]
    }
  }
}
```

## 6. Keyword Strategy

Keywords cần specific, tránh quá chung:

```yaml
keywords: ["sentry", "error tracking", "error monitoring", "sentry sdk", "sentry mcp", "sentry issues", "crash reporting"]
```

Tránh: "error", "debug", "monitoring" (quá chung → false activation)

## 7. Scope Boundary

```
This power handles:
- Sentry SDK initialization and configuration
- Error capture, tracing, breadcrumbs patterns
- Source map upload and release tracking
- Querying Sentry issues/events via MCP
- Seer AI root cause analysis
- Alert and notification setup guidance

Does NOT handle:
- General error handling patterns (→ backend-development skill)
- Application logging (→ project-specific)
- APM tools khác (Datadog, New Relic)
- CI/CD pipeline setup (→ devops skill)
```

## 8. Layer Assignment

Power `sentry` thuộc **APPLICATION LAYER** — tương tự fastapi-at-scale, nó là tool-specific integration.

Connections:
- `fastapi-at-scale` → Sentry Python SDK setup cho FastAPI
- `docker-gpu-setup` → Sentry trong Docker containers
- `python-project-setup` → Add sentry-sdk dependency

## 9. Steering Considerations

POWER.md sẽ > 300 lines nếu chứa cả SDK patterns + MCP workflows.
→ Split steering:
- `workflow-debugging.md` — MCP-based debugging workflows (paste URL → fix)
- `workflow-sdk-setup.md` — SDK init patterns per platform

POWER.md giữ overview + quick reference + decision tables.

## 10. Unresolved Questions

1. Kiro có support OAuth remote MCP không? Nếu có → dùng remote URL trực tiếp, nếu không → phải dùng stdio
2. Sentry MCP server có cần Node.js/npx pre-installed không? → Có, cần npx cho stdio mode
3. Nên support bao nhiêu platforms trong SDK patterns? → Recommend focus JS + Python (phổ biến nhất), mention others
