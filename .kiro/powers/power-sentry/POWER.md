---
name: "sentry"
displayName: "Sentry Error Tracking & Debugging"
description: "Integrate Sentry SDK for error tracking, performance monitoring, and debug production issues via MCP. Setup patterns for JavaScript, Python, React, Next.js, FastAPI."
keywords: ["sentry", "error tracking", "sentry sdk", "sentry mcp", "crash reporting", "sentry issues", "error monitoring"]
author: "AIE"
---

# Sentry Error Tracking & Debugging

Sentry SDK integration patterns + MCP-powered debugging workflows. This power helps you set up Sentry correctly and debug production issues directly from your IDE.

## Scope

This power handles:
- Sentry SDK initialization and configuration (JS, Python, React, Next.js, FastAPI, Django)
- Error capture, tracing, breadcrumbs, and context enrichment
- Source map upload and release tracking
- Querying Sentry issues/events via MCP tools
- Seer AI root cause analysis and fix suggestions
- Filtering, sampling, and PII scrubbing patterns

Does NOT handle:
- General error handling patterns (→ backend-development skill)
- APM tools other than Sentry (Datadog, New Relic, etc.)
- CI/CD pipeline setup (→ devops skill)
- Docker containerization (→ docker-gpu-setup skill)

## Onboarding

### Prerequisites
- Node.js 18+ (for MCP server via npx)
- Sentry account at sentry.io (or self-hosted instance)

### First-time Setup
1. MCP server authenticates via device-code flow on first run — opens browser to log in
2. Token cached at `~/.sentry/mcp.json` for future sessions
3. For self-hosted: create access token in User Settings → Auth Tokens with scopes: `org:read`, `project:read`, `project:write`, `team:read`, `team:write`, `event:write`

### Non-interactive Auth (CI, piped stdio)
```bash
npx @sentry/mcp-server@latest auth login
npx @sentry/mcp-server@latest auth status
npx @sentry/mcp-server@latest auth logout
```

## Available MCP Tools

| Tool | Purpose | Safe |
|------|---------|------|
| `list_projects` | List all projects in an organization | ✅ |
| `list_project_issues` | List issues for a specific project | ✅ |
| `get_sentry_issue` | Get issue details by ID or URL | ✅ |
| `resolve_short_id` | Resolve issue by short ID (e.g., PROJECT-123) | ✅ |
| `get_sentry_event` | Get specific event details from an issue | ✅ |
| `list_issue_events` | List events for a specific issue | ✅ |
| `list_error_events_in_project` | List error events in a project | ✅ |
| `create_project` | Create new Sentry project + get DSN | ⚠️ write |
| `list_organization_replays` | List session replays with filters | ✅ |

## Common Workflows

### 1. Fix Issue from URL
```
User pastes: https://sentry.io/issues/6811213890/
→ get_sentry_issue (extract stack trace, tags, context)
→ Analyze root cause from stack trace
→ Propose code fix
```

### 2. Triage Production Errors
```
→ list_project_issues (org, project, sorted by frequency)
→ Identify top unresolved errors
→ get_sentry_issue for each high-impact issue
→ Prioritize by user impact
```

### 3. Root Cause with Seer AI
```
→ get_sentry_issue (includes Seer analysis if available)
→ Review AI-generated root cause
→ Apply suggested fix
```

### 4. Setup New Project
```
→ create_project (org, team, platform)
→ Get DSN from response
→ Generate SDK init code for the platform
```

### 5. Compare Releases
```
→ list_error_events_in_project (filter by release)
→ Compare error counts between versions
→ Identify regressions
```

## SDK Quick Reference

### Platform Decision Table

| Platform | Package | Init Location |
|----------|---------|---------------|
| Node.js (Express/Fastify) | `@sentry/node` | App entry point, before other imports |
| Browser JavaScript | `@sentry/browser` | `<head>` or app entry |
| React | `@sentry/react` | Before `ReactDOM.render()` |
| Next.js | `@sentry/nextjs` | `sentry.client.config.ts` + `sentry.server.config.ts` + `sentry.edge.config.ts` |
| Python (generic) | `sentry-sdk` | App startup, before other imports |
| FastAPI | `sentry-sdk[fastapi]` | Before `app = FastAPI()` |
| Django | `sentry-sdk[django]` | `settings.py` |
| Vue | `@sentry/vue` | Before `createApp()` |

### Sampling Strategy

| Environment | `sampleRate` | `tracesSampleRate` | Notes |
|-------------|-------------|-------------------|-------|
| Development | 1.0 | 1.0 | Capture everything |
| Staging | 1.0 | 0.5 | All errors, half traces |
| Production (low traffic) | 1.0 | 0.25 | All errors, 25% traces |
| Production (high traffic) | 1.0 | 0.05–0.1 | All errors, 5-10% traces |

### Essential Config Options

| Option | Purpose | Default |
|--------|---------|---------|
| `dsn` | Project identifier (from env var) | required |
| `environment` | `development` / `staging` / `production` | `production` |
| `release` | Version string for regression tracking | auto-detected |
| `sampleRate` | Error sampling rate [0-1] | 1.0 |
| `tracesSampleRate` | Performance trace sampling [0-1] | 0 (disabled) |
| `beforeSend` | Filter/modify events before sending | none |
| `beforeBreadcrumb` | Filter/modify breadcrumbs | none |
| `ignoreErrors` | Regex/string patterns to ignore | [] |
| `denyUrls` | URL patterns to ignore (browser) | [] |
| `maxBreadcrumbs` | Max breadcrumbs per event | 100 |
| `attachStacktrace` | Attach stack trace to messages | false |
| `sendDefaultPii` | Auto-attach user IP, cookies | false |

## SDK Init Patterns

### JavaScript / Node.js
```javascript
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.SENTRY_RELEASE,
  tracesSampleRate: 0.1,
  beforeSend(event) {
    // Strip PII
    if (event.user) {
      delete event.user.email;
      delete event.user.ip_address;
    }
    return event;
  },
  ignoreErrors: [
    "ResizeObserver loop limit exceeded",
    "Network request failed",
  ],
});
```

### Python / FastAPI
```python
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("ENVIRONMENT", "production"),
    release=os.environ.get("SENTRY_RELEASE"),
    traces_sample_rate=0.1,
    before_send=scrub_pii,
    ignore_errors=[KeyboardInterrupt],
)

def scrub_pii(event, hint):
    if "user" in event and "email" in event["user"]:
        del event["user"]["email"]
    return event
```

### React
```typescript
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({ maskAllText: true }),
  ],
  tracesSampleRate: 0.1,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
});

// Wrap root component
const App = Sentry.withProfiler(AppComponent);
```

### Next.js
```typescript
// sentry.client.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  integrations: [Sentry.replayIntegration()],
});
```

## Error Capture Patterns

### Manual Capture
```javascript
// Capture exception with context
Sentry.captureException(error, {
  tags: { module: "payment", action: "checkout" },
  extra: { orderId: order.id, amount: order.total },
  level: "error",
});

// Capture message
Sentry.captureMessage("Payment timeout", "warning");
```

### Scope Management
```javascript
Sentry.withScope((scope) => {
  scope.setTag("transaction", "payment");
  scope.setUser({ id: user.id });
  scope.setContext("order", { id: orderId, items: itemCount });
  Sentry.captureException(error);
});
```

### Custom Breadcrumbs
```javascript
Sentry.addBreadcrumb({
  category: "auth",
  message: `User ${userId} logged in`,
  level: "info",
  data: { method: "oauth", provider: "google" },
});
```

## Source Maps & Releases

### CLI Upload (CI/CD)
```bash
# Install CLI
npm install -g @sentry/cli

# Create release
sentry-cli releases new $RELEASE_VERSION
sentry-cli releases set-commits $RELEASE_VERSION --auto

# Upload source maps
sentry-cli sourcemaps upload --release=$RELEASE_VERSION ./dist

# Finalize
sentry-cli releases finalize $RELEASE_VERSION
sentry-cli releases deploys $RELEASE_VERSION new -e production
```

### Webpack/Vite Plugin
```javascript
// vite.config.ts
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default {
  build: { sourcemap: true },
  plugins: [
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
    }),
  ],
};
```

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Default config is fine for production" | ALWAYS set environment, release, and sampling rates |
| "tracesSampleRate: 1.0 is OK" | Will overwhelm Sentry quota on any real traffic. Use 0.05-0.25 |
| "Just put DSN in the code" | Use env vars. DSN in source = security risk + hard to rotate |
| "Don't need source maps" | Without source maps, stack traces are useless in minified code |
| "Capture everything, filter later" | Use beforeSend + ignoreErrors to reduce noise at source |
| "sendDefaultPii: true is convenient" | Violates GDPR/CCPA. Scrub PII with beforeSend |
| "Skip release tracking" | Without releases, can't identify which deploy caused regression |

## Troubleshooting

```
Events not appearing in Sentry?
├─ Check DSN is correct and not empty
├─ Check sampleRate > 0
├─ Check beforeSend isn't returning null for all events
├─ Check network: can app reach sentry.io?
├─ Enable debug: Sentry.init({ debug: true })
└─ Check browser console / server logs for Sentry errors

Source maps not working?
├─ Verify sourcemap: true in build config
├─ Check release matches between SDK init and upload
├─ Verify files uploaded: sentry-cli sourcemaps list --release=X
└─ Check URL prefix matches deployed asset paths

MCP server not connecting?
├─ Run: npx @sentry/mcp-server@latest auth status
├─ Re-auth: npx @sentry/mcp-server@latest auth login
├─ Check Node.js 18+ installed
└─ Self-hosted: verify access token scopes
```

## MCP Config Placeholders

For self-hosted Sentry instances, replace these values in `mcp.json`:

| Placeholder | Description | How to get |
|-------------|-------------|------------|
| `YOUR_SENTRY_ACCESS_TOKEN` | API auth token | Sentry → User Settings → Auth Tokens → Create New Token (scopes: org:read, project:read, project:write, team:read, team:write, event:write) |
| `YOUR_SENTRY_HOST` | Self-hosted Sentry URL | Your Sentry instance hostname (e.g., `sentry.example.com`) |

For sentry.io users: no placeholders needed. The MCP server uses device-code OAuth automatically.

## Connected Skills

| Situation | Skill | Why |
|-----------|-------|-----|
| Building FastAPI backend | fastapi-at-scale | Sentry Python SDK + FastAPI integration |
| Containerizing app | docker-gpu-setup | Sentry in Docker, env var management |
| Setting up Python project | python-project-setup | Add sentry-sdk to dependencies |
| Backend architecture | backend-development | Error handling patterns that feed into Sentry |

## Steering Files

- [workflow-debugging.md](steering/workflow-debugging.md) — MCP-based debugging: paste URL → analyze → fix
- [workflow-sdk-setup.md](steering/workflow-sdk-setup.md) — Detailed SDK setup per platform with validation gates
