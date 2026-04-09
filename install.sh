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

# Core set — always installed
core_skills() {
  echo "aie-skills-installer python-project-setup python-ml-deps hf-hub-datasets docker-gpu-setup notebook-workflows"
}

# Profile: llm
profile_llm() {
  echo "hf-transformers-trainer unsloth-training model-quantization experiment-tracking"
}

# Profile: inference
profile_inference() {
  echo "vllm-tgi-inference sglang-serving llama-cpp-inference ollama-local-llm tensorrt-llm triton-deployment"
}

# Profile: speech
profile_speech() {
  echo "k2-training-pipeline sherpa-onnx hf-speech-to-speech-pipeline openai-audio-api"
}

# Profile: cv
profile_cv() {
  echo "ultralytics-yolo paddleocr"
}

# Profile: rag
profile_rag() {
  echo "text-embeddings-rag text-embeddings-inference"
}

# Profile: backend
profile_backend() {
  echo "fastapi-at-scale opentelemetry python-quality-testing"
}

# All skills (union of everything + standalone)
all_skills() {
  echo "$(core_skills) $(profile_llm) $(profile_inference) $(profile_speech) $(profile_cv) $(profile_rag) $(profile_backend) arxiv-reader freqtrade ml-brainstorm"
}

# Resolve skill list based on install mode
# $1 = mode (core|profile|all), $2 = comma-separated profiles
resolve_skills() {
  local mode="$1"
  local profiles="$2"

  case "$mode" in
    core)
      core_skills
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

# ── Parse arguments ─────────────────────────────────────
TARGET=""
INSTALL_MODE="core"    # core | profile | all
PROFILES=""            # comma-separated profile names
INSTALL_POWERS=false

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
    --all|-a)
      INSTALL_MODE="all"
      shift
      ;;
    --global|-g)
      TARGET="$HOME"
      shift
      ;;
    --powers|-p)
      INSTALL_POWERS=true
      shift
      ;;
    --help|-h)
      echo ""
      echo "${BOLD}AIE-Skills Installer${RESET}"
      echo ""
      echo "Usage:"
      echo "  install.sh                              Install core skills (default)"
      echo "  install.sh --profile llm                Install core + LLM skills"
      echo "  install.sh --profile llm,inference      Combine profiles"
      echo "  install.sh --all                        Install all 30 skills"
      echo "  install.sh -p                           Include Powers (MCP integrations)"
      echo ""
      echo "Options:"
      echo "  --profile <names>   Install core + specified profile(s), comma-separated"
      echo "  --all, -a           Install all 30 skills + all steering"
      echo "  --global, -g        Install globally to ~/.kiro/"
      echo "  --powers, -p        Also install Powers (MCP integrations, disabled by default)"
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

# --all overrides --profile
if [ "$INSTALL_MODE" = "all" ]; then
  PROFILES="all"
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
echo ""
echo "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
echo "${BOLD}${CYAN}║       AIE-Skills Kiro Installer      ║${RESET}"
echo "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""
info "Target: ${BOLD}$TARGET/.kiro/${RESET}"
case "$INSTALL_MODE" in
  core)    info "Mode: ${BOLD}core (default)${RESET}" ;;
  profile) info "Mode: ${BOLD}profile ($PROFILES)${RESET}" ;;
  all)     info "Mode: ${BOLD}all (30 skills)${RESET}" ;;
esac
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

if [ ! -d "$SOURCE_KIRO" ]; then
  err "Invalid repository structure: .kiro/ directory not found"
  exit 1
fi

# ── Install components ──────────────────────────────────
shopt -s nullglob

SUBDIRS="skills steering scripts settings"
# NOTE: powers/ is intentionally excluded from default install.
# Powers contain MCP servers that require API keys/auth — auto-connecting
# causes popup prompts in Kiro when credentials aren't configured.
# Install powers via: aie-skills-installer skill (recommended) or manual copy.
for dir in $SUBDIRS; do
  mkdir -p "$TARGET/.kiro/$dir"
done

skills=0; steering=0; scripts=0; settings=0; skipped=0

# Skills (selective based on mode)
SKILL_LIST=$(resolve_skills "$INSTALL_MODE" "$PROFILES")
for skill_name in $SKILL_LIST; do
  if [ -d "$SOURCE_KIRO/skills/$skill_name" ]; then
    if [ ! -d "$TARGET/.kiro/skills/$skill_name" ]; then
      cp -r "$SOURCE_KIRO/skills/$skill_name" "$TARGET/.kiro/skills/$skill_name" 2>/dev/null || true
      skills=$((skills + 1))
    else
      skipped=$((skipped + 1))
    fi
  fi
done

# Steering (selective based on mode)
AUTO_ON_INSTALL="kiro-component-creation.md"
STEERING_LIST=$(resolve_steering "${PROFILES:-core}")
for local_name in $STEERING_LIST; do
  if [ -f "$SOURCE_KIRO/steering/$local_name" ]; then
    if [ ! -f "$TARGET/.kiro/steering/$local_name" ]; then
      cp "$SOURCE_KIRO/steering/$local_name" "$TARGET/.kiro/steering/" 2>/dev/null || true

      # Convert dev-only steering from "always" to "auto" for target repos
      for auto_file in $AUTO_ON_INSTALL; do
        if [ "$local_name" = "$auto_file" ]; then
          sed -i 's/^inclusion: always$/inclusion: auto\nname: kiro-component-creation\ndescription: Quy tắc tạo Kiro components (steering, skills, hooks, powers). Use when creating or modifying Kiro skills, steering files, hooks, or powers./' \
            "$TARGET/.kiro/steering/$local_name"
          break
        fi
      done

      steering=$((steering + 1))
    else
      skipped=$((skipped + 1))
    fi
  fi
done

# Scripts
if [ -d "$SOURCE_KIRO/scripts" ]; then
  for f in "$SOURCE_KIRO/scripts"/*.sh; do
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/scripts/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/scripts/" 2>/dev/null || true
      chmod +x "$TARGET/.kiro/scripts/$local_name" 2>/dev/null || true
      scripts=$((scripts + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# Settings
if [ -d "$SOURCE_KIRO/settings" ]; then
  for f in "$SOURCE_KIRO/settings"/*; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/settings/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/settings/" 2>/dev/null || true
      settings=$((settings + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# Powers (only with -p/--powers flag)
powers=0
if [ "$INSTALL_POWERS" = true ] && [ -d "$SOURCE_KIRO/powers" ]; then
  mkdir -p "$TARGET/.kiro/powers"
  for d in "$SOURCE_KIRO/powers"/*/; do
    [ -d "$d" ] || continue
    power_name="$(basename "$d")"
    if [ ! -d "$TARGET/.kiro/powers/$power_name" ]; then
      cp -r "$d" "$TARGET/.kiro/powers/$power_name" 2>/dev/null || true
      powers=$((powers + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# ── Summary ─────────────────────────────────────────────
total=$((skills + steering + powers))

echo ""
echo "${BOLD}Installation complete!${RESET}"
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
esac

if [ "$powers" -gt 0 ]; then
  ok "$powers powers installed"
fi

if [ "$skipped" -gt 0 ]; then
  echo "  ${YELLOW}Skipped:${RESET}   $skipped (already exist)"
fi

echo ""

if [ "$total" -eq 0 ] && [ "$skipped" -gt 0 ]; then
  warn "All components already installed. Nothing to do."
  echo ""
fi

# Mode-aware next steps
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
    echo "     install.sh --all                 Everything (30 skills)"
    echo ""
    echo "  Combine profiles: install.sh --profile llm,inference"
    ;;
  profile)
    ;;
  all)
    ;;
esac

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
