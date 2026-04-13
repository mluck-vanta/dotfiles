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

    mkdir -p "$HOME/.claude"
    ln -sf "$CLAUDE_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    success "~/.claude/CLAUDE.md"

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
    elif [ -t 0 ]; then
        info "gh: starting device flow (follow the prompts)..."
        gh auth login --hostname github.com \
            && success "gh: authenticated" \
            || warn "gh: auth failed — run 'gh auth login' manually"
    else
        warn "gh: not authenticated — run 'gh auth login' in an interactive terminal"
    fi

    # gsync
    if ! command -v gsync >/dev/null 2>&1; then
        skip "gsync not on PATH"
        return
    fi
    if gsync auth status >/dev/null 2>&1; then
        skip "gsync already authenticated"
    elif [ -f "/usr/local/secrets/gsync_google_oauth" ] && [ -t 0 ]; then
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
