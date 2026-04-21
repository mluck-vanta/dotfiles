# Design: Sync Local ~/.claude Changes Back to Dotfiles

**Date:** 2026-04-21  
**Status:** Approved

## Problem

`ai-setup.sh` is a one-way pipe: dotfiles → `~/.claude/`. When Claude modifies `~/.claude/settings.json` in a devbox (adding permissions, changing modes), creates slash commands in `~/.claude/commands/`, or generates custom skills in `~/.claude/skills/`, those changes are lost on CDE rebuild. There is no way to promote them back to the dotfiles repo.

## Scope

Three artifact types can drift and need syncing back:

| Live location | Dotfiles location | Notes |
|---|---|---|
| `~/.claude/settings.json` | `claude/settings.json` | Copied on first run by ai-setup.sh, drifts after |
| `~/.claude/commands/` | `claude/commands/` | Copied by ai-setup.sh, new commands accumulate locally |
| `~/.claude/skills/` | `claude/skills/` | New directory; custom skills created via writing-skills skill |

**Excluded from sync:**
- `CLAUDE.md` — symlinked, never drifts
- `gitignore` — symlinked, never drifts
- `obsidian-settings-local.json` — intentionally per-CDE, not synced back

## Architecture

Two components, each doing what it does best:

### `sync-back.sh` (shell script)

Reliable, debuggable core. Handles all file operations deterministically. Follows the same style as `ai-setup.sh` (info/success/skip/warn helpers, idempotent).

**Flags:**
- Default (no flags): copy files, show diff, prompt "Commit? [y/N]", commit if yes
- `--no-commit`: copy files and show diff, then exit — used by the slash command so Claude can write the commit message

**Flow:**
1. Validate `~/.claude/` exists
2. `cp ~/.claude/settings.json claude/settings.json`
3. `rsync -a --delete --exclude='.gitkeep' ~/.claude/commands/ claude/commands/`
4. `mkdir -p claude/skills/` then `rsync -a --delete ~/.claude/skills/ claude/skills/` (no-op if `~/.claude/skills/` is empty)
5. `git diff --stat` + `git diff` to show what changed
6. If `--no-commit`: exit 0
7. Prompt "Commit these changes? [y/N]" — if yes, stage `claude/settings.json claude/commands/ claude/skills/` and commit

Script does **not** push — pushing stays an intentional manual step.

### `claude/commands/sync-dotfiles.md` (slash command)

Instructs Claude to:
1. Run `bash ~/dotfiles/sync-back.sh --no-commit`
2. Read the `git diff` output
3. Write a commit message describing the semantic changes (what settings were added/changed, what commands or skills were created)
4. Present the message for approval, then commit

Deployed automatically by the existing `ai-setup.sh` step 3 (copies `claude/commands/` → `~/.claude/commands/`).

## Changes to `ai-setup.sh`

Add a new step after step 3 (commands) to push skills outward:

```
# 3b. Skills
setup_skills() {
    mkdir -p "$HOME/.claude/skills"
    if [ -n "$(find "$CLAUDE_DIR/skills" -not -name '.gitkeep' -type f 2>/dev/null)" ]; then
        cp -r "$CLAUDE_DIR/skills/." "$HOME/.claude/skills/"
        success "skills → ~/.claude/skills/"
    else
        skip "no custom skills yet"
    fi
}
```

## New Files

- `sync-back.sh` — sync script
- `claude/commands/sync-dotfiles.md` — slash command
- `claude/skills/.gitkeep` — placeholder so the directory is tracked

## Non-Goals

- Automatic/scheduled sync (intentional trigger only)
- Syncing MCP server registrations (those are registered via `claude mcp add` and re-run via `ai-setup.sh`)
- Syncing plugin installations (same — reinstalled via `ai-setup.sh`)
