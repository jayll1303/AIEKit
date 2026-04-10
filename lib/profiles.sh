#!/bin/bash
# AIE-Skills — Profile definitions and resolution functions
# Sourced by install.sh and tests/test_helper.bash
#
# IMPORTANT: Keep in sync with inline definitions in install.sh
# (install.sh embeds these for curl | bash compatibility)

# ── Profile Definitions ─────────────────────────────────

core_skills() {
  echo "aie-skills-installer python-project-setup python-ml-deps hf-hub-datasets docker-gpu-setup notebook-workflows"
}

profile_llm() {
  echo "hf-transformers-trainer unsloth-training model-quantization experiment-tracking"
}

profile_inference() {
  echo "vllm-tgi-inference sglang-serving llama-cpp-inference ollama-local-llm tensorrt-llm triton-deployment"
}

profile_speech() {
  echo "k2-training-pipeline sherpa-onnx hf-speech-to-speech-pipeline openai-audio-api"
}

profile_cv() {
  echo "ultralytics-yolo paddleocr"
}

profile_rag() {
  echo "text-embeddings-rag text-embeddings-inference"
}

profile_backend() {
  echo "fastapi-at-scale opentelemetry python-quality-testing"
}

all_skills() {
  echo "$(core_skills) $(profile_llm) $(profile_inference) $(profile_speech) $(profile_cv) $(profile_rag) $(profile_backend) arxiv-reader freqtrade ml-brainstorm"
}

# ── Resolution Functions ────────────────────────────────

# Resolve skill list based on install mode
# $1 = mode (core|profile|all|single), $2 = comma-separated profiles (or skill name for single)
resolve_skills() {
  local mode="$1"
  local profiles="$2"

  case "$mode" in
    core)
      core_skills
      ;;
    single)
      echo "$profiles" | tr ',' ' ' | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs
      ;;
    profile)
      local skills="$(core_skills)"
      IFS=',' read -ra PROFILE_ARRAY <<< "$profiles"
      for p in "${PROFILE_ARRAY[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        local fn="profile_${p}"
        if declare -f "$fn" > /dev/null 2>&1; then
          skills="$skills $(${fn})"
        else
          err "Unknown profile: $p"
          echo ""
          echo "Valid profiles: llm, inference, speech, cv, rag, backend"
          exit 1
        fi
      done
      echo "$skills" | tr ' ' '\n' | sort -u | tr '\n' ' '
      ;;
    all)
      all_skills | tr ' ' '\n' | sort -u | tr '\n' ' '
      ;;
  esac
}

# Resolve steering files based on active profiles
# $1 = comma-separated profile names, "core", or "all"
resolve_steering() {
  local profiles="$1"
  local steering="python-project-conventions.md gpu-environment.md notebook-conventions.md"

  if [[ "$profiles" == *"llm"* ]] || [[ "$profiles" == *"speech"* ]] || [[ "$profiles" == "all" ]]; then
    steering="$steering ml-training-workflow.md"
  fi

  if [[ "$profiles" == *"inference"* ]] || [[ "$profiles" == "all" ]]; then
    steering="$steering inference-deployment.md"
  fi

  if [[ "$profiles" == "all" ]]; then
    steering="$steering kiro-component-creation.md"
  fi

  echo "$steering"
}

# ── Skill-Level Steering Mapping ────────────────────────

# Returns steering file(s) needed for a specific skill
# $1 = skill name
resolve_skill_steering() {
  local skill="$1"
  case "$skill" in
    python-project-setup|python-quality-testing)
      echo "python-project-conventions.md" ;;
    docker-gpu-setup)
      echo "gpu-environment.md" ;;
    notebook-workflows)
      echo "notebook-conventions.md" ;;
    hf-transformers-trainer|unsloth-training|k2-training-pipeline|experiment-tracking|hf-speech-to-speech-pipeline)
      echo "ml-training-workflow.md" ;;
    vllm-tgi-inference|sglang-serving|llama-cpp-inference|ollama-local-llm|tensorrt-llm|triton-deployment)
      echo "inference-deployment.md" ;;
    *)
      echo "" ;;
  esac
}

# Collect and deduplicate steering files for multiple skills
# $1 = space-separated skill names
resolve_skills_steering() {
  local skills="$1"
  local steering=""
  for skill in $skills; do
    local s
    s=$(resolve_skill_steering "$skill")
    if [ -n "$s" ]; then
      steering="$steering $s"
    fi
  done
  echo "$steering" | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ' | xargs
}

# ── Steering Conversion ────────────────────────────────

# Convert steering frontmatter from "always" to "auto" with name/description
# Used when installing kiro-component-creation.md to target repos
# $1 = file path to convert
convert_steering_frontmatter() {
  local file="$1"
  local tmp="${file}.tmp"

  # Write new frontmatter
  {
    echo "---"
    echo "inclusion: auto"
    echo "name: kiro-component-creation"
    echo "description: Quy tắc tạo Kiro components (steering, skills, hooks, powers). Use when creating or modifying Kiro skills, steering files, hooks, or powers."
    echo "---"
  } > "$tmp"

  # Append everything after the closing --- of original frontmatter
  local in_frontmatter=true
  local frontmatter_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip trailing CR for CRLF compatibility
    line="${line%$'\r'}"
    if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
      frontmatter_count=$((frontmatter_count + 1))
      if [ "$frontmatter_count" -ge 2 ]; then
        in_frontmatter=false
        continue
      fi
      continue
    fi
    if [ "$in_frontmatter" = false ]; then
      echo "$line"
    fi
  done < "$file" >> "$tmp"

  mv "$tmp" "$file"
}
