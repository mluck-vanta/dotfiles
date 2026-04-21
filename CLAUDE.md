# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup Scripts

```bash
bash install.sh        # Full setup: zsh shell + dotfile symlinks + zsh plugins
bash ai-setup.sh       # AI tooling only (idempotent, safe to re-run)
bash sync-back.sh      # Sync ~/.claude changes back to dotfiles (see Common Tasks)
bash cursor-install.sh # Cursor editor extensions only
```

There are no tests or build steps — this repo is shell scripts and config files.

## Architecture

Two-layer setup: `install.sh` handles shell config (zsh, dotfile symlinks), then delegates to `ai-setup.sh` for AI tooling.

**`claude/` is the source of truth for AI config** — files are symlinked or copied to `~/.claude/` by `ai-setup.sh`:

- `claude/CLAUDE.md` → symlinked to `~/.claude/CLAUDE.md` (global Claude instructions for all projects)
- `claude/settings.json` → copied to `~/.claude/settings.json` on first run only (edit there for local overrides, edit here to change the baseline)
- `claude/gitignore` → symlinked to `~/.config/git/ignore` (global gitignore; excludes `.ai-dev/` and `settings.local.json`)
- `claude/commands/` → copied to `~/.claude/commands/` (custom slash commands)
- `claude/skills/` → copied to `~/.claude/skills/` (custom skills created via the superpowers writing-skills flow)
- `claude/obsidian-settings-local.json` → seeded to `~/.claude/obsidian-settings-local.json`, then symlinked from `/workspaces/obsidian/.claude/settings.local.json` to persist obsidian repo permission approvals across CDE rebuilds

## MCP Servers

Always-on: Glean, ESLint, Context7, Vanta  
Conditional (require Ona secrets): Slack (`SLACK_BOT_TOKEN`), Datadog (`DATADOG_API_KEY`), LangSmith (`LANGSMITH_API_KEY`), Snowflake (`SNOWFLAKE_ACCOUNT`/`USER`/`PASSWORD`)  
Manual: MongoDB (use `/toggle-mongo-mcp enable` in obsidian repo)

To enable a conditional server: set the Ona secret, rebuild the CDE, re-run `ai-setup.sh`.

## Common Tasks

**Reset permissions baseline** (after editing `claude/settings.json`):
```bash
rm ~/.claude/settings.json && bash ai-setup.sh
```

**Add a slash command:** put the file in `claude/commands/`, commit, re-run `ai-setup.sh`.

**Persist an obsidian permission approval permanently:** edit `claude/obsidian-settings-local.json`.

**Sync local ~/.claude changes back to dotfiles:**
```bash
bash sync-back.sh            # interactive: shows diff, prompts to commit
bash sync-back.sh --no-commit  # diff only, no commit (used by /sync-dotfiles)
# Or from within Claude: /sync-dotfiles
```
