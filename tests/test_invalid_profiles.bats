#!/usr/bin/env bats
# Tests for invalid profile rejection
# Feature: installer-redesign, Task 7.4

load 'test_helper'

@test "resolve_skills rejects 'invalid' profile" {
  run resolve_skills profile "invalid"
  [ "$status" -ne 0 ]
}

@test "resolve_skills rejects 'foo' profile" {
  run resolve_skills profile "foo"
  [ "$status" -ne 0 ]
}

@test "resolve_skills rejects 'llm,invalid' mixed profile" {
  run resolve_skills profile "llm,invalid"
  [ "$status" -ne 0 ]
}

@test "invalid profile error output contains 'Valid profiles:'" {
  run resolve_skills profile "invalid"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Valid profiles:"* ]]
}

@test "random string 'xyzzy' is rejected" {
  run resolve_skills profile "xyzzy"
  [ "$status" -ne 0 ]
}

@test "random string 'notaprofile123' is rejected" {
  run resolve_skills profile "notaprofile123"
  [ "$status" -ne 0 ]
}
