#!/usr/bin/env bats
# Tests for resolve_skills function
# Feature: installer-redesign, Task 7.2

load 'test_helper'

@test "resolve_skills core returns exactly 6 skills" {
  run resolve_skills core ""
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 6 ]
}

@test "resolve_skills core returns the correct core skills" {
  run resolve_skills core ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"aie-skills-installer"* ]]
  [[ "$output" == *"python-project-setup"* ]]
  [[ "$output" == *"python-ml-deps"* ]]
  [[ "$output" == *"hf-hub-datasets"* ]]
  [[ "$output" == *"docker-gpu-setup"* ]]
  [[ "$output" == *"notebook-workflows"* ]]
}

@test "resolve_skills profile llm returns 10 unique skills" {
  run resolve_skills profile "llm"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | tr ' ' '\n' | grep -c .)
  [ "$count" -eq 10 ]
}

@test "resolve_skills profile llm,inference returns 16 unique skills" {
  run resolve_skills profile "llm,inference"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | tr ' ' '\n' | grep -c .)
  [ "$count" -eq 16 ]
}

@test "resolve_skills all returns 29 unique skills" {
  run resolve_skills all ""
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | tr ' ' '\n' | grep -c .)
  [ "$count" -eq 29 ]
}

@test "resolve_skills results are deduplicated" {
  run resolve_skills profile "llm"
  [ "$status" -eq 0 ]
  local total
  total=$(echo "$output" | tr ' ' '\n' | grep -c .)
  local unique
  unique=$(echo "$output" | tr ' ' '\n' | sort -u | grep -c .)
  [ "$total" -eq "$unique" ]
}
