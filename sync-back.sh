#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CLAUDE_DIR="$SCRIPT_DIR/claude"
NO_COMMIT=false

info()    { echo "[sync-back] $*"; }
success() { echo "[sync-back] ✓ $*"; }
warn()    { echo "[sync-back] ⚠ $*" >&2; }
skip()    { echo "[sync-back] → $*"; }

for arg in "$@"; do
    case $arg in
        --no-commit) NO_COMMIT=true ;;
        *) warn "Unknown argument: $arg"; exit 1 ;;
    esac
done

if [ ! -d "$HOME/.claude" ]; then
    warn "~/.claude not found — is Claude Code installed?"
    exit 1
fi

# 1. settings.json
if [ -f "$HOME/.claude/settings.json" ]; then
    cp "$HOME/.claude/settings.json" "$CLAUDE_DIR/settings.json"
    success "settings.json"
else
    skip "~/.claude/settings.json not found"
fi

# 2. commands/
rsync -a --delete --exclude='.gitkeep' "$HOME/.claude/commands/" "$CLAUDE_DIR/commands/"
success "commands/"

# 3. skills/
if [ -d "$HOME/.claude/skills" ]; then
    mkdir -p "$CLAUDE_DIR/skills"
    rsync -a --delete --exclude='.gitkeep' "$HOME/.claude/skills/" "$CLAUDE_DIR/skills/"
    success "skills/"
else
    skip "~/.claude/skills/ not found — no skills to sync"
fi

# Show diff
echo ""
cd "$SCRIPT_DIR"

# intent-to-add makes new untracked files appear in git diff
git add --intent-to-add claude/settings.json claude/commands/ claude/skills/ 2>/dev/null || true

if git diff --quiet -- claude/settings.json claude/commands/ claude/skills/; then
    info "No changes to sync back."
    exit 0
fi

git diff --stat -- claude/settings.json claude/commands/ claude/skills/
echo ""
git diff -- claude/settings.json claude/commands/ claude/skills/

if [ "$NO_COMMIT" = true ]; then
    exit 0
fi

echo ""
printf "Commit these changes? [y/N] "
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    git add claude/settings.json claude/commands/ claude/skills/
    git commit -m "sync-back: update dotfiles from ~/.claude"
    success "committed"
else
    info "Changes left unstaged. Run 'git add' and 'git commit' when ready."
fi
