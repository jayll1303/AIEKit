# Workflow: Debug Sentry Issues via MCP

Step-by-step workflows for debugging production issues using Sentry MCP tools.

## Workflow 1: Fix Issue from URL

When user pastes a Sentry issue URL (e.g., `https://sentry.io/issues/123456/` or `https://my-org.sentry.io/issues/PROJECT-123/`):

### Step 1: Fetch Issue Details
1. Call `get_sentry_issue` with the URL or issue ID
2. Extract: title, culprit, stack trace, tags, first/last seen, event count
**Validate:** Response contains stack trace with file paths and line numbers.

### Step 2: Analyze Stack Trace
1. Identify the exception type and message
2. Trace the call stack from top (most recent) to bottom (origin)
3. Find the file and line where the error originates in user code (skip library frames)
4. Note relevant tags: browser, OS, release version, environment
**Validate:** Identified at least one user-code file in the stack trace.

### Step 3: Read Source Code
1. Open the identified file(s) from the stack trace
2. Read the function/method where the error occurs
3. Check surrounding context (error handling, input validation, null checks)
**Validate:** Source code matches the stack trace (same function names, line numbers plausible).

### Step 4: Determine Root Cause
1. Match exception type to common causes:
   - `TypeError` / `AttributeError` → null/undefined access, missing property
   - `ReferenceError` / `NameError` → undefined variable, import issue
   - `NetworkError` / `ConnectionError` → API/service down, timeout
   - `ValidationError` → bad input data, schema mismatch
2. Check breadcrumbs for user actions leading to the error
3. Check tags for environment-specific patterns (only in production? specific browser?)
**Validate:** Root cause explains both the exception AND the frequency pattern.

### Step 5: Propose Fix
1. Write the minimal code change to fix the root cause
2. Add defensive checks if the error is from external input
3. Consider edge cases that could cause similar errors
**Validate:** Fix addresses root cause, not just symptom. No new issues introduced.

## Workflow 2: Triage Production Errors

When user asks "what's broken?" or "top errors this week":

### Step 1: List Issues
1. Call `list_project_issues` with org and project slugs
2. Request sorted by frequency or last seen
**Validate:** Response returns issue list with counts.

### Step 2: Categorize
1. Group issues by:
   - Error type (TypeError, NetworkError, etc.)
   - Module/component (auth, payment, API, UI)
   - Severity (crash vs warning vs info)
2. Identify issues with highest event count or most affected users
**Validate:** At least top 5 issues identified with impact metrics.

### Step 3: Deep Dive Top Issues
1. For each high-impact issue, call `get_sentry_issue`
2. Summarize: what, where, how often, since when, which users
3. Estimate fix complexity (quick fix vs refactor)
**Validate:** Each issue has actionable summary.

### Step 4: Prioritize
Present prioritized list:
```
Priority | Issue | Impact | Fix Effort
---------|-------|--------|----------
P0       | Payment crash on checkout | 500 users/day | Quick fix
P1       | API timeout on search | 200 users/day | Medium
P2       | CSS layout shift on mobile | 100 users/day | Low effort
```

## Workflow 3: Root Cause Analysis with Seer

When Seer AI analysis is available:

### Step 1: Get Issue with Seer Data
1. Call `get_sentry_issue` — Seer analysis included if available
2. Review AI-generated root cause hypothesis
3. Review suggested fix (if provided)
**Validate:** Seer analysis present in response.

### Step 2: Verify Seer's Analysis
1. Cross-reference Seer's root cause with actual source code
2. Check if the suggested fix is correct and complete
3. Verify fix doesn't introduce regressions
**Validate:** Seer's analysis aligns with code reality.

### Step 3: Apply or Adapt Fix
1. If Seer's fix is correct → apply directly
2. If partially correct → adapt to project conventions
3. If incorrect → use Seer's analysis as starting point, investigate manually
**Validate:** Fix resolves the issue without side effects.

## Workflow 4: Compare Releases

When user asks "did the last deploy break anything?":

### Step 1: Get Error Events by Release
1. Call `list_error_events_in_project` for current release
2. Call again for previous release
**Validate:** Both responses return event data.

### Step 2: Compare
1. Count total errors per release
2. Identify NEW error types in current release (not present in previous)
3. Identify error types with significantly increased frequency
**Validate:** Comparison shows clear delta.

### Step 3: Report
```
Release v2.4 vs v2.3:
- Total errors: 450 vs 320 (+40%)
- NEW errors: TypeError in PaymentForm.tsx (150 events)
- Increased: API timeout errors +80%
- Resolved: Login redirect loop (0 events in v2.4)
```

## Workflow 5: Setup New Sentry Project

When user needs to instrument a new app:

### Step 1: Create Project
1. Call `create_project` with org, team, platform
2. Extract DSN from response
**Validate:** DSN returned in format `https://xxx@xxx.ingest.sentry.io/xxx`.

### Step 2: Generate Init Code
1. Determine platform from project config or user input
2. Generate SDK init code using patterns from POWER.md
3. Include environment-appropriate sampling rates
**Validate:** Init code uses env var for DSN, not hardcoded.

### Step 3: Verify
1. Add a test error: `Sentry.captureMessage("Test from setup")`
2. Check Sentry dashboard for the test event
**Validate:** Test event appears in Sentry within 30 seconds.

## Tips for Effective Debugging

- Always check breadcrumbs — they show what happened BEFORE the error
- Tags reveal patterns: same browser? same region? same release?
- Event count + first/last seen = is this new or chronic?
- Multiple events with same stack trace = systematic issue, not fluke
- If stack trace shows only library code, source maps may be missing
