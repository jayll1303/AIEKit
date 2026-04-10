#!/usr/bin/env bats
# Tests for --skill flag (single and comma-separated skill install)
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

# ── Single skill ──

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

# ── Comma-separated skills ──

@test "comma-separated: resolve_skills returns 2 skills" {
  run resolve_skills single "ultralytics-yolo,paddleocr"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 2 ]
  [[ "$output" == *"ultralytics-yolo"* ]]
  [[ "$output" == *"paddleocr"* ]]
}

@test "comma-separated: resolve_skills returns 3 skills" {
  run resolve_skills single "ultralytics-yolo,paddleocr,experiment-tracking"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}

@test "comma-separated: duplicates are deduplicated" {
  run resolve_skills single "ultralytics-yolo,ultralytics-yolo"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 1 ]
  [ "$output" = "ultralytics-yolo" ]
}

@test "comma-separated: installs correct skill directories" {
  local skill_list
  skill_list=$(resolve_skills single "ultralytics-yolo,paddleocr")
  for skill_name in $skill_list; do
    if [ -d "$SOURCE_DIR/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
    fi
  done

  local count
  count=$(ls -1d "$TARGET_DIR/.kiro/skills"/*/ 2>/dev/null | wc -l)
  [ "$count" -eq 2 ]
  [ -d "$TARGET_DIR/.kiro/skills/ultralytics-yolo" ]
  [ -d "$TARGET_DIR/.kiro/skills/paddleocr" ]
}

# ── Single skill + steering integration ──

@test "single skill with steering: hf-transformers-trainer gets ml-training-workflow.md" {
  local skill_list
  skill_list=$(resolve_skills single "hf-transformers-trainer")
  local steering_list
  steering_list=$(resolve_skills_steering "$skill_list")

  # Install skill
  for skill_name in $skill_list; do
    cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
  done
  # Install steering
  for f in $steering_list; do
    cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
  done

  [ -d "$TARGET_DIR/.kiro/skills/hf-transformers-trainer" ]
  [ -f "$TARGET_DIR/.kiro/steering/ml-training-workflow.md" ]
}

@test "single skill without steering: arxiv-reader gets no steering" {
  local skill_list
  skill_list=$(resolve_skills single "arxiv-reader")
  local steering_list
  steering_list=$(resolve_skills_steering "$skill_list")

  cp -r "$SOURCE_DIR/.kiro/skills/arxiv-reader" "$TARGET_DIR/.kiro/skills/arxiv-reader"

  [ -d "$TARGET_DIR/.kiro/skills/arxiv-reader" ]
  [ -z "$steering_list" ]
  local steer_count
  steer_count=$(ls -1 "$TARGET_DIR/.kiro/steering"/*.md 2>/dev/null | wc -l)
  [ "$steer_count" -eq 0 ]
}

@test "comma skills with mixed steering: yolo + vllm → inference-deployment.md only" {
  local skill_list
  skill_list=$(resolve_skills single "ultralytics-yolo,vllm-tgi-inference")
  local steering_list
  steering_list=$(resolve_skills_steering "$skill_list")

  for skill_name in $skill_list; do
    cp -r "$SOURCE_DIR/.kiro/skills/$skill_name" "$TARGET_DIR/.kiro/skills/$skill_name"
  done
  for f in $steering_list; do
    cp "$SOURCE_DIR/.kiro/steering/$f" "$TARGET_DIR/.kiro/steering/"
  done

  [ -d "$TARGET_DIR/.kiro/skills/ultralytics-yolo" ]
  [ -d "$TARGET_DIR/.kiro/skills/vllm-tgi-inference" ]
  [ -f "$TARGET_DIR/.kiro/steering/inference-deployment.md" ]
  local steer_count
  steer_count=$(ls -1 "$TARGET_DIR/.kiro/steering"/*.md 2>/dev/null | wc -l)
  [ "$steer_count" -eq 1 ]
}
