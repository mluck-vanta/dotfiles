# AI Dotfiles Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap all AI tooling (Claude Code CLI, MCP servers, plugins, permissions, auth) automatically from the dotfiles repo so a fresh Vanta CDE is fully configured after running `install.sh`.

**Architecture:** A new `claude/` directory holds static config files. A new `ai-setup.sh` script (called by `install.sh`) symlinks/copies them into place, registers MCP servers via `claude mcp add`, installs plugins, and runs auth flows. Everything is idempotent — safe to re-run.

**Tech Stack:** Bash, Claude Code CLI, GitHub CLI (`gh`), gsync, Cursor

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `claude/CLAUDE.md` | Global Claude instructions — symlinked to `~/CLAUDE.md` |
| Create | `claude/settings.json` | Permissions baseline — copied to `~/.claude/settings.json` if absent |
| Create | `claude/gitignore` | Global gitignore — symlinked to `~/.config/git/ignore` |
| Create | `claude/obsidian-settings-local.json` | Per-project settings seed — copied to `~/.claude/obsidian-settings-local.json` if absent |
| Create | `claude/commands/.gitkeep` | Empty dir tracked in git; future slash commands go here |
| Create | `ai-setup.sh` | Main bootstrap script — all AI tool setup |
| Modify | `install.sh:28` | Remove Glean-for-Cursor line; add call to `ai-setup.sh` |
| Modify | `cursor-install.sh:12` | Append 3 new extensions (Claude Code, Codex, Snowflake) |
| Modify | `.gitconfig:1-3` | Add `[core] excludesFile` section |

---

### Task 1: Create static config files

**Files:**
- Create: `claude/CLAUDE.md`
- Create: `claude/settings.json`
- Create: `claude/gitignore`
- Create: `claude/obsidian-settings-local.json`
- Create: `claude/commands/.gitkeep`

- [ ] **Step 1: Create the `claude/` directory**

```bash
mkdir -p claude/commands
```

- [ ] **Step 2: Create `claude/CLAUDE.md`**

Write this file at `claude/CLAUDE.md`:

```markdown
# Global Claude Instructions

## Plan and research storage

**CRITICAL**: When developing plans, designs, or research artifacts always store them in
`.ai-dev` directories. Place the artifact in the closest subdirectory to the subject of
the change. If not applicable, put in `.ai-dev` in the root of the repository.

Example: `packages/my-package/src/.ai-dev/plans/2026-04-13-support-new-feature.md`

These files are in the global gitignore and should never be committed.

## Working style

- Terse responses. No trailing "here's what I did" summaries — the diff speaks for itself.
- Prefer editing existing files over creating new ones.
- No speculative abstractions, extra error handling, or features beyond what was asked.
- No docstrings, comments, or type annotations on code you didn't change.
```

- [ ] **Step 3: Create `claude/settings.json`**

Write this file at `claude/settings.json`:

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

- [ ] **Step 4: Create `claude/gitignore`**

Write this file at `claude/gitignore`:

```
**/.claude/settings.local.json
**/.ai-dev
```

- [ ] **Step 5: Create `claude/obsidian-settings-local.json`**

Write this file at `claude/obsidian-settings-local.json`:

```json
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

- [ ] **Step 6: Create `claude/commands/.gitkeep`**

```bash
touch claude/commands/.gitkeep
```

- [ ] **Step 7: Verify all files exist**

Run: `find claude -type f | sort`

Expected:
```
claude/CLAUDE.md
claude/commands/.gitkeep
claude/gitignore
claude/obsidian-settings-local.json
claude/settings.json
```

- [ ] **Step 8: Commit**

```bash
git add claude/
git commit -m "Add Claude config files (CLAUDE.md, settings, gitignore, commands)"
```

---

### Task 2: Create `ai-setup.sh`

**Files:**
- Create: `ai-setup.sh`

- [ ] **Step 1: Write `ai-setup.sh`**

Write this file at `ai-setup.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CLAUDE_DIR="$SCRIPT_DIR/claude"

info()    { echo "[ai-setup] $*"; }
success() { echo "[ai-setup] ✓ $*"; }
warn()    { echo "[ai-setup] ⚠ $*" >&2; }
skip()    { echo "[ai-setup] → $*"; }

# ---------------------------------------------------------------------------
# 0. Install Claude Code CLI
# ---------------------------------------------------------------------------
install_claude_code() {
    if command -v claude >/dev/null 2>&1; then
        skip "claude already installed"
        return
    fi
    info "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | sh
    success "Claude Code CLI installed"
}

# ---------------------------------------------------------------------------
# 1. Symlinks
# ---------------------------------------------------------------------------
setup_symlinks() {
    info "Setting up symlinks..."

    ln -sf "$CLAUDE_DIR/CLAUDE.md" "$HOME/CLAUDE.md"
    success "~/CLAUDE.md"

    mkdir -p "$HOME/.config/git"
    ln -sf "$CLAUDE_DIR/gitignore" "$HOME/.config/git/ignore"
    success "~/.config/git/ignore"

    if [ -d "/workspaces/obsidian" ]; then
        mkdir -p "$HOME/.claude" "/workspaces/obsidian/.claude"
        if [ ! -f "$HOME/.claude/obsidian-settings-local.json" ]; then
            cp "$CLAUDE_DIR/obsidian-settings-local.json" \
               "$HOME/.claude/obsidian-settings-local.json"
        fi
        ln -sf "$HOME/.claude/obsidian-settings-local.json" \
               "/workspaces/obsidian/.claude/settings.local.json"
        success "/workspaces/obsidian/.claude/settings.local.json"
    else
        warn "/workspaces/obsidian not found — skipping obsidian settings.local.json"
    fi
}

# ---------------------------------------------------------------------------
# 2. Claude settings
# ---------------------------------------------------------------------------
setup_claude_settings() {
    mkdir -p "$HOME/.claude"
    if [ ! -f "$HOME/.claude/settings.json" ]; then
        cp "$CLAUDE_DIR/settings.json" "$HOME/.claude/settings.json"
        success "~/.claude/settings.json installed"
    else
        skip "~/.claude/settings.json already exists (delete and re-run to reset)"
    fi
}

# ---------------------------------------------------------------------------
# 3. Slash commands
# ---------------------------------------------------------------------------
setup_commands() {
    mkdir -p "$HOME/.claude/commands"
    if [ -n "$(find "$CLAUDE_DIR/commands" -not -name '.gitkeep' -type f 2>/dev/null)" ]; then
        cp -r "$CLAUDE_DIR/commands/." "$HOME/.claude/commands/"
        success "slash commands → ~/.claude/commands/"
    else
        skip "no custom commands yet"
    fi
}

# ---------------------------------------------------------------------------
# 4. MCP servers
# ---------------------------------------------------------------------------
setup_mcp_servers() {
    if ! command -v claude >/dev/null 2>&1; then
        warn "claude not found — skipping MCP setup"
        return
    fi
    info "Configuring MCP servers..."

    # Always on
    claude mcp add --transport http --scope user glean_default \
        https://vanta-be.glean.com/mcp/default 2>/dev/null || true
    success "MCP: glean_default"

    claude mcp add --transport stdio --scope user eslint \
        -- npx @eslint/mcp@latest 2>/dev/null || true
    success "MCP: eslint"

    claude mcp add --transport stdio --scope user context7 \
        -- npx -y @upstash/context7-mcp 2>/dev/null || true
    success "MCP: context7"

    claude mcp add --transport http --scope user vanta \
        https://mcp.vanta.com/mcp 2>/dev/null || true
    success "MCP: vanta"

    # Conditional — only if Ona secrets are set
    if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
        claude mcp add --transport stdio --scope user slack \
            --env SLACK_BOT_TOKEN="$SLACK_BOT_TOKEN" \
            -- npx -y @modelcontextprotocol/server-slack 2>/dev/null || true
        success "MCP: slack"
    else
        warn "MCP: slack — SLACK_BOT_TOKEN not set"
    fi

    if [ -n "${DATADOG_API_KEY:-}" ]; then
        claude mcp add --transport stdio --scope user datadog \
            --env DATADOG_API_KEY="$DATADOG_API_KEY" \
            --env DATADOG_APP_KEY="${DATADOG_APP_KEY:-}" \
            -- npx -y datadog-mcp-server 2>/dev/null || true
        success "MCP: datadog"
    else
        skip "MCP: datadog — DATADOG_API_KEY not set (use /toggle-datadog-mcp enable)"
    fi

    skip "MCP: mongodb — use /toggle-mongo-mcp enable when needed"

    if [ -n "${LANGSMITH_API_KEY:-}" ]; then
        claude mcp add --transport stdio --scope user LangSmith \
            --env LANGSMITH_API_KEY="$LANGSMITH_API_KEY" \
            -- uvx langsmith-mcp-server 2>/dev/null || true
        success "MCP: LangSmith"
    else
        skip "MCP: LangSmith — LANGSMITH_API_KEY not set"
    fi

    if [ -n "${SNOWFLAKE_ACCOUNT:-}" ] && [ -n "${SNOWFLAKE_USER:-}" ] && \
       { [ -n "${SNOWFLAKE_PASSWORD:-}" ] || [ -n "${SNOWFLAKE_PRIVATE_KEY_PATH:-}" ]; }; then
        claude mcp add --transport stdio --scope user snowflake \
            --env SNOWFLAKE_ACCOUNT="$SNOWFLAKE_ACCOUNT" \
            --env SNOWFLAKE_USER="$SNOWFLAKE_USER" \
            --env SNOWFLAKE_PASSWORD="${SNOWFLAKE_PASSWORD:-}" \
            --env SNOWFLAKE_PRIVATE_KEY_PATH="${SNOWFLAKE_PRIVATE_KEY_PATH:-}" \
            -- npx -y @modelcontextprotocol/server-snowflake 2>/dev/null || true
        success "MCP: snowflake"
    else
        skip "MCP: snowflake — SNOWFLAKE_ACCOUNT/USER/PASSWORD not set"
    fi

    setup_cursor_mcp
}

setup_cursor_mcp() {
    mkdir -p "$HOME/.cursor"
    cat > "$HOME/.cursor/mcp.json" << 'CURSORMCP'
{
  "mcpServers": {
    "glean_default": {
      "url": "https://vanta-be.glean.com/mcp/default",
      "type": "http"
    },
    "atlassian": {
      "url": "https://mcp.atlassian.com/v1/sse",
      "type": "sse"
    }
  }
}
CURSORMCP
    success "~/.cursor/mcp.json"
}

# ---------------------------------------------------------------------------
# 5. Claude Code plugins
# ---------------------------------------------------------------------------
setup_plugins() {
    if ! command -v claude >/dev/null 2>&1; then
        warn "claude not found — skipping plugin installation"
        return
    fi
    info "Installing Claude Code plugins..."
    claude plugin install superpowers@claude-plugins-official 2>/dev/null || true
    success "plugin: superpowers"
    claude plugin install code-simplifier@claude-plugins-official 2>/dev/null || true
    success "plugin: code-simplifier"
}

# ---------------------------------------------------------------------------
# 6. gsync Claude Code plugin
# ---------------------------------------------------------------------------
setup_gsync_plugin() {
    if [ ! -d "/workspaces/obsidian" ]; then
        skip "gsync plugin — /workspaces/obsidian not found"
        return
    fi
    info "Installing gsync Claude Code plugin..."
    (cd /workspaces/obsidian && yarn workspace @vanta/gsync claude:install 2>/dev/null) \
        && success "gsync plugin installed" \
        || warn "gsync plugin install failed — run: cd /workspaces/obsidian && yarn workspace @vanta/gsync claude:install"
}

# ---------------------------------------------------------------------------
# 7. Auth bootstrap
# ---------------------------------------------------------------------------
setup_auth() {
    info "Checking auth..."

    # gh
    if gh auth status >/dev/null 2>&1; then
        skip "gh already authenticated"
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "$GITHUB_TOKEN" | gh auth login --with-token \
            && success "gh: authenticated via GITHUB_TOKEN" \
            || warn "gh: auth failed — run 'gh auth login' manually"
    else
        info "gh: starting device flow (follow the prompts)..."
        gh auth login --hostname github.com \
            && success "gh: authenticated" \
            || warn "gh: auth failed — run 'gh auth login' manually"
    fi

    # gsync
    if ! command -v gsync >/dev/null 2>&1; then
        skip "gsync not on PATH"
        return
    fi
    if gsync auth status >/dev/null 2>&1; then
        skip "gsync already authenticated"
    elif [ -f "/usr/local/secrets/gsync_google_oauth" ]; then
        info "gsync: running auth login (browser will open)..."
        gsync auth login \
            && success "gsync: authenticated" \
            || warn "gsync: auth failed — run 'gsync auth login' manually"
    else
        warn "gsync: credentials missing at /usr/local/secrets/gsync_google_oauth"
        info "  Get from 1Password and save (may need sudo), then run: gsync auth login"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "========================================"
    echo "  AI tooling setup"
    echo "========================================"
    echo ""

    install_claude_code
    setup_symlinks
    setup_claude_settings
    setup_commands
    setup_mcp_servers
    setup_plugins
    setup_gsync_plugin
    setup_auth

    echo ""
    echo "========================================"
    echo "  Setup complete"
    echo "========================================"
    echo ""
}

main "$@"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ai-setup.sh
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n ai-setup.sh && echo "syntax OK"`

Expected:
```
syntax OK
```

- [ ] **Step 4: Commit**

```bash
git add ai-setup.sh
git commit -m "Add ai-setup.sh: Claude Code, MCP, plugins, auth bootstrap"
```

---

### Task 3: Update existing files

**Files:**
- Modify: `install.sh:28` (remove Glean line, add `ai-setup.sh` call)
- Modify: `cursor-install.sh:12` (append 3 extensions)
- Modify: `.gitconfig:1-3` (add `[core]` section)

- [ ] **Step 1: Update `install.sh`**

Replace line 28 (`npx -y @gleanwork/configure-mcp-server remote --url https://vanta-be.glean.com/mcp/default --client cursor`) with:

```bash
bash "$(dirname "$(readlink -f "$0")")/ai-setup.sh"
```

The full file should now be:

```bash
#!/bin/bash

sudo chsh "$(id -un)" --shell "/usr/bin/zsh"

create_symlinks() {
    # Get the directory in which this script lives.
    script_dir=$(dirname "$(readlink -f "$0")")

    # Get a list of all files in this directory that start with a dot.
    files=$(find -maxdepth 1 -type f -name ".*")

    # Create a symbolic link to each file in the home directory.
    for file in $files; do
        name=$(basename $file)
        echo "Creating symlink to $name in home directory."
        rm -rf ~/$name
        ln -s $script_dir/$name ~/$name
    done
}

create_symlinks

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

bash "$(dirname "$(readlink -f "$0")")/ai-setup.sh"
```

- [ ] **Step 2: Verify `install.sh` syntax**

Run: `bash -n install.sh && echo "syntax OK"`

Expected:
```
syntax OK
```

- [ ] **Step 3: Update `cursor-install.sh`**

Append three new extensions. The full file should now be:

```bash
cursor --install-extension ms-python.python \
     --install-extension ms-python.black-formatter \
     --install-extension dbaeumer.vscode-eslint \
     --install-extension esbenp.prettier-vscode \
     --install-extension eamodio.gitlens \
     --install-extension graphql.vscode-graphql \
     --install-extension hashicorp.terraform \
     --install-extension redhat.vscode-yaml \
     --install-extension github.vscode-github-actions \
     --install-extension yoavbls.pretty-ts-errors \
     --install-extension apollographql.vscode-apollo \
     --install-extension firsttris.vscode-jest-runner \
     --install-extension anthropic.claude-vscode \
     --install-extension openai.codex \
     --install-extension snowflake.snowflake-vsc
```

- [ ] **Step 4: Update `.gitconfig`**

Add the `[core]` section. The full file should now be:

```ini
[pager]
    branch = false

[core]
    excludesFile = ~/.config/git/ignore
```

- [ ] **Step 5: Verify all scripts**

Run: `bash -n install.sh && bash -n ai-setup.sh && echo "all OK"`

Expected:
```
all OK
```

- [ ] **Step 6: Commit**

```bash
git add install.sh cursor-install.sh .gitconfig
git commit -m "Wire up ai-setup.sh, add Cursor extensions, add global gitignore"
```

---

### Task 4: End-to-end smoke test

- [ ] **Step 1: Run `ai-setup.sh`**

Run: `bash ai-setup.sh`

Watch output for these key lines (exact text depends on what's already configured):

```
[ai-setup] → claude already installed
[ai-setup] ✓ ~/CLAUDE.md
[ai-setup] ✓ ~/.config/git/ignore
[ai-setup] ✓ /workspaces/obsidian/.claude/settings.local.json  (OR ⚠ if obsidian missing)
[ai-setup] ✓ ~/.claude/settings.json installed  (OR → already exists)
[ai-setup] → no custom commands yet
[ai-setup] ✓ MCP: glean_default
[ai-setup] ✓ MCP: eslint
[ai-setup] ✓ MCP: context7
[ai-setup] ✓ MCP: vanta
[ai-setup] ⚠ MCP: slack — SLACK_BOT_TOKEN not set
[ai-setup] ✓ ~/.cursor/mcp.json
[ai-setup] ✓ plugin: superpowers
[ai-setup] ✓ plugin: code-simplifier
```

No unhandled errors or `set -e` aborts.

- [ ] **Step 2: Verify symlinks point to the right source**

Run: `readlink ~/CLAUDE.md && readlink ~/.config/git/ignore`

Expected:
```
/workspaces/dotfiles/claude/CLAUDE.md
/workspaces/dotfiles/claude/gitignore
```

- [ ] **Step 3: Verify settings.json is valid JSON**

Run: `python3 -m json.tool < ~/.claude/settings.json > /dev/null && echo "valid JSON"`

Expected:
```
valid JSON
```

- [ ] **Step 4: Verify Cursor MCP config is valid JSON**

Run: `python3 -m json.tool < ~/.cursor/mcp.json > /dev/null && echo "valid JSON"`

Expected:
```
valid JSON
```

- [ ] **Step 5: Verify MCP servers registered**

Run: `claude mcp list 2>/dev/null`

Expected output includes: `glean_default`, `eslint`, `context7`, `vanta`.

- [ ] **Step 6: Re-run to verify idempotency**

Run: `bash ai-setup.sh`

Expected: no errors, skip messages for things already configured (e.g. `→ ~/.claude/settings.json already exists`). No duplicated MCP entries.

- [ ] **Step 7: Commit any fixes (if needed)**

If the smoke test revealed issues that required edits:

```bash
git add -A
git commit -m "Fix issues found during smoke test"
```

Skip this step if no fixes were needed.
