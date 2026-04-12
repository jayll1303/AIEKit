#!/usr/bin/env bash
# Bug Condition Exploration Test
# ================================
# This test encodes the EXPECTED (correct) behavior for installer documentation.
# It MUST FAIL on unfixed code — failure confirms the bugs exist.
#
# Validates: Requirements 1.1, 1.2, 1.3
# Property 1: Bug Condition - README Manual Install path & SKILL.md remote install method

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ERRORS=""

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected=$expected, actual=$actual)"
    ERRORS="${ERRORS}\n  - $desc: expected=$expected, got=$actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Bug Condition Exploration Test ==="
echo ""

# ---------------------------------------------------------------------------
# Bug 1: README.md Manual Install section should NOT contain .kiro/install.sh
# ---------------------------------------------------------------------------
echo "[Bug 1] README.md Manual Install path check"

# Extract Manual Install section (between "### Manual Install" and next "---")
MANUAL_SECTION=$(sed -n '/^### Manual Install/,/^---/p' "$REPO_ROOT/README.md")

# Count occurrences of the WRONG path .kiro/install.sh in Manual Install section
WRONG_PATH_COUNT=$(echo "$MANUAL_SECTION" | grep -c '\.kiro/install\.sh' || true)

# Expected behavior: 0 occurrences of .kiro/install.sh (all paths should be /tmp/aie-skills/install.sh)
assert_eq "README Manual Install has NO .kiro/install.sh (wrong path)" "0" "$WRONG_PATH_COUNT"

# ---------------------------------------------------------------------------
# Bug 2: SKILL.md Step 4 should contain curl -fsSL as primary remote method
# ---------------------------------------------------------------------------
echo ""
echo "[Bug 2] SKILL.md Step 4 remote install method check"

SKILL_FILE="$REPO_ROOT/.kiro/skills/aie-skills-installer/SKILL.md"

# Extract Step 4 section (between "### Step 4" and "### Step 5" or next ## heading)
STEP4_SECTION=$(sed -n '/^### Step 4/,/^### Step [5-9]\|^## /p' "$SKILL_FILE")

# Count occurrences of curl -fsSL in Step 4 (remote install method)
CURL_COUNT=$(echo "$STEP4_SECTION" | grep -c 'curl -fsSL' || true)

# Expected behavior: at least 1 occurrence of curl -fsSL in Step 4
if [[ "$CURL_COUNT" -ge 1 ]]; then
  echo "  PASS: SKILL.md Step 4 contains curl -fsSL remote install method"
  PASS=$((PASS + 1))
else
  echo "  FAIL: SKILL.md Step 4 does NOT contain curl -fsSL (found $CURL_COUNT occurrences)"
  ERRORS="${ERRORS}\n  - SKILL.md Step 4 missing curl -fsSL remote install: found $CURL_COUNT occurrences"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "FAILURES (these confirm bugs exist in unfixed code):"
  echo -e "$ERRORS"
  echo ""
  echo "Counterexamples:"
  echo "  Bug 1: README Manual Install contains '$WRONG_PATH_COUNT' occurrences of .kiro/install.sh"
  echo "         Lines: $(echo "$MANUAL_SECTION" | grep '\.kiro/install\.sh' || echo 'none')"
  echo "  Bug 2: SKILL.md Step 4 has $CURL_COUNT occurrences of 'curl -fsSL' (expected >= 1)"
  exit 1
fi

echo "All checks passed!"
exit 0
