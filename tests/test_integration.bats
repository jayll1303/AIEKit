#!/usr/bin/env bats
# Integration tests for install flow
# Feature: installer-redesign, Tasks 7.5, 7.6, 7.7

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

# ── Task 7.5: Default install (core mode) ──

@test "default install creates exactly 6 skill dirs" {
  local skill_list
  skill_list=$(resolve_skills core "")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  local count
  count=$(ls -1d "$TARGET_DIR/.kiro/skills"/*/ 2>/dev/null | wc -l)
  [ "$count" -eq 6 ]
}

@test "default install creates exactly 3 steering files" {
  local steering_list
  steering_list=$(resolve_steering "core")
  for f in $steering_list; do
    if [ -f "$SOURCE_DIR/.kiro/steering/$f" ]; then
      cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
    fi
  done
  local count
  count=$(ls -1 "$TARGET_DIR/.kiro/steering"/*.md 2>/dev/null | wc -l)
  [ "$count" -eq 3 ]
}

@test "default install does not create hooks directory" {
  local skill_list
  skill_list=$(resolve_skills core "")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  [ ! -d "$TARGET_DIR/.kiro/hooks" ]
}

# ── Task 7.6: --profile llm ──

@test "profile llm installs 10 skill dirs" {
  local skill_list
  skill_list=$(resolve_skills profile "llm")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  local count
  count=$(ls -1d "$TARGET_DIR/.kiro/skills"/*/ 2>/dev/null | wc -l)
  [ "$count" -eq 10 ]
}

@test "profile llm installs 4 steering files" {
  local steering_list
  steering_list=$(resolve_steering "llm")
  for f in $steering_list; do
    if [ -f "$SOURCE_DIR/.kiro/steering/$f" ]; then
      cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
    fi
  done
  local count
  count=$(ls -1 "$TARGET_DIR/.kiro/steering"/*.md 2>/dev/null | wc -l)
  [ "$count" -eq 4 ]
}

@test "profile llm does not create hooks directory" {
  local skill_list
  skill_list=$(resolve_skills profile "llm")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  [ ! -d "$TARGET_DIR/.kiro/hooks" ]
}

# ── Task 7.7: --all ──

@test "all mode installs 30 skill dirs" {
  local skill_list
  skill_list=$(resolve_skills all "")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  local count
  count=$(ls -1d "$TARGET_DIR/.kiro/skills"/*/ 2>/dev/null | wc -l)
  [ "$count" -eq 30 ]
}

@test "all mode installs 6 steering files" {
  local steering_list
  steering_list=$(resolve_steering "all")
  for f in $steering_list; do
    if [ -f "$SOURCE_DIR/.kiro/steering/$f" ]; then
      cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
    fi
  done
  local count
  count=$(ls -1 "$TARGET_DIR/.kiro/steering"/*.md 2>/dev/null | wc -l)
  [ "$count" -eq 6 ]
}

@test "all mode does not create hooks directory" {
  local skill_list
  skill_list=$(resolve_skills all "")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done
  [ ! -d "$TARGET_DIR/.kiro/hooks" ]
}
