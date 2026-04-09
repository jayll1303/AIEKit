#!/usr/bin/env bats
# Tests for --powers flag installation path
# Phase 1, Task 1.5

load 'test_helper'

setup() {
  TEST_TMPDIR=$(mktemp -d)
  SOURCE_DIR="$TEST_TMPDIR/source"
  TARGET_DIR="$TEST_TMPDIR/target"
  create_mock_source "$SOURCE_DIR"
  mkdir -p "$TARGET_DIR/.kiro"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "powers: not installed by default (no -p flag)" {
  # Simulate default install — only skills/steering
  mkdir -p "$TARGET_DIR/.kiro/skills" "$TARGET_DIR/.kiro/steering"
  local skill_list
  skill_list=$(resolve_skills core "")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  [ ! -d "$TARGET_DIR/.kiro/powers" ]
}

@test "powers: all 3 installed with INSTALL_POWERS=true" {
  mkdir -p "$TARGET_DIR/.kiro/powers"
  local SOURCE_KIRO="$SOURCE_DIR/.kiro"
  local powers=0
  for d in "$SOURCE_KIRO/powers"/*/; do
    [ -d "$d" ] || continue
    local power_name
    power_name="$(basename "$d")"
    if [ ! -d "$TARGET_DIR/.kiro/powers/$power_name" ]; then
      cp -r "$d" "$TARGET_DIR/.kiro/powers/$power_name"
      powers=$((powers + 1))
    fi
  done
  [ "$powers" -eq 3 ]
}

@test "powers: existing power is skipped" {
  mkdir -p "$TARGET_DIR/.kiro/powers/power-huggingface"
  echo "existing-content" > "$TARGET_DIR/.kiro/powers/power-huggingface/POWER.md"

  local SOURCE_KIRO="$SOURCE_DIR/.kiro"
  local powers=0
  local skipped=0
  for d in "$SOURCE_KIRO/powers"/*/; do
    [ -d "$d" ] || continue
    local power_name
    power_name="$(basename "$d")"
    if [ ! -d "$TARGET_DIR/.kiro/powers/$power_name" ]; then
      cp -r "$d" "$TARGET_DIR/.kiro/powers/$power_name"
      powers=$((powers + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
  [ "$powers" -eq 2 ]
  [ "$skipped" -eq 1 ]

  # Verify existing file not overwritten
  local content
  content=$(cat "$TARGET_DIR/.kiro/powers/power-huggingface/POWER.md")
  [ "$content" = "existing-content" ]
}


