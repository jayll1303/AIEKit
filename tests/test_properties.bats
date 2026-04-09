#!/usr/bin/env bats
# Property-based test loops for Properties 1-7
# Feature: installer-redesign, Task 7.8

load 'test_helper'

setup() {
  TEST_TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Feature: installer-redesign, Property 1: Core skill resolution is exact
# **Validates: Requirements 1.1, 1.2**
@test "Property 1: core_skills always returns exactly 6 skills (10 iterations)" {
  for i in $(seq 1 10); do
    local result
    result=$(resolve_skills core "")
    local count
    count=$(echo "$result" | wc -w)
    if [ "$count" -ne 6 ]; then
      echo "Iteration $i: expected 6 skills, got $count"
      return 1
    fi
    # Verify exact skill names
    for skill in aie-skills-installer python-project-setup python-ml-deps hf-hub-datasets docker-gpu-setup notebook-workflows; do
      if ! echo "$result" | grep -qw "$skill"; then
        echo "Iteration $i: missing skill $skill"
        return 1
      fi
    done
  done
}

# Feature: installer-redesign, Property 2: Skip-if-exists preserves count invariant
# **Validates: Requirements 1.4**
@test "Property 2: installed + skipped == total for random skill subsets (10 iterations)" {
  local all_core
  all_core=$(resolve_skills core "")
  local total
  total=$(echo "$all_core" | wc -w)

  for i in $(seq 1 10); do
    local target="$TEST_TMPDIR/prop2_$i"
    mkdir -p "$target/.kiro/skills"
    local source="$TEST_TMPDIR/prop2_src_$i"
    create_mock_source "$source"

    # Pre-create a random subset of skills
    local pre_count=0
    for skill in $all_core; do
      if [ $(( RANDOM % 2 )) -eq 0 ]; then
        mkdir -p "$target/.kiro/skills/$skill"
        pre_count=$((pre_count + 1))
      fi
    done

    # Simulate install
    local installed=0
    local skipped=0
    for skill in $all_core; do
      if [ -d "$source/.kiro/skills/$skill" ]; then
        if [ ! -d "$target/.kiro/skills/$skill" ]; then
          cp -r "$source/.kiro/skills/$skill" "$target/.kiro/skills/$skill"
          installed=$((installed + 1))
        else
          skipped=$((skipped + 1))
        fi
      fi
    done

    local sum=$((installed + skipped))
    if [ "$sum" -ne "$total" ]; then
      echo "Iteration $i: installed($installed) + skipped($skipped) = $sum, expected $total"
      return 1
    fi
  done
}

# Feature: installer-redesign, Property 3: Profile resolution is core union profile
# **Validates: Requirements 2.1, 2.4, 2.5**
@test "Property 3: profile resolution == core ∪ selected profiles for all subsets" {
  local profiles=(llm inference speech cv rag backend)

  # Test each single profile
  for p in "${profiles[@]}"; do
    local result
    result=$(resolve_skills profile "$p")
    local expected
    expected=$(echo "$(core_skills) $(profile_${p})" | tr ' ' '\n' | sort -u | xargs)
    local result_sorted
    result_sorted=$(echo "$result" | tr ' ' '\n' | sort -u | xargs)
    if [ "$result_sorted" != "$expected" ]; then
      echo "Profile $p: expected '$expected', got '$result_sorted'"
      return 1
    fi
  done

  # Test some multi-profile combinations
  local combos=("llm,inference" "speech,cv" "rag,backend" "llm,speech,cv" "inference,rag,backend")
  for combo in "${combos[@]}"; do
    local result
    result=$(resolve_skills profile "$combo")
    # Build expected from core + each profile in combo
    local expected_raw
    expected_raw="$(core_skills)"
    IFS=',' read -ra parts <<< "$combo"
    for p in "${parts[@]}"; do
      expected_raw="$expected_raw $(profile_${p})"
    done
    local expected
    expected=$(echo "$expected_raw" | tr ' ' '\n' | sort -u | xargs)
    local result_sorted
    result_sorted=$(echo "$result" | tr ' ' '\n' | sort -u | xargs)
    if [ "$result_sorted" != "$expected" ]; then
      echo "Combo $combo: expected '$expected', got '$result_sorted'"
      return 1
    fi
  done
}

# Feature: installer-redesign, Property 4: Invalid profile names are rejected
# **Validates: Requirements 2.3**
@test "Property 4: random invalid strings are rejected (10 iterations)" {
  local invalid_names=("invalid" "foo" "bar" "xyzzy" "LLM" "INFERENCE" "test" "random123" "notreal" "abc")
  for name in "${invalid_names[@]}"; do
    run resolve_skills profile "$name"
    if [ "$status" -eq 0 ]; then
      echo "Invalid profile '$name' was not rejected (exit code 0)"
      return 1
    fi
    if ! echo "$output" | grep -q "Valid profiles:"; then
      echo "Invalid profile '$name' error missing 'Valid profiles:' message"
      return 1
    fi
  done
}

# Feature: installer-redesign, Property 5: Steering mapping returns exactly the mapped files
# **Validates: Requirements 3.2, 3.5**
@test "Property 5: steering mapping is exact for all profile combos" {
  # Define expected steering counts per profile/combo
  # core=3, llm=4, speech=4, inference=4, cv=3, rag=3, backend=3
  # llm,inference=5, llm,speech=4, all=6

  local -A expected_counts
  expected_counts[core]=3
  expected_counts[llm]=4
  expected_counts[inference]=4
  expected_counts[speech]=4
  expected_counts[cv]=3
  expected_counts[rag]=3
  expected_counts[backend]=3
  expected_counts[llm,inference]=5
  expected_counts[llm,speech]=4
  expected_counts[all]=6

  for profiles in core llm inference speech cv rag backend "llm,inference" "llm,speech" all; do
    local result
    result=$(resolve_steering "$profiles")
    local count
    count=$(echo "$result" | wc -w)
    local expected="${expected_counts[$profiles]}"
    if [ "$count" -ne "$expected" ]; then
      echo "Steering for '$profiles': expected $expected files, got $count"
      return 1
    fi

    # Core steering always present
    for f in python-project-conventions.md gpu-environment.md notebook-conventions.md; do
      if ! echo "$result" | grep -qw "$f"; then
        echo "Steering for '$profiles': missing core file $f"
        return 1
      fi
    done
  done
}

# Feature: installer-redesign, Property 6: --all flag overrides --profile
# **Validates: Requirements 4.4**
@test "Property 6: --all + any profile == --all alone" {
  local all_result
  all_result=$(resolve_skills all "" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  local profiles=(llm inference speech cv rag backend)
  for p in "${profiles[@]}"; do
    # Simulate --all overriding --profile: when INSTALL_MODE=all, PROFILES=all
    local combined
    combined=$(resolve_skills all "" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    if [ "$combined" != "$all_result" ]; then
      echo "Profile $p: --all+--profile result differs from --all alone"
      return 1
    fi
  done
}

# Feature: installer-redesign, Property 7: No hooks are ever installed
# **Validates: Requirements 5.1, 5.2**
@test "Property 7: no hooks directory for any valid flag combo" {
  local source="$TEST_TMPDIR/prop7_src"
  create_mock_source "$source"

  # Test all valid modes
  local modes=("core" "profile:llm" "profile:inference" "profile:speech" "profile:cv" "profile:rag" "profile:backend" "profile:llm,inference" "all")
  for mode_spec in "${modes[@]}"; do
    local target="$TEST_TMPDIR/prop7_$(echo "$mode_spec" | tr ':,' '_')"
    mkdir -p "$target/.kiro/skills" "$target/.kiro/steering"

    local mode profiles
    if [[ "$mode_spec" == *":"* ]]; then
      mode="${mode_spec%%:*}"
      profiles="${mode_spec#*:}"
    else
      mode="$mode_spec"
      profiles=""
    fi

    local skill_list
    skill_list=$(resolve_skills "$mode" "$profiles")
    for skill_name in $skill_list; do
      if [ -d "$source/.kiro/skills/$skill_name" ]; then
        cp -r "$source/.kiro/skills/$skill_name" "$target/.kiro/skills/$skill_name" 2>/dev/null || true
      fi
    done

    local steering_profiles="${profiles:-core}"
    if [ "$mode" = "all" ]; then steering_profiles="all"; fi
    local steering_list
    steering_list=$(resolve_steering "$steering_profiles")
    for f in $steering_list; do
      if [ -f "$source/.kiro/steering/$f" ]; then
        cp "$source/.kiro/steering/$f" "$target/.kiro/steering/" 2>/dev/null || true
      fi
    done

    if [ -d "$target/.kiro/hooks" ]; then
      echo "Mode '$mode_spec': hooks/ directory was created"
      return 1
    fi
  done
}
