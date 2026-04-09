#!/usr/bin/env bats
# Tests for steering frontmatter conversion (convert_steering_frontmatter)
# Phase 1, Task 1.4

load 'test_helper'

setup() {
  TEST_TMPDIR=$(mktemp -d)
  SOURCE_DIR="$TEST_TMPDIR/source"
  TARGET_DIR="$TEST_TMPDIR/target"
  create_mock_source "$SOURCE_DIR"
  mkdir -p "$TARGET_DIR/.kiro/steering"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "conversion: produces valid auto frontmatter with name and description" {
  cp "$SOURCE_DIR/.kiro/steering/kiro-component-creation.md" "$TARGET_DIR/.kiro/steering/"
  convert_steering_frontmatter "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"

  local line1 line2 line5
  line1=$(sed -n '1p' "$TARGET_DIR/.kiro/steering/kiro-component-creation.md")
  line2=$(sed -n '2p' "$TARGET_DIR/.kiro/steering/kiro-component-creation.md")
  line5=$(sed -n '5p' "$TARGET_DIR/.kiro/steering/kiro-component-creation.md")
  [ "$line1" = "---" ]
  [ "$line2" = "inclusion: auto" ]
  [ "$line5" = "---" ]

  run grep "^name: kiro-component-creation$" "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
  run grep "^description:" "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
}

@test "conversion: preserves body content after frontmatter" {
  cp "$SOURCE_DIR/.kiro/steering/kiro-component-creation.md" "$TARGET_DIR/.kiro/steering/"
  convert_steering_frontmatter "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"

  run grep "# Steering Content" "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
  run grep "Body text here." "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
}

@test "conversion: handles CRLF line endings" {
  printf '%s\r\n' "---" "inclusion: always" "---" "" "# CRLF Content" "Body." \
    > "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"

  convert_steering_frontmatter "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"

  run grep "^inclusion: auto" "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
  run grep "# CRLF Content" "$TARGET_DIR/.kiro/steering/kiro-component-creation.md"
  [ "$status" -eq 0 ]
}
