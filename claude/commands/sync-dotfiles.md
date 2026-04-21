---
description: Sync local ~/.claude changes (settings, commands, skills) back to dotfiles and commit with a semantic message
---

Sync local `~/.claude` changes back to the dotfiles repo:

1. Run `bash ~/dotfiles/sync-back.sh --no-commit`
2. Review the diff output printed above
3. Write a concise commit message that describes the *semantic* changes — what settings were added or changed, what commands or skills were created or modified. Avoid mechanical messages like "update settings.json". Example: "sync-back: add defaultMode:auto and effortLevel:xhigh to settings baseline"
4. Present the proposed commit message and ask: "Commit with this message? [y/N]"
5. Once approved, run:
   ```
   cd ~/dotfiles && git add claude/settings.json claude/commands/ claude/skills/ && git commit -m "<approved message>"
   ```
