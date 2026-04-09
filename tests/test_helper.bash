#!/bin/bash
# Test helper — source functions from lib/profiles.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source functions directly from lib/ — no more fragile sed extraction
source "$SCRIPT_DIR/lib/profiles.sh"

# Stub color variables and helper functions
BOLD="" GREEN="" CYAN="" YELLOW="" RED="" RESET=""
info()  { echo "▸ $*"; }
ok()    { echo "✓ $*"; }
warn()  { echo "⚠ $*"; }
err()   { echo "✗ $*" >&2; }

# Helper: create mock source directory with all 30 skills, 6 steering, 3 powers
create_mock_source() {
  local dir="$1"
  mkdir -p "$dir/.kiro/skills" "$dir/.kiro/steering" "$dir/.kiro/powers"

  # Create all 30 skill directories
  for skill in $(all_skills | tr ' ' '\n' | sort -u); do
    mkdir -p "$dir/.kiro/skills/$skill"
    echo "mock" > "$dir/.kiro/skills/$skill/SKILL.md"
  done

  # Create all 6 steering files
  for f in python-project-conventions.md gpu-environment.md notebook-conventions.md ml-training-workflow.md inference-deployment.md kiro-component-creation.md; do
    printf '%s\n' "---" "inclusion: always" "---" "" "# Steering Content for $f" "Body text here." > "$dir/.kiro/steering/$f"
  done

  # Create 3 mock powers
  for power in power-huggingface power-gpu-monitor power-sentry; do
    mkdir -p "$dir/.kiro/powers/$power"
    echo "mock" > "$dir/.kiro/powers/$power/POWER.md"
    echo '{}' > "$dir/.kiro/powers/$power/mcp.json"
  done
}

# Helper: simulate skill install, returns "installed skipped"
simulate_skill_install() {
  local source="$1" target="$2" mode="$3" profiles="$4" force="${5:-false}"
  local installed=0 skipped=0 updated_count=0
  local skill_list
  skill_list=$(resolve_skills "$mode" "$profiles")
  for skill_name in $skill_list; do
    if [ -d "$source/.kiro/skills/$skill_name" ]; then
      if [ ! -d "$target/.kiro/skills/$skill_name" ] || [ "$force" = true ]; then
        if [ -d "$target/.kiro/skills/$skill_name" ] && [ "$force" = true ]; then
          rm -rf "$target/.kiro/skills/$skill_name"
          updated_count=$((updated_count + 1))
        fi
        cp -r "$source/.kiro/skills/$skill_name" "$target/.kiro/skills/$skill_name"
        installed=$((installed + 1))
      else
        skipped=$((skipped + 1))
      fi
    fi
  done
  echo "$installed $skipped $updated_count"
}

# Helper: simulate steering install, returns "installed skipped"
simulate_steering_install() {
  local source="$1" target="$2" profiles="$3" force="${4:-false}"
  local installed=0 skipped=0
  local steering_list
  steering_list=$(resolve_steering "$profiles")
  for f in $steering_list; do
    if [ -f "$source/.kiro/steering/$f" ]; then
      if [ ! -f "$target/.kiro/steering/$f" ] || [ "$force" = true ]; then
        cp "$source/.kiro/steering/$f" "$target/.kiro/steering/"
        installed=$((installed + 1))
      else
        skipped=$((skipped + 1))
      fi
    fi
  done
  echo "$installed $skipped"
}
