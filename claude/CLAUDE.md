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
