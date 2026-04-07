# Workflow: Sentry SDK Setup by Platform

Detailed SDK setup patterns with validation gates for each platform.

## Platform Selection

```
What framework/runtime?
├─ Node.js (Express, Fastify, Koa) → @sentry/node
├─ Browser vanilla JS → @sentry/browser
├─ React (Vite/CRA) → @sentry/react
├─ Next.js → @sentry/nextjs (wizard available)
├─ Vue → @sentry/vue
├─ Python (generic) → sentry-sdk
├─ FastAPI → sentry-sdk[fastapi]
├─ Django → sentry-sdk[django]
└─ Flask → sentry-sdk[flask]
```

## Node.js (Express)

### Step 1: Install
```bash
npm install @sentry/node @sentry/profiling-node
```
**Validate:** Package in `package.json` dependencies.

### Step 2: Init (MUST be first import)
```javascript
// instrument.js — import this BEFORE everything else
import * as Sentry from "@sentry/node";
import { nodeProfilingIntegration } from "@sentry/profiling-node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || "production",
  release: process.env.SENTRY_RELEASE,
  integrations: [nodeProfilingIntegration()],
  tracesSampleRate: process.env.NODE_ENV === "production" ? 0.1 : 1.0,
  profilesSampleRate: 0.1,
});
```

### Step 3: Express Integration
```javascript
// app.js
import "./instrument.js"; // MUST be first
import express from "express";
import * as Sentry from "@sentry/node";

const app = express();

// Routes here...

// Sentry error handler MUST be before any other error middleware
Sentry.setupExpressErrorHandler(app);

// Optional: custom error handler after Sentry
app.use((err, req, res, next) => {
  res.status(500).json({ error: "Internal server error" });
});
```
**Validate:** `instrument.js` imported before express. Error handler registered after routes.

### Step 4: Test
```javascript
app.get("/debug-sentry", (req, res) => {
  throw new Error("Sentry test error");
});
```
**Validate:** Error appears in Sentry dashboard.

## React (Vite)

### Step 1: Install
```bash
npm install @sentry/react
```

### Step 2: Init
```typescript
// src/instrument.ts
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  release: import.meta.env.VITE_SENTRY_RELEASE,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({ maskAllText: true, blockAllMedia: true }),
  ],
  tracesSampleRate: import.meta.env.PROD ? 0.1 : 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
});
```

### Step 3: Error Boundary
```tsx
// src/main.tsx
import "./instrument"; // MUST be first
import { createRoot } from "react-dom/client";
import * as Sentry from "@sentry/react";
import App from "./App";

const SentryErrorBoundary = Sentry.withErrorBoundary(App, {
  fallback: <p>Something went wrong. Please refresh.</p>,
  showDialog: true,
});

createRoot(document.getElementById("root")!).render(<SentryErrorBoundary />);
```
**Validate:** Error boundary wraps root component. Instrument imported first.

### Step 4: Source Maps (Vite)
```typescript
// vite.config.ts
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default defineConfig({
  build: { sourcemap: true },
  plugins: [
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
    }),
  ],
});
```
**Validate:** `build.sourcemap: true` set. Plugin configured with org/project/token.

## Next.js

### Step 1: Wizard (recommended)
```bash
npx @sentry/wizard@latest -i nextjs
```
This auto-creates: `sentry.client.config.ts`, `sentry.server.config.ts`, `sentry.edge.config.ts`, `next.config.ts` wrapper.

### Step 2: Manual Setup (if wizard not used)
```bash
npm install @sentry/nextjs
```

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

```typescript
// sentry.server.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 0.1,
});
```

```typescript
// next.config.ts
import { withSentryConfig } from "@sentry/nextjs";

const nextConfig = { /* your config */ };

export default withSentryConfig(nextConfig, {
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  authToken: process.env.SENTRY_AUTH_TOKEN,
  silent: true,
  widenClientFileUpload: true,
  hideSourceMaps: true,
});
```
**Validate:** Three config files exist. `next.config.ts` wrapped with `withSentryConfig`.

### Step 3: Global Error Handler
```typescript
// app/global-error.tsx
"use client";
import * as Sentry from "@sentry/nextjs";
import { useEffect } from "react";

export default function GlobalError({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => { Sentry.captureException(error); }, [error]);
  return (
    <html><body>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </body></html>
  );
}
```

## Python / FastAPI

### Step 1: Install
```bash
pip install sentry-sdk[fastapi]
# or with uv:
uv add "sentry-sdk[fastapi]"
```

### Step 2: Init (before app creation)
```python
# main.py
import os
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("ENVIRONMENT", "production"),
    release=os.environ.get("SENTRY_RELEASE"),
    traces_sample_rate=0.1,
    profiles_sample_rate=0.1,
    before_send=_scrub_pii,
)

def _scrub_pii(event, hint):
    """Remove PII before sending to Sentry."""
    user = event.get("user", {})
    user.pop("email", None)
    user.pop("ip_address", None)
    return event

# AFTER sentry init
from fastapi import FastAPI
app = FastAPI()
```
**Validate:** `sentry_sdk.init()` called BEFORE `FastAPI()` instantiation.

### Step 3: Custom Context
```python
import sentry_sdk

@app.post("/checkout")
async def checkout(order: OrderRequest):
    sentry_sdk.set_user({"id": order.user_id})
    sentry_sdk.set_tag("payment_method", order.payment_method)
    sentry_sdk.set_context("order", {"id": order.id, "total": order.total})
    # ... business logic
```

### Step 4: Test
```python
@app.get("/debug-sentry")
async def debug_sentry():
    raise ValueError("Sentry test error")
```
**Validate:** Error appears in Sentry with FastAPI request context.

## Django

### Step 1: Install
```bash
pip install sentry-sdk[django]
```

### Step 2: Init in settings.py
```python
# settings.py
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("DJANGO_ENV", "production"),
    release=os.environ.get("SENTRY_RELEASE"),
    traces_sample_rate=0.1,
    send_default_pii=False,
)
```
**Validate:** Init in `settings.py`, not in `wsgi.py` or `manage.py`.

## Environment Variables Checklist

Every Sentry-instrumented project should have these env vars:

| Variable | Required | Example |
|----------|----------|---------|
| `SENTRY_DSN` | Yes | `https://abc@o123.ingest.sentry.io/456` |
| `SENTRY_RELEASE` | Recommended | `my-app@1.2.3` or git SHA |
| `SENTRY_ORG` | For source maps | `my-org` |
| `SENTRY_PROJECT` | For source maps | `my-project` |
| `SENTRY_AUTH_TOKEN` | For source maps | Token from sentry.io settings |
| `NODE_ENV` / `ENVIRONMENT` | Recommended | `production` |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Init after framework setup | Sentry MUST init before Express/FastAPI/Django |
| Missing source maps | Add Vite/Webpack plugin or CLI upload in CI |
| `NEXT_PUBLIC_SENTRY_DSN` not set | Client-side needs `NEXT_PUBLIC_` prefix in Next.js |
| `sendDefaultPii: true` | Keep false, manually set user context without PII |
| No error boundary in React | Wrap root with `Sentry.withErrorBoundary` |
| Same DSN for all environments | Use separate projects or at minimum set `environment` |
