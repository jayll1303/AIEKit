#!/usr/bin/env bats
# Tests for resolve_skill_steering and resolve_skills_steering
# Feature: installer-agent-alignment, Phase 5

load 'test_helper'

# ── resolve_skill_steering (single skill → steering) ──

@test "skill steering: python-project-setup → python-project-conventions.md" {
  run resolve_skill_steering "python-project-setup"
  [ "$status" -eq 0 ]
  [ "$output" = "python-project-conventions.md" ]
}

@test "skill steering: python-quality-testing → python-project-conventions.md" {
  run resolve_skill_steering "python-quality-testing"
  [ "$status" -eq 0 ]
  [ "$output" = "python-project-conventions.md" ]
}

@test "skill steering: docker-gpu-setup → gpu-environment.md" {
  run resolve_skill_steering "docker-gpu-setup"
  [ "$status" -eq 0 ]
  [ "$output" = "gpu-environment.md" ]
}

@test "skill steering: notebook-workflows → notebook-conventions.md" {
  run resolve_skill_steering "notebook-workflows"
  [ "$status" -eq 0 ]
  [ "$output" = "notebook-conventions.md" ]
}

@test "skill steering: hf-transformers-trainer → ml-training-workflow.md" {
  run resolve_skill_steering "hf-transformers-trainer"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skill steering: unsloth-training → ml-training-workflow.md" {
  run resolve_skill_steering "unsloth-training"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skill steering: k2-training-pipeline → ml-training-workflow.md" {
  run resolve_skill_steering "k2-training-pipeline"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skill steering: experiment-tracking → ml-training-workflow.md" {
  run resolve_skill_steering "experiment-tracking"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skill steering: hf-speech-to-speech-pipeline → ml-training-workflow.md" {
  run resolve_skill_steering "hf-speech-to-speech-pipeline"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skill steering: vllm-tgi-inference → inference-deployment.md" {
  run resolve_skill_steering "vllm-tgi-inference"
  [ "$status" -eq 0 ]
  [ "$output" = "inference-deployment.md" ]
}

@test "skill steering: sglang-serving → inference-deployment.md" {
  run resolve_skill_steering "sglang-serving"
  [ "$status" -eq 0 ]
  [ "$output" = "inference-deployment.md" ]
}

@test "skill steering: triton-deployment → inference-deployment.md" {
  run resolve_skill_steering "triton-deployment"
  [ "$status" -eq 0 ]
  [ "$output" = "inference-deployment.md" ]
}

@test "skill steering: arxiv-reader → empty (no steering)" {
  run resolve_skill_steering "arxiv-reader"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill steering: freqtrade → empty (no steering)" {
  run resolve_skill_steering "freqtrade"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill steering: ultralytics-yolo → empty (no steering)" {
  run resolve_skill_steering "ultralytics-yolo"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill steering: paddleocr → empty (no steering)" {
  run resolve_skill_steering "paddleocr"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── resolve_skills_steering (multiple skills → deduplicated steering) ──

@test "skills steering: single skill with steering" {
  run resolve_skills_steering "hf-transformers-trainer"
  [ "$status" -eq 0 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skills steering: two skills same steering → deduplicated" {
  run resolve_skills_steering "hf-transformers-trainer unsloth-training"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 1 ]
  [ "$output" = "ml-training-workflow.md" ]
}

@test "skills steering: two skills different steering → both" {
  run resolve_skills_steering "hf-transformers-trainer vllm-tgi-inference"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 2 ]
  [[ "$output" == *"ml-training-workflow.md"* ]]
  [[ "$output" == *"inference-deployment.md"* ]]
}

@test "skills steering: skills with no steering → empty" {
  run resolve_skills_steering "arxiv-reader freqtrade"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skills steering: mixed skills (some with, some without steering)" {
  run resolve_skills_steering "arxiv-reader hf-transformers-trainer paddleocr"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 1 ]
  [ "$output" = "ml-training-workflow.md" ]
}
