#!/bin/bash
#
# AIE-Skills Kiro Installer
# Installs AI/ML Engineering skills, steering, hooks, and scripts into a Kiro project.
#
# Usage:
#   ./install.sh              # Install to current directory
#   ./install.sh /path/to/dir # Install to specific directory
#   ./install.sh ~            # Install globally to ~/.kiro/
#
set -euo pipefail

# When globs match nothing, expand to empty list instead of the literal pattern
shopt -s nullglob

# Resolve the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The script lives inside .kiro/, so SCRIPT_DIR *is* the source.
SOURCE_KIRO="$SCRIPT_DIR"

# Target directory: argument or current working directory
TARGET="${1:-.}"

# Expand ~ to $HOME
if [ "$TARGET" = "~" ] || [[ "$TARGET" == "~/"* ]]; then
  TARGET="${TARGET/#\~/$HOME}"
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

echo "AIE-Skills Kiro Installer"
echo "========================="
echo ""
echo "Source:  $SOURCE_KIRO"
echo "Target:  $TARGET/.kiro/"
echo ""

# Subdirectories to create and populate
SUBDIRS="skills steering hooks scripts settings"

# Create all required .kiro/ subdirectories
for dir in $SUBDIRS; do
  mkdir -p "$TARGET/.kiro/$dir"
done

# Counters for summary
skills=0; steering=0; hooks=0; scripts=0; settings=0

# Copy skills (directories with SKILL.md + references/)
if [ -d "$SOURCE_KIRO/skills" ]; then
  for d in "$SOURCE_KIRO/skills"/*/; do
    [ -d "$d" ] || continue
    skill_name="$(basename "$d")"
    if [ ! -d "$TARGET/.kiro/skills/$skill_name" ]; then
      cp -r "$d" "$TARGET/.kiro/skills/$skill_name" 2>/dev/null || true
      skills=$((skills + 1))
    fi
  done
fi

# Copy steering files (markdown)
if [ -d "$SOURCE_KIRO/steering" ]; then
  for f in "$SOURCE_KIRO/steering"/*.md; do
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/steering/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/steering/" 2>/dev/null || true
      steering=$((steering + 1))
    fi
  done
fi

# Copy hooks (.kiro.hook files)
if [ -d "$SOURCE_KIRO/hooks" ]; then
  for f in "$SOURCE_KIRO/hooks"/*.kiro.hook; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/hooks/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/hooks/" 2>/dev/null || true
      hooks=$((hooks + 1))
    fi
  done
fi

# Copy scripts (shell scripts) and make executable
if [ -d "$SOURCE_KIRO/scripts" ]; then
  for f in "$SOURCE_KIRO/scripts"/*.sh; do
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/scripts/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/scripts/" 2>/dev/null || true
      chmod +x "$TARGET/.kiro/scripts/$local_name" 2>/dev/null || true
      scripts=$((scripts + 1))
    fi
  done
fi

# Copy settings (example files)
if [ -d "$SOURCE_KIRO/settings" ]; then
  for f in "$SOURCE_KIRO/settings"/*; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    if [ ! -f "$TARGET/.kiro/settings/$local_name" ]; then
      cp "$f" "$TARGET/.kiro/settings/" 2>/dev/null || true
      settings=$((settings + 1))
    fi
  done
fi

# Installation summary
echo "Installation complete!"
echo ""
echo "Components installed:"
echo "  Skills:    $skills"
echo "  Steering:  $steering"
echo "  Hooks:     $hooks"
echo "  Scripts:   $scripts"
echo "  Settings:  $settings"
echo ""
echo "Next steps:"
echo "  1. Open your project in Kiro"
echo "  2. Skills are available via / menu in chat"
echo "  3. Steering files with 'always' inclusion load automatically"
echo "  4. Toggle hooks in the Agent Hooks panel"
echo "  5. If settings/mcp.json.example exists, copy desired MCP servers to settings/mcp.json"
