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

# ── Parse arguments ─────────────────────────────────────
TARGET=""
SELECTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global|-g)
      TARGET="$HOME"
      shift
      ;;
    --help|-h)
      echo ""
      echo "${BOLD}${SCRIPT_NAME}${RESET}"
      echo ""
      echo "Usage:"
      echo "  curl -fsSL <url>/install.sh | bash                        # Install to ./  "
      echo "  curl -fsSL <url>/install.sh | bash -s -- /path/to/project # Install to dir "
      echo "  curl -fsSL <url>/install.sh | bash -s -- --global         # Install to ~/.kiro/"
      echo ""
      echo "Options:"
      echo "  --global, -g    Install globally to ~/.kiro/"
      echo "  --help, -h      Show this help"
      echo ""
      exit 0
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

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

SUBDIRS="skills steering hooks scripts settings"
# NOTE: powers/ is intentionally excluded from default install.
# Powers contain MCP servers that require API keys/auth — auto-connecting
# causes popup prompts in Kiro when credentials aren't configured.
# Install powers via: aie-skills-installer skill (recommended) or manual copy.
for dir in $SUBDIRS; do
  mkdir -p "$TARGET/.kiro/$dir"
done

skills=0; steering=0; hooks=0; scripts=0; settings=0; skipped=0

# Skills
if [ -d "$SOURCE_KIRO/skills" ]; then
  for d in "$SOURCE_KIRO/skills"/*/; do
    [ -d "$d" ] || continue
    skill_name="$(basename "$d")"
    if [ ! -d "$TARGET/.kiro/skills/$skill_name" ]; then
      cp -r "$d" "$TARGET/.kiro/skills/$skill_name" 2>/dev/null || true
      skills=$((skills + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
fi

# Steering
# Files that should switch from "always" to "auto" when installed to other repos
AUTO_ON_INSTALL="kiro-component-creation.md"

if [ -d "$SOURCE_KIRO/steering" ]; then
  for f in "$SOURCE_KIRO/steering"/*.md; do
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/steering/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/steering/" 2>/dev/null || true

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
  done
fi

# Hooks
if [ -d "$SOURCE_KIRO/hooks" ]; then
  for f in "$SOURCE_KIRO/hooks"/*.kiro.hook; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/hooks/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/hooks/" 2>/dev/null || true
      hooks=$((hooks + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
fi

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

# ── Summary ─────────────────────────────────────────────
total=$((skills + steering + hooks + scripts + settings))

echo ""
echo "${BOLD}Installation complete!${RESET}"
echo ""
echo "  ${GREEN}Skills:${RESET}    $skills"
echo "  ${GREEN}Steering:${RESET}  $steering"
echo "  ${GREEN}Hooks:${RESET}     $hooks"
echo "  ${GREEN}Scripts:${RESET}   $scripts"
echo "  ${GREEN}Settings:${RESET}  $settings"

if [ "$skipped" -gt 0 ]; then
  echo "  ${YELLOW}Skipped:${RESET}   $skipped (already exist)"
fi

echo ""
echo "${BOLD}Total: $total components installed to $TARGET/.kiro/${RESET}"
echo ""

if [ "$total" -eq 0 ] && [ "$skipped" -gt 0 ]; then
  warn "All components already installed. Nothing to do."
  echo ""
fi

echo "Next steps:"
echo "  1. Open your project in Kiro"
echo "  2. Skills are available via ${CYAN}/${RESET} menu in chat"
echo "  3. Steering files with 'always' inclusion load automatically"
echo "  4. Toggle hooks in the ${CYAN}Agent Hooks${RESET} panel"
echo ""
echo "${YELLOW}Powers (MCP integrations) are NOT installed by default.${RESET}"
echo "  To install powers: use ${CYAN}aie-skills-installer${RESET} skill in Kiro"
echo "  Or manually copy from .kiro/powers/ in the AIE-Skills repo."
echo ""
