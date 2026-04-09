#!/usr/bin/env bats
# Tests for --skill flag (single skill install)
# Phase 3, Task 3.3

load 'test_helper'

setup() {
  TEST_TMPDIR=$(mktemp -d)
  SOURCE_DIR="$TEST_TMPDIR/source"
  TARGET_DIR="$TEST_TMPDIR/target"
  create_mock_source "$SOURCE_DIR"
  mkdir -p "$TARGET_DIR/.kiro/skills"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "single skill: resolve_skills returns exactly one skill" {
  run resolve_skills single "arxiv-reader"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 1 ]
  [ "$output" = "arxiv-reader" ]
}

@test "single skill: installs exactly one skill directory" {
  local skill_list
  skill_list=$(resolve_skills single "arxiv-reader")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done

  local count
  count=$(ls -1d "$TARGET_DIR/.kiro/skills"/*/ 2>/dev/null | wc -l)
  [ "$count" -eq 1 ]
  [ -d "$TARGET_DIR/.kiro/skills/arxiv-reader" ]
}
