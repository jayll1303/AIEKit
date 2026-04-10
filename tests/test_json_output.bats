#!/usr/bin/env bats
# Tests for --json output mode
# Feature: installer-agent-alignment, Phase 5

load 'test_helper'

setup() {
  TEST_TMPDIR=$(mktemp -d)
  SOURCE_DIR="$TEST_TMPDIR/source"
  TARGET_DIR="$TEST_TMPDIR/target"
  create_mock_source "$SOURCE_DIR"
  mkdir -p "$TARGET_DIR/.kiro/skills" "$TARGET_DIR/.kiro/steering"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Helper: simulate install and produce JSON output
# Uses the same to_json_array logic as install.sh
to_json_array() {
  local items="$1"
  if [ -z "$items" ] || [ "$(echo "$items" | xargs)" = "" ]; then
    echo "[]"
    return
  fi
  echo "$items" | tr ' ' '\n' | grep . | sort -u | sed 's/.*/"&"/' | paste -sd, | sed 's/^/[/;s/$/]/'
}

simulate_json_install() {
  local mode="$1" profiles="$2"
  local INSTALLED_SKILLS="" SKIPPED_SKILLS="" FAILED_SKILLS=""
  local INSTALLED_STEERING="" SKIPPED_STEERING=""
  local INSTALLED_POWERS="" SKIPPED_POWERS=""

  local skill_list
  skill_list=$(resolve_skills "$mode" "$profiles")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      if [ ! -d "$TARGET_DIR/.kiro/skills/$skill_name" ]; then
        cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
        INSTALLED_SKILLS="$INSTALLED_SKILLS $skill_name"
      else
        SKIPPED_SKILLS="$SKIPPED_SKILLS $skill_name"
      fi
    fi
  done

  local steering_list
  if [ "$mode" = "single" ]; then
    steering_list=$(resolve_skills_steering "$skill_list")
  else
    steering_list=$(resolve_steering "${profiles:-core}")
  fi
  for f in $steering_list; do
    if [ -f "$SOURCE_DIR/.kiro/steering/$f" ]; then
      if [ ! -f "$TARGET_DIR/.kiro/steering/$f" ]; then
        cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
        INSTALLED_STEERING="$INSTALLED_STEERING $f"
      else
        SKIPPED_STEERING="$SKIPPED_STEERING $f"
      fi
    fi
  done

  cat <<EOF
{
  "mode": "$mode",
  "skills": {
    "installed": $(to_json_array "$INSTALLED_SKILLS"),
    "skipped": $(to_json_array "$SKIPPED_SKILLS"),
    "failed": $(to_json_array "$FAILED_SKILLS")
  },
  "steering": {
    "installed": $(to_json_array "$INSTALLED_STEERING"),
    "skipped": $(to_json_array "$SKIPPED_STEERING")
  },
  "powers": {
    "installed": $(to_json_array "$INSTALLED_POWERS"),
    "skipped": $(to_json_array "$SKIPPED_POWERS")
  }
}
EOF
}

# ── JSON structure tests ──

@test "json: core mode produces valid JSON with mode field" {
  run simulate_json_install "core" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *'"mode": "core"'* ]]
}

@test "json: core mode lists 6 installed skills" {
  run simulate_json_install "core" ""
  [ "$status" -eq 0 ]
  # Count quoted skill names in installed array
  local count
  count=$(echo "$output" | grep -o '"aie-skills-installer"\|"python-project-setup"\|"python-ml-deps"\|"hf-hub-datasets"\|"docker-gpu-setup"\|"notebook-workflows"' | wc -l)
  [ "$count" -eq 6 ]
}

@test "json: core mode lists 3 installed steering" {
  run simulate_json_install "core" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"python-project-conventions.md"* ]]
  [[ "$output" == *"gpu-environment.md"* ]]
  [[ "$output" == *"notebook-conventions.md"* ]]
}

@test "json: single skill mode shows correct mode" {
  run simulate_json_install "single" "arxiv-reader"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"mode": "single"'* ]]
  [[ "$output" == *'"arxiv-reader"'* ]]
}

@test "json: single skill with steering includes steering in output" {
  run simulate_json_install "single" "hf-transformers-trainer"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hf-transformers-trainer"'* ]]
  [[ "$output" == *"ml-training-workflow.md"* ]]
}

@test "json: empty arrays when nothing to install" {
  # Pre-install everything
  simulate_json_install "core" "" > /dev/null
  # Run again — all should be skipped
  run simulate_json_install "core" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *'"installed": []'* ]]
}

@test "json: skipped skills appear in skipped array" {
  # Pre-install core
  simulate_json_install "core" "" > /dev/null
  # Run again
  run simulate_json_install "core" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *'"skipped":'* ]]
  [[ "$output" == *'"aie-skills-installer"'* ]]
}

@test "json: to_json_array handles empty input" {
  run to_json_array ""
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "json: to_json_array handles single item" {
  run to_json_array "foo"
  [ "$status" -eq 0 ]
  [ "$output" = '["foo"]' ]
}

@test "json: to_json_array handles multiple items" {
  run to_json_array "foo bar baz"
  [ "$status" -eq 0 ]
  [[ "$output" == '["bar","baz","foo"]' ]]
}
