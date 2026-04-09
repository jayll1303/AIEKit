#!/usr/bin/env bats
# Tests for --update/--force mode
# Phase 3, Task 3.3

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

@test "update mode: overwrites existing skill" {
  # First install
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core ""

  # Modify a skill file
  echo "modified-content" > "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md"

  # Update install (force=true)
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core "" true

  # Verify content matches source (overwritten)
  local content
  content=$(cat "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md")
  [ "$content" = "mock" ]
}

@test "update mode: updated count is correct" {
  # Pre-create 3 skills
  for skill in aie-skills-installer python-project-setup python-ml-deps; do
    mkdir -p "$TARGET_DIR/.kiro/skills/$skill"
    echo "old" > "$TARGET_DIR/.kiro/skills/$skill/SKILL.md"
  done

  local result
  result=$(simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core "" true)
  local installed updated_count
  installed=$(echo "$result" | awk '{print $1}')
  updated_count=$(echo "$result" | awk '{print $3}')

  # All 6 installed (3 new + 3 overwritten)
  [ "$installed" -eq 6 ]
  # 3 were updates
  [ "$updated_count" -eq 3 ]
}

@test "update mode: without flag, existing skills are skipped" {
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core ""

  # Modify a skill
  echo "custom-content" > "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md"

  # Normal install (no force)
  simulate_skill_install "$SOURCE_DIR" "$TARGET_DIR" core ""

  # Verify custom content preserved
  local content
  content=$(cat "$TARGET_DIR/.kiro/skills/python-project-setup/SKILL.md")
  [ "$content" = "custom-content" ]
}

@test "update mode: steering files overwritten" {
  simulate_steering_install "$SOURCE_DIR" "$TARGET_DIR" "core"

  # Modify steering
  echo "custom-steering" > "$TARGET_DIR/.kiro/steering/gpu-environment.md"

  # Force update
  simulate_steering_install "$SOURCE_DIR" "$TARGET_DIR" "core" true

  # Verify overwritten
  local content
  content=$(cat "$TARGET_DIR/.kiro/steering/gpu-environment.md")
  [ "$content" != "custom-steering" ]
}
