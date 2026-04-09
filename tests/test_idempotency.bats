#!/usr/bin/env bats
# Tests for installation idempotency + skip-if-exists
# Phase 1, Task 1.6

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

@test "idempotency: second install skips all, files unchanged" {
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core ""
  local content_before
  content_before=$(cat "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md")

  local result2
  result2=$(simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core "")
  local installed2 skipped2
  installed2=$(echo "$result2" | awk '{print $1}')
  skipped2=$(echo "$result2" | awk '{print $2}')
  [ "$installed2" -eq 0 ]
  [ "$skipped2" -eq 6 ]

  local content_after
  content_after=$(cat "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md")
  [ "$content_before" = "$content_after" ]
}

@test "idempotency: adding profile after core installs only new skills" {
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core ""

  local result
  result=$(simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" profile "llm")
  local installed skipped
  installed=$(echo "$result" | awk '{print $1}')
  skipped=$(echo "$result" | awk '{print $2}')
  [ "$installed" -eq 4 ]
  [ "$skipped" -eq 6 ]
}

@test "idempotency: steering skip with partial pre-existing" {
  # Pre-create 2 of 3 core steering files with custom content
  echo "custom-content" > "$TARGET_DIR/.kiro/steering/gpu-environment.md"
  echo "custom-content" > "$TARGET_DIR/.kiro/steering/notebook-conventions.md"

  local result
  result=$(simulate_steering_install "$SOURCE_DIR" "$TARGET_DIR" "core")
  local installed skipped
  installed=$(echo "$result" | awk '{print $1}')
  skipped=$(echo "$result" | awk '{print $2}')
  [ "$installed" -eq 1 ]
  [ "$skipped" -eq 2 ]

  # Verify custom content preserved
  local content
  content=$(cat "$TARGET_DIR/.kiro/steering/gpu-environment.md")
  [ "$content" = "custom-content" ]
}
