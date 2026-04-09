#!/usr/bin/env bats
# Tests for resolve_steering mapping logic
# Feature: installer-redesign, Task 7.3

load 'test_helper'

@test "resolve_steering core returns exactly 3 files" {
  run resolve_steering "core"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}

@test "resolve_steering core returns correct steering files" {
  run resolve_steering "core"
  [ "$status" -eq 0 ]
  [[ "$output" == *"python-project-conventions.md"* ]]
  [[ "$output" == *"gpu-environment.md"* ]]
  [[ "$output" == *"notebook-conventions.md"* ]]
}

@test "resolve_steering llm returns 4 files (core + ml-training-workflow)" {
  run resolve_steering "llm"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 4 ]
  [[ "$output" == *"ml-training-workflow.md"* ]]
}

@test "resolve_steering speech returns 4 files (core + ml-training-workflow)" {
  run resolve_steering "speech"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 4 ]
  [[ "$output" == *"ml-training-workflow.md"* ]]
}

@test "resolve_steering inference returns 4 files (core + inference-deployment)" {
  run resolve_steering "inference"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 4 ]
  [[ "$output" == *"inference-deployment.md"* ]]
}

@test "resolve_steering llm,inference returns 5 files" {
  run resolve_steering "llm,inference"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 5 ]
  [[ "$output" == *"ml-training-workflow.md"* ]]
  [[ "$output" == *"inference-deployment.md"* ]]
}

@test "resolve_steering all returns 6 files" {
  run resolve_steering "all"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 6 ]
  [[ "$output" == *"kiro-component-creation.md"* ]]
}

@test "resolve_steering cv returns 3 files (core only)" {
  run resolve_steering "cv"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}

@test "resolve_steering rag returns 3 files (core only)" {
  run resolve_steering "rag"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}

@test "resolve_steering backend returns 3 files (core only)" {
  run resolve_steering "backend"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}
