#!/bin/bash
#
# AIE-Skills Remote Installer
# One-liner: curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash
#
# Usage:
#   curl -fsSL <url>/install.sh | bash                    # Install to current directory
#   curl -fsSL <url>/install.sh | bash -s -- /path/to/dir # Install to specific directory
#   curl -fsSL <url>/install.sh | bash -s -- ~            # Install globally to ~/.kiro/
#   curl -fsSL <url>/install.sh | bash -s -- --global     # Same as above
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────
REPO_URL="https://github.com/jayll1303/AIEKit.git"
BRANCH="main"
SCRIPT_NAME="AIE-Skills Installer"

# ── Colors (if terminal supports) ───────────────────────
if [ -t 1 ] && command -v tput &>/dev/null; then
  BOLD=$(tput bold)
  GREEN=$(tput setaf 2)
  CYAN=$(tput setaf 6)
  YELLOW=$(tput setaf 3)
  RED=$(tput setaf 1)
  RESET=$(tput sgr0)
else
  BOLD="" GREEN="" CYAN="" YELLOW="" RED="" RESET=""
fi

info()  { echo "${CYAN}▸${RESET} $*"; }
ok()    { echo "${GREEN}✓${RESET} $*"; }
warn()  { echo "${YELLOW}⚠${RESET} $*"; }
err()   { echo "${RED}✗${RESET} $*" >&2; }

# ── Profile Definitions ─────────────────────────────────
# NOTE: These are duplicated from lib/profiles.sh for curl | bash compatibility.
# Keep in sync when modifying profiles.

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
  echo "text-embeddings-rag text-embeddings-inference semantic-router"
}

profile_backend() {
  echo "fastapi-at-scale opentelemetry python-quality-testing"
}

all_skills() {
  echo "$(core_skills) $(profile_llm) $(profile_inference) $(profile_speech) $(profile_cv) $(profile_rag) $(profile_backend) arxiv-reader freqtrade ml-brainstorm"
}

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

# Convert steering frontmatter from "always" to "auto" (portable, no sed -i)
convert_steering_frontmatter() {
  local file="$1"
  local tmp="${file}.tmp"

  {
    echo "---"
    echo "inclusion: auto"
    echo "name: kiro-component-creation"
    echo "description: Quy tắc tạo Kiro components (steering, skills, hooks, powers). Use when creating or modifying Kiro skills, steering files, hooks, or powers."
    echo "---"
  } > "$tmp"

  local in_frontmatter=true
  local frontmatter_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
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

# ── Skill-Level Steering Mapping ─────────────────────────
# NOTE: Duplicated from lib/profiles.sh for curl | bash compatibility.

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

# ── Parse arguments ─────────────────────────────────────
TARGET=""
INSTALL_MODE="core"    # core | profile | all | single
PROFILES=""            # comma-separated profile names
INSTALL_POWERS=false
DRY_RUN=false
FORCE_UPDATE=false
SINGLE_SKILL=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
        err "--profile requires a profile name"
        echo "Valid profiles: llm, inference, speech, cv, rag, backend"
        exit 1
      fi
      PROFILES="$2"
      INSTALL_MODE="profile"
      shift 2
      ;;
    --skill|-s)
      if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
        err "--skill requires a skill name"
        exit 1
      fi
      SINGLE_SKILL="$2"
      INSTALL_MODE="single"
      shift 2
      ;;
    --all, -a)
      INSTALL_MODE="all"
      shift
      ;;
    --global, -g)
      TARGET="$HOME"
      shift
      ;;
    --powers|-p)
      INSTALL_POWERS=true
      shift
      ;;
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --update|--force|-f)
      FORCE_UPDATE=true
      shift
      ;;
    --json|-j)
      JSON_OUTPUT=true
      shift
      ;;
    --list|-l)
      echo ""
      echo "${BOLD}Available Profiles:${RESET}"
      echo ""
      printf "  %-18s %2d skills  (default)\n" "core" "$(core_skills | wc -w)"
      printf "  %-18s %2d skills  — Fine-tune LLMs\n" "llm" "$(profile_llm | wc -w)"
      printf "  %-18s %2d skills  — Deploy LLM servers\n" "inference" "$(profile_inference | wc -w)"
      printf "  %-18s %2d skills  — Speech processing\n" "speech" "$(profile_speech | wc -w)"
      printf "  %-18s %2d skills  — Computer vision\n" "cv" "$(profile_cv | wc -w)"
      printf "  %-18s %2d skills  — RAG pipelines\n" "rag" "$(profile_rag | wc -w)"
      printf "  %-18s %2d skills  — FastAPI, monitoring\n" "backend" "$(profile_backend | wc -w)"
      echo ""
      printf "  %-18s %2d skills  — Everything\n" "all" "$(all_skills | tr ' ' '\n' | sort -u | wc -w)"
      echo ""
      echo "Core skills: $(core_skills)"
      echo ""
      echo "${BOLD}Available Skills (--skill):${RESET}"
      all_skills | tr ' ' '\n' | sort | sed 's/^/  /'
      echo ""
      exit 0
      ;;
    --help|-h)
      echo ""
      echo "${BOLD}AIE-Skills Installer${RESET}"
      echo ""
      echo "Usage:"
      echo "  install.sh                              Install core skills (default)"
      echo "  install.sh --profile llm                Install core + LLM skills"
      echo "  install.sh --profile llm,inference      Combine profiles"
      echo "  install.sh --all                        Install all 31 skills"
      echo "  install.sh --skill arxiv-reader         Install a single skill"
      echo "  install.sh --skill yolo,paddleocr       Install multiple skills"
      echo "  install.sh --skill yolo --json          Machine-readable JSON output"
      echo "  install.sh -p                           Include Powers (MCP integrations)"
      echo ""
      echo "Options:"
      echo "  --profile <names>   Install core + specified profile(s), comma-separated"
      echo "  --skill, -s <name>  Install specific skill(s) by name, comma-separated"
      echo "  --all, -a           Install all 30 skills + all steering"
      echo "  --global, -g        Install globally to ~/.kiro/"
      echo "  --powers, -p        Also install Powers (MCP integrations, disabled by default)"
      echo "  --dry-run, -n       Preview what would be installed (no changes)"
      echo "  --update, -f        Overwrite existing components (update mode)"
      echo "  --json, -j          Machine-readable JSON output (for agent/programmatic use)"
      echo "  --list, -l          List available profiles and skills"
      echo "  --help, -h          Show this help"
      echo ""
      echo "Profiles:"
      echo "  llm          Fine-tune LLMs (Trainer, Unsloth, LoRA, quantization)"
      echo "  inference    Deploy LLM servers (vLLM, SGLang, Ollama, TensorRT)"
      echo "  speech       Speech processing (Kaldi, sherpa-onnx, TTS)"
      echo "  cv           Computer vision (YOLO, PaddleOCR)"
      echo "  rag          RAG pipelines (embeddings, vector DB)"
      echo "  backend      FastAPI, OpenTelemetry, testing"
      echo ""
      echo "Default: installs 6 core skills only. Use --profile or --all for more."
      echo ""
      exit 0
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

# --all overrides --profile (but not --skill)
if [ "$INSTALL_MODE" = "all" ]; then
  PROFILES="all"
fi

# For single skill mode, set PROFILES to skill name for resolve_skills
if [ "$INSTALL_MODE" = "single" ]; then
  PROFILES="$SINGLE_SKILL"
fi

# Validate profile names early
if [ "$INSTALL_MODE" = "profile" ]; then
  IFS=',' read -ra _VALIDATE_PROFILES <<< "$PROFILES"
  for _vp in "${_VALIDATE_PROFILES[@]}"; do
    _vp=$(echo "$_vp" | tr -d ' ')
    if ! declare -f "profile_${_vp}" > /dev/null 2>&1; then
      err "Unknown profile: $_vp"
      echo "Valid profiles: llm, inference, speech, cv, rag, backend"
      exit 1
    fi
  done
fi

# Default: current directory
if [ -z "$TARGET" ]; then
  TARGET="."
fi

# Suppress human output when --json
if [ "$JSON_OUTPUT" = true ]; then
  info()  { :; }
  ok()    { :; }
  warn()  { :; }
  # err still goes to stderr for error reporting
fi

# Expand ~ to $HOME
if [ "$TARGET" = "~" ] || [[ "$TARGET" == "~/"* ]]; then
  TARGET="${TARGET/#\~/$HOME}"
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

# ── Dependency check ────────────────────────────────────
check_dep() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 is required but not installed."
    exit 1
  fi
}

check_dep git

# ── Banner ──────────────────────────────────────────────
if [ "$JSON_OUTPUT" = false ]; then
  echo ""
  echo "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
  echo "${BOLD}${CYAN}║       AIE-Skills Kiro Installer      ║${RESET}"
  echo "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
  echo ""
fi
info "Target: ${BOLD}$TARGET/.kiro/${RESET}"
case "$INSTALL_MODE" in
  core)    info "Mode: ${BOLD}core (default)${RESET}" ;;
  profile) info "Mode: ${BOLD}profile ($PROFILES)${RESET}" ;;
  all)     info "Mode: ${BOLD}all (31 skills)${RESET}" ;;
  single)  info "Mode: ${BOLD}single skill ($SINGLE_SKILL)${RESET}" ;;
esac
if [ "$DRY_RUN" = true ]; then
  info "Dry run: ${BOLD}no changes will be made${RESET}"
fi
if [ "$FORCE_UPDATE" = true ]; then
  info "Update mode: ${BOLD}existing components will be overwritten${RESET}"
fi
echo ""

# ── Clone to temp directory ─────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

info "Cloning AIE-Skills repository..."
if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMPDIR/aie-skills" 2>/dev/null; then
  err "Failed to clone repository. Check your network connection."
  exit 1
fi
ok "Repository cloned"

SOURCE_KIRO="$TMPDIR/aie-skills/.kiro"

# Validate source structure
if [ ! -d "$SOURCE_KIRO" ]; then
  err "Invalid repository structure: .kiro/ directory not found"
  exit 1
fi
for required_dir in skills steering; do
  if [ ! -d "$SOURCE_KIRO/$required_dir" ]; then
    err "Invalid repository structure: .kiro/$required_dir/ not found"
    exit 1
  fi
done

# Validate skill names exist in source (after clone)
if [ "$INSTALL_MODE" = "single" ]; then
  IFS=',' read -ra _VALIDATE_SKILLS <<< "$SINGLE_SKILL"
  for _vs in "${_VALIDATE_SKILLS[@]}"; do
    _vs=$(echo "$_vs" | tr -d ' ')
    if [ ! -d "$SOURCE_KIRO/skills/$_vs" ]; then
      err "Skill '$_vs' not found in repository"
      echo ""
      echo "Available skills:"
      ls -1 "$SOURCE_KIRO/skills/" | sed 's/^/  /'
      exit 1
    fi
  done
fi

# ── Install components ──────────────────────────────────
shopt -s nullglob

if [ "$DRY_RUN" = false ]; then
  SUBDIRS="skills steering scripts settings"
  for dir in $SUBDIRS; do
    mkdir -p "$TARGET/.kiro/$dir"
  done
fi

skills=0; steering=0; scripts=0; settings=0; skipped=0; failed=0; updated=0
INSTALLED_SKILLS=""; SKIPPED_SKILLS=""; FAILED_SKILLS=""
INSTALLED_STEERING=""; SKIPPED_STEERING=""
INSTALLED_POWERS=""; SKIPPED_POWERS=""; FAILED_POWERS=""

# Skills (selective based on mode)
SKILL_LIST=$(resolve_skills "$INSTALL_MODE" "$PROFILES")
for skill_name in $SKILL_LIST; do
  if [ -d "$SOURCE_KIRO/skills/$skill_name" ]; then
    if [ ! -d "$TARGET/.kiro/skills/$skill_name" ] || [ "$FORCE_UPDATE" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        if [ -d "$TARGET/.kiro/skills/$skill_name" ]; then
          info "Would update skill: $skill_name"
          updated=$((updated + 1))
        else
          info "Would install skill: $skill_name"
        fi
        skills=$((skills + 1))
        INSTALLED_SKILLS="$INSTALLED_SKILLS $skill_name"
      else
        if [ -d "$TARGET/.kiro/skills/$skill_name" ] && [ "$FORCE_UPDATE" = true ]; then
          rm -rf "$TARGET/.kiro/skills/$skill_name"
          updated=$((updated + 1))
        fi
        if cp -r "$SOURCE_KIRO/skills/$skill_name" "$TARGET/.kiro/skills/$skill_name" 2>/dev/null; then
          skills=$((skills + 1))
          INSTALLED_SKILLS="$INSTALLED_SKILLS $skill_name"
        else
          warn "Failed to copy skill: $skill_name"
          failed=$((failed + 1))
          FAILED_SKILLS="$FAILED_SKILLS $skill_name"
        fi
      fi
    else
      skipped=$((skipped + 1))
      SKIPPED_SKILLS="$SKIPPED_SKILLS $skill_name"
    fi
  fi
done

# Steering (selective based on mode)
if [ "$INSTALL_MODE" = "single" ]; then
  STEERING_LIST=$(resolve_skills_steering "$SKILL_LIST")
else
  STEERING_LIST=$(resolve_steering "${PROFILES:-core}")
fi

if [ -n "$STEERING_LIST" ]; then
  AUTO_ON_INSTALL="kiro-component-creation.md"
  for local_name in $STEERING_LIST; do
    if [ -f "$SOURCE_KIRO/steering/$local_name" ]; then
      if [ ! -f "$TARGET/.kiro/steering/$local_name" ] || [ "$FORCE_UPDATE" = true ]; then
        if [ "$DRY_RUN" = true ]; then
          if [ -f "$TARGET/.kiro/steering/$local_name" ]; then
            info "Would update steering: $local_name"
            updated=$((updated + 1))
          else
            info "Would install steering: $local_name"
          fi
          steering=$((steering + 1))
          INSTALLED_STEERING="$INSTALLED_STEERING $local_name"
        else
          if [ -f "$TARGET/.kiro/steering/$local_name" ] && [ "$FORCE_UPDATE" = true ]; then
            rm -f "$TARGET/.kiro/steering/$local_name"
            updated=$((updated + 1))
          fi
          if cp "$SOURCE_KIRO/steering/$local_name" "$TARGET/.kiro/steering/" 2>/dev/null; then
            # Convert dev-only steering from "always" to "auto" for target repos
            for auto_file in $AUTO_ON_INSTALL; do
              if [ "$local_name" = "$auto_file" ]; then
                convert_steering_frontmatter "$TARGET/.kiro/steering/$local_name"
                break
              fi
            done
            steering=$((steering + 1))
            INSTALLED_STEERING="$INSTALLED_STEERING $local_name"
          else
            warn "Failed to copy steering: $local_name"
            failed=$((failed + 1))
          fi
        fi
      else
        skipped=$((skipped + 1))
        SKIPPED_STEERING="$SKIPPED_STEERING $local_name"
      fi
    fi
  done
fi

# Scripts
if [ "$DRY_RUN" = false ] && [ -d "$SOURCE_KIRO/scripts" ]; then
  for f in "$SOURCE_KIRO/scripts"/*.sh; do
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/scripts/$local_name" ] || [ "$FORCE_UPDATE" = true ]; then
      if [ -f "$TARGET/.kiro/scripts/$local_name" ] && [ "$FORCE_UPDATE" = true ]; then
        updated=$((updated + 1))
      fi
      if cp "$f" "$TARGET/.kiro/scripts/" 2>/dev/null; then
        chmod +x "$TARGET/.kiro/scripts/$local_name" 2>/dev/null || true
        scripts=$((scripts + 1))
      else
        warn "Failed to copy script: $local_name"
        failed=$((failed + 1))
      fi
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# Settings
if [ "$DRY_RUN" = false ] && [ -d "$SOURCE_KIRO/settings" ]; then
  for f in "$SOURCE_KIRO/settings"/*; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/settings/$local_name" ] || [ "$FORCE_UPDATE" = true ]; then
      if [ -f "$TARGET/.kiro/settings/$local_name" ] && [ "$FORCE_UPDATE" = true ]; then
        updated=$((updated + 1))
      fi
      if cp "$f" "$TARGET/.kiro/settings/" 2>/dev/null; then
        settings=$((settings + 1))
      else
        warn "Failed to copy setting: $local_name"
        failed=$((failed + 1))
      fi
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# Powers (only with -p/--powers flag)
powers=0
if [ "$INSTALL_POWERS" = true ] && [ -d "$SOURCE_KIRO/powers" ]; then
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET/.kiro/powers"
  fi
  for d in "$SOURCE_KIRO/powers"/*/; do
    [ -d "$d" ] || continue
    power_name="$(basename "$d")"
    if [ ! -d "$TARGET/.kiro/powers/$power_name" ] || [ "$FORCE_UPDATE" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        if [ -d "$TARGET/.kiro/powers/$power_name" ]; then
          info "Would update power: $power_name"
          updated=$((updated + 1))
        else
          info "Would install power: $power_name"
        fi
        powers=$((powers + 1))
        INSTALLED_POWERS="$INSTALLED_POWERS $power_name"
      else
        if [ -d "$TARGET/.kiro/powers/$power_name" ] && [ "$FORCE_UPDATE" = true ]; then
          rm -rf "$TARGET/.kiro/powers/$power_name"
          updated=$((updated + 1))
        fi
        if cp -r "$d" "$TARGET/.kiro/powers/$power_name" 2>/dev/null; then
          powers=$((powers + 1))
          INSTALLED_POWERS="$INSTALLED_POWERS $power_name"
        else
          warn "Failed to copy power: $power_name"
          failed=$((failed + 1))
          FAILED_POWERS="$FAILED_POWERS $power_name"
        fi
      fi
    else
      skipped=$((skipped + 1))
      SKIPPED_POWERS="$SKIPPED_POWERS $power_name"
    fi
  done
fi

# ── Summary ─────────────────────────────────────────────
total=$((skills + steering + powers))

if [ "$JSON_OUTPUT" = false ]; then

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "${BOLD}Dry run complete (no changes made)${RESET}"
else
  echo "${BOLD}Installation complete!${RESET}"
fi
echo ""

case "$INSTALL_MODE" in
  core)
    ok "$skills skills installed"
    ok "$steering steering files installed"
    ;;
  profile)
    ok "$skills skills installed (core + $PROFILES)"
    ok "$steering steering files installed"
    ;;
  all)
    ok "$skills skills installed"
    ok "$steering steering files installed"
    ;;
  single)
    ok "$skills skill(s) installed ($SINGLE_SKILL)"
    if [ "$steering" -gt 0 ]; then
      ok "$steering steering file(s) installed"
    fi
    ;;
esac

if [ "$powers" -gt 0 ]; then
  ok "$powers powers installed"
fi

if [ "$updated" -gt 0 ]; then
  ok "$updated components updated (overwritten)"
fi

if [ "$skipped" -gt 0 ]; then
  echo "  ${YELLOW}Skipped:${RESET}   $skipped (already exist)"
fi

if [ "$failed" -gt 0 ]; then
  warn "$failed components failed to copy (check permissions/disk space)"
fi

echo ""

if [ "$total" -eq 0 ] && [ "$skipped" -gt 0 ]; then
  warn "All components already installed. Nothing to do."
  if [ "$FORCE_UPDATE" = false ]; then
    echo "  Use ${CYAN}--update${RESET} flag to overwrite existing components."
  fi
  echo ""
fi

# Mode-aware next steps (skip for dry-run and single skill)
if [ "$DRY_RUN" = false ] && [ "$INSTALL_MODE" != "single" ]; then
  case "$INSTALL_MODE" in
    core)
      echo "Next steps:"
      echo "  1. Open project in Kiro"
      echo "  2. Type \"install ML skills\" for project-specific recommendations"
      echo "  3. Or re-run with a profile:"
      echo ""
      echo "     install.sh --profile llm        Fine-tune LLMs (Trainer, Unsloth, LoRA)"
      echo "     install.sh --profile inference   Deploy LLM servers (vLLM, SGLang, Ollama)"
      echo "     install.sh --profile speech      Speech processing (Kaldi, sherpa-onnx)"
      echo "     install.sh --profile cv          Computer vision (YOLO, PaddleOCR)"
      echo "     install.sh --profile rag         RAG pipelines (embeddings, vector DB)"
      echo "     install.sh --profile backend     FastAPI, OpenTelemetry, testing"
      echo "     install.sh --all                 Everything (31 skills)"
      echo ""
      echo "  Combine profiles: install.sh --profile llm,inference"
      ;;
    profile)
      ;;
    all)
      ;;
  esac
fi

echo ""
echo "  💡 Use aie-skills-installer skill in Kiro for project-specific recommendations"

if [ "$INSTALL_POWERS" = true ] && [ "$powers" -gt 0 ]; then
  echo ""
  echo "${YELLOW}Powers installed with MCP servers disabled.${RESET}"
  echo "  To enable: set ${CYAN}\"disabled\": false${RESET} in each .kiro/powers/*/mcp.json"
  echo "  after configuring credentials (API keys, login, etc.)"
elif [ "$INSTALL_POWERS" = false ]; then
  echo ""
  echo "${YELLOW}Powers (MCP integrations) were not installed.${RESET}"
  echo "  To include powers: re-run with ${CYAN}-p${RESET} flag"
  echo "  Or use ${CYAN}aie-skills-installer${RESET} skill in Kiro for selective install"
fi
echo ""

fi  # end JSON_OUTPUT = false

# ── JSON Output ─────────────────────────────────────────
if [ "$JSON_OUTPUT" = true ]; then
  # Helper: convert space-separated list to JSON array
  to_json_array() {
    local items="$1"
    if [ -z "$items" ] || [ "$(echo "$items" | xargs)" = "" ]; then
      echo "[]"
      return
    fi
    echo "$items" | tr ' ' '\n' | grep . | sort -u | sed 's/.*/"&"/' | paste -sd, | sed 's/^/[/;s/$/]/'
  }

  cat <<EOF
{
  "mode": "$INSTALL_MODE",
  "skills": {
    "installed": $(to_json_array "$INSTALLED_SKILLS"),
    "skipped": $(to_json_array "$SKIPPED_SKILLS"),
    "failed": $(to_json_array "$FAILED_SKILLS")
  },
  "steering": {
    "installed": $(to_json_array "$INSTALLED_STEERING"),
    "skipped": $(to_json_array "$SKIPPED_STEERING")
  },
  "powers": {
    "installed": $(to_json_array "$INSTALLED_POWERS"),
    "skipped": $(to_json_array "$SKIPPED_POWERS")
  }
}
EOF
fi
