# Machine (managed in ~/dotfiles — edit stow/claude there, not ~/.claude)

- Ubuntu + zsh. Available: rg, fd (`fdfind`), jq, ast-grep (structural search/replace), gh, sqlite3, psql, delta, uv, pnpm, bun.
- Bash output is compressed by RTK automatically; use `rtk proxy <cmd>` only when you need raw output.
- RTK also reformats `ls` inside pipelines (adds sizes). To feed file names into other commands, use `find -printf` or `command ls`.
- Browser work: agent-browser skill. Machine setup lives in ~/dotfiles (Ansible + Stow); follow its AGENTS.md.

## Secrets (Bitwarden SM)

- Keys: FAL_KEY, OPENROUTER_API_KEY. Never print, echo, log, or write secret values to files, and never pass them as CLI args.
- `genmedia` gets FAL_KEY injected automatically. The fal skill runtime (falkit) resolves FAL_KEY via bws on its own.
- For anything else: `with-secrets FAL_KEY -- <cmd>` (comma-separate several keys). Check availability with `with-secrets --check FAL_KEY` — never `printenv`.
- If a key is missing or rejected, tell the user; don't go looking for it in files.
