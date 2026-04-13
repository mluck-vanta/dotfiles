# AI Dotfiles Setup Design

**Date:** 2026-04-13
**Status:** Approved

## Context

Vanta CDEs (Ona) have no persistent home directory between rebuilds (EFS beta not in use). Every new CDE starts fresh — Claude Code configuration, MCP servers, auth tokens, and plugins are all lost. The goal is to bootstrap all AI tooling automatically from the dotfiles repo so a fresh CDE is fully configured after running `install.sh`.

**Primary tool:** Claude Code (CLI). Cursor used occasionally.

---

## Repository Structure

```
dotfiles/
├── .zshrc                  (existing, auto-symlinked by install.sh)
├── .gitconfig              (existing, auto-symlinked — add core.excludesFile)
├── install.sh              (add: call ai-setup.sh at end, remove Glean-for-Cursor line)
├── cursor-install.sh       (existing, unchanged)
├── ai-setup.sh             (NEW)
└── claude/
    ├── CLAUDE.md           → symlinked to ~/CLAUDE.md
    ├── settings.json       → copied to ~/.claude/settings.json (only if not present)
    ├── obsidian-settings-local.json  → symlinked to /workspaces/obsidian/.claude/settings.local.json
    ├── gitignore           → symlinked to ~/.config/git/ignore
    └── commands/           → contents copied to ~/.claude/commands/
```

---

## `ai-setup.sh`

A dedicated script for all AI tooling setup. Called by `install.sh` at the end. Safe to re-run independently (all steps are idempotent or skip-if-exists).

### Execution order

**0. Install Claude Code CLI**
- Check if `claude` is already on `$PATH`; skip if present
- Install via: `curl -fsSL https://claude.ai/install.sh | sh`
- This ensures `ai-setup.sh` is safe to run on a completely fresh CDE before Claude Code has been installed

**1. Symlinks**
- `~/CLAUDE.md` → `dotfiles/claude/CLAUDE.md`
- `~/.config/git/ignore` → `dotfiles/claude/gitignore`
- `/workspaces/obsidian/.claude/settings.local.json` → `~/.claude/obsidian-settings-local.json`
  (Kevin Royer's trick: persists per-project approved permissions across CDE rebuilds)
  Only created if `/workspaces/obsidian` exists; skipped with a warning otherwise.

**2. Claude settings**
- Copy `dotfiles/claude/settings.json` to `~/.claude/settings.json` — skipped if the file already exists, so Claude's runtime writes are preserved on re-runs.
  To pick up changes to `claude/settings.json` after the initial install: delete `~/.claude/settings.json` and re-run `ai-setup.sh`.

**3. Slash commands**
- Copy contents of `dotfiles/claude/commands/` to `~/.claude/commands/`
- Infrastructure is in place; directory starts empty and is populated over time

**4. MCP servers**
Each configured with `claude mcp add --scope user ... || true` (safe to re-run).

| Server | Default | Condition / Command |
|--------|---------|---------------------|
| Glean | On | `claude mcp add --transport http --scope user glean_default https://vanta-be.glean.com/mcp/default` |
| Slack | On | Skip with warning if `$SLACK_BOT_TOKEN` Ona secret is absent; `claude mcp add --transport stdio --scope user slack -- npx -y @modelcontextprotocol/server-slack` (token passed via env) |
| ESLint | On | `claude mcp add --transport stdio --scope user eslint -- npx @eslint/mcp@latest` |
| Context7 | On | `claude mcp add --transport stdio --scope user context7 -- npx -y @upstash/context7-mcp` |
| Vanta Remote MCP | On | `claude mcp add --transport http --scope user vanta https://mcp.vanta.com/mcp` |
| Datadog | Off | Skip unless `$DATADOG_API_KEY` present. `/toggle-datadog-mcp` is an existing command in `/workspaces/obsidian/.claude/commands/` — not created by this setup. |
| MongoDB | Off | Skip unconditionally. `/toggle-mongo-mcp` is an existing command in `/workspaces/obsidian/.claude/commands/` — not created by this setup. |
| LangSmith | Off | Skip unless `$LANGSMITH_API_KEY` present; `claude mcp add --transport stdio --scope user LangSmith --env LANGSMITH_API_KEY="$LANGSMITH_API_KEY" -- uvx langsmith-mcp-server` |
| Snowflake | Off | Skip unless `$SNOWFLAKE_ACCOUNT`, `$SNOWFLAKE_USER`, and `$SNOWFLAKE_PASSWORD` (or `$SNOWFLAKE_PRIVATE_KEY_PATH`) Ona secrets are present; `claude mcp add --transport stdio --scope user snowflake -- npx -y @modelcontextprotocol/server-snowflake` with credentials passed via env |

Also: sync Glean + Atlassian MCP entries to `~/.cursor/mcp.json` (replaces the existing line in `install.sh`).

**5. Claude Code plugins**
```bash
claude plugin install superpowers@claude-plugins-official || true
claude plugin install code-simplifier@claude-plugins-official || true
```

**6. gsync Claude Code plugin**
```bash
cd /workspaces/obsidian && yarn workspace @vanta/gsync claude:install || true
```

**7. Auth bootstrap**

The script continues past auth failures (printing a warning) so a single failed auth doesn't abort the whole setup.

`gh` (GitHub CLI):
- Run `gh auth status` first; skip if already authenticated
- If `$GITHUB_TOKEN` env var is set: `echo "$GITHUB_TOKEN" | gh auth login --with-token`
- Otherwise: `gh auth login --hostname github.com` (interactive device flow)
- Print clear status so the user knows if manual action is needed

`gsync` (Google Docs sync):
- Run `gsync auth status` first; skip if already authenticated
- Credentials expected at `/usr/local/secrets/gsync_google_oauth` (Ona secret — format: Google OAuth JSON)
- If credentials present: run `gsync auth login` (browser OAuth flow)
- If credentials missing: print instructions to retrieve from 1Password (link in gsync README)

---

## `claude/CLAUDE.md`

Global instructions for Claude Code across all repos.

**`.ai-dev` directive** (from Vanta Agentic Planning Guru card):
Always store plans, designs, and research in `.ai-dev/` directories placed as close as possible to the relevant code. Never commit these files — they are covered by the global gitignore.

Example path: `packages/my-package/src/.ai-dev/plans/2026-04-13-support-new-feature.md`

**Personal working style:**
- Terse responses; no trailing "here's what I did" summaries
- Prefer editing existing files over creating new ones
- No speculative abstractions or features beyond what was asked

---

## `claude/settings.json` — Permissions baseline

Based on Lucas Liepert's setup shared in #vanta-internal-ai. Pre-approves read-only operations to avoid constant prompting; denies all destructive git ops.

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(ls /workspaces/obsidian*)",
      "Bash(cat /workspaces/obsidian*)",
      "Bash(head /workspaces/obsidian*)",
      "Bash(tail /workspaces/obsidian*)",
      "Bash(grep /workspaces/obsidian*)",
      "Bash(find /workspaces/obsidian*)",
      "mcp__ide__getDiagnostics",
      "mcp__glean_default__search",
      "mcp__glean_default__read_document",
      "mcp__glean_default__chat"
    ],
    "deny": [
      "Bash(git add:*)",
      "Bash(git commit*)",
      "Bash(git push*)",
      "Bash(git reset*)",
      "Bash(git switch*)",
      "Bash(git checkout*)",
      "Bash(git merge*)",
      "Bash(git rebase*)",
      "Bash(git cherry-pick*)",
      "Bash(git stash*)",
      "Bash(git clean*)",
      "Bash(git revert*)",
      "Bash(git branch -d*)",
      "Bash(git branch -D*)"
    ]
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true
  }
}
```

---

## `claude/gitignore` — Global gitignore

Symlinked to `~/.config/git/ignore`. Also requires adding `core.excludesFile = ~/.config/git/ignore` to `.gitconfig`.

```
**/.claude/settings.local.json
**/.ai-dev
```

---

## `claude/obsidian-settings-local.json`

Per-project settings for the Obsidian monorepo. Starts as an empty permissions object — populated over time as you approve tool calls you want persisted. Symlinked from `/workspaces/obsidian/.claude/settings.local.json` so approvals survive CDE rebuilds.

```json
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

---

## Cursor plugin installation

`cursor-install.sh` is extended with three additional extensions:

| Extension | ID | Purpose |
|-----------|-----|---------|
| Claude Code | `anthropic.claude-vscode` | Claude Code integration inside Cursor |
| Codex | `openai.codex` | OpenAI Codex assistant inside Cursor |
| Snowflake | `snowflake.snowflake-vsc` | Snowflake SQL development and schema browsing |

These are appended to the existing `cursor --install-extension` block. The script is called from `install.sh` already; no change to the call site is needed.

---

## Changes to existing files

### `install.sh`
- Add `bash "$SCRIPT_DIR/ai-setup.sh"` at the end
- Remove the `npx -y @gleanwork/configure-mcp-server ... --client cursor` line (consolidated into `ai-setup.sh`)

### `cursor-install.sh`
- Add `anthropic.claude-vscode`, `openai.codex`, `snowflake.snowflake-vsc` to the extension list

### `.gitconfig`
- Add `[core] excludesFile = ~/.config/git/ignore` (the symlinked gitignore)

---

## References

- [MCP Servers for AI Assistants or Agents — Guru](https://app.getguru.com/card/iRrEK44T)
- [Agentic Planning and Technical Design — Guru](https://app.getguru.com/card/TArEKz5c)
- [How to set up Claude Code — Guru](https://app.getguru.com/card/cpgozLxi)
- [YanxiChen-gh/Dotfiles — GitHub](https://github.com/YanxiChen-gh/Dotfiles)
- Lucas Liepert's bootstrap.sh — shared in #vanta-internal-ai
- Kevin Royer's settings.local.json trick — #proj-ai-coding-agents (Apr 2026)
