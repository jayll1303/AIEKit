#!/bin/bash
# Test helper — extract and source functions from install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

# Source only the function definitions (between Profile Definitions and Parse arguments)
eval "$(sed -n '/^# ── Profile Definitions/,/^# ── Parse arguments/p' "$INSTALL_SCRIPT" | head -n -1)"

# Stub color variables and helper functions
BOLD="" GREEN="" CYAN="" YELLOW="" RED="" RESET=""
info()  { echo "▸ $*"; }
ok()    { echo "✓ $*"; }
warn()  { echo "⚠ $*"; }
err()   { echo "✗ $*" >&2; }

# Helper: create mock source directory with all 30 skills and 6 steering files
create_mock_source() {
  local dir="$1"
  mkdir -p "$dir/.kiro/skills" "$dir/.kiro/steering"

  # Create all 30 skill directories
  for skill in $(all_skills | tr ' ' '\n' | sort -u); do
    mkdir -p "$dir/.kiro/skills/$skill"
    echo "mock" > "$dir/.kiro/skills/$skill/SKILL.md"
  done

  # Create all 6 steering files
  for f in python-project-conventions.md gpu-environment.md notebook-conventions.md ml-training-workflow.md inference-deployment.md kiro-component-creation.md; do
    echo "---" > "$dir/.kiro/steering/$f"
    echo "inclusion: always" >> "$dir/.kiro/steering/$f"
    echo "---" >> "$dir/.kiro/steering/$f"
  done
}
