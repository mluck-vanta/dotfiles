# Dotfiles

Personal dotfiles for Vanta CDEs (Ona). Bootstraps shell config, AI tooling, and editor plugins.

## Quick Start

```bash
# Full setup (shell + AI + editor)
bash install.sh

# AI tooling only (safe to re-run anytime)
bash ai-setup.sh

# Cursor extensions only
bash cursor-install.sh
```

## What `install.sh` Does

1. Sets default shell to zsh
2. Symlinks dotfiles (`.zshrc`, `.gitconfig`) to `~/`
3. Symlinks `~/.snowflake/connections.toml` for the Snowflake Cursor extension
4. Installs zsh plugins (autosuggestions, completions, history-substring-search, syntax-highlighting)

After your CDE starts, run `bash ~/dotfiles/ai-setup.sh` to set up AI tooling.

## What `ai-setup.sh` Does

Bootstraps all AI tooling for Claude Code and Cursor. Idempotent — safe to re-run.

| Step | What it does |
|------|-------------|
| 0 | Installs Claude Code CLI if not on PATH |
| 1 | Symlinks `~/CLAUDE.md` and `~/.config/git/ignore` from `claude/` |
| 2 | Copies `claude/settings.json` to `~/.claude/settings.json` (first run only) |
| 3 | Copies custom slash commands from `claude/commands/` to `~/.claude/commands/` |
| 4 | Registers MCP servers (see table below) |
| 5 | Installs Claude Code plugins (superpowers, code-simplifier) |
| 6 | Installs gsync Claude Code plugin (if obsidian repo present) |
| 7 | Runs `gh auth login` and `gsync auth login` |

### MCP Servers

| Server | Default | Required Ona Secret |
|--------|---------|---------------------|
| Glean | Always on | — |
| ESLint | Always on | — |
| Context7 | Always on | — |
| Vanta | Always on | — |
| Slack | Conditional | `SLACK_BOT_TOKEN` |
| Datadog | Conditional | `DATADOG_API_KEY` (+ `DATADOG_APP_KEY`) |
| LangSmith | Conditional | `LANGSMITH_API_KEY` |
| Snowflake | Conditional | `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD` or `SNOWFLAKE_PRIVATE_KEY_PATH` |
| MongoDB | Manual | Use `/toggle-mongo-mcp enable` in obsidian repo |

### Obsidian Settings Persistence

The script symlinks `/workspaces/obsidian/.claude/settings.local.json` to `~/.claude/obsidian-settings-local.json`. This means per-project permission approvals (e.g. "always allow Bash(git diff)") survive CDE rebuilds. Update `claude/obsidian-settings-local.json` in this repo to persist approvals permanently.

## Config Files

| File | Purpose |
|------|---------|
| `claude/CLAUDE.md` | Global Claude instructions (symlinked to `~/CLAUDE.md`) |
| `claude/settings.json` | Permissions baseline — auto-allows read-only git/bash, denies destructive git ops |
| `claude/gitignore` | Global gitignore — excludes `.ai-dev/` and `.claude/settings.local.json` |
| `claude/obsidian-settings-local.json` | Per-project settings seed for obsidian monorepo |
| `claude/commands/` | Custom slash commands (copied to `~/.claude/commands/`) |
| `snowflake/connections.toml` | Snowflake connection config (symlinked to `~/.snowflake/connections.toml`) |

## Common Tasks

**Enable a conditional MCP server:**
Set the Ona secret (e.g. `SLACK_BOT_TOKEN`), rebuild your CDE, and re-run:
```bash
bash ai-setup.sh
```

**Reset permissions baseline after editing `claude/settings.json`:**
```bash
rm ~/.claude/settings.json
bash ai-setup.sh
```

**Add a custom slash command:**
Put the file in `claude/commands/`, commit, and re-run `ai-setup.sh`.

**Persist an obsidian permission approval:**
Edit `claude/obsidian-settings-local.json` to include the rule, then commit.

## Cursor Extensions

`cursor-install.sh` installs: Python, Black, ESLint, Prettier, GitLens, GraphQL, Terraform, YAML, GitHub Actions, Pretty TS Errors, Apollo, Jest Runner, Claude Code, Codex, Snowflake.
