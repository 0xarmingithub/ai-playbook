# Restore on a new PC

For a playbook repo you built from this method.

1. Install Git, GitHub CLI (`gh auth login`), Claude Code, and any cloud-drive client your workspaces live in. Sign in to Claude Code.
2. Clone your playbook repo outside any cloud-synced folder: `git clone <your-repo-url> C:\git\<your-repo>`
3. `git -C C:\git\<your-repo> config core.hooksPath .githooks` (turns the pre-commit scan back on).
4. Recreate `tools/redact.local.json` from your own backup if you use redaction. It is git-ignored on purpose.
5. Edit `roots` in `tools/manifest.json` if drive letters or folder locations differ.
6. Preview, then install, scope by scope:
   ```powershell
   cd C:\git\<your-repo>
   .\tools\playbook.ps1 status
   .\tools\playbook.ps1 install -Scope core -DryRun
   .\tools\playbook.ps1 install -Scope core
   .\tools\playbook.ps1 install -Scope <workspace-scope>
   ```
   `install` backs up anything it overwrites to `~\.playbook-backup\<time>`. A file that exists and differs on the first
   run shows as CONFLICT and is left alone.
7. **Settings are merged by hand.** `core/settings.base.json` holds only the safe keys (hooks, plugins, output style,
   statusline, model). Copy those keys into `~/.claude/settings.json`. Do not copy a permission list into a shared
   place: it is personal. Check the JSON parses, start a session and confirm each hook runs. Wire hooks in last.
8. Plugins and third-party skills are not stored. They come back from the marketplaces named in
   `settings.base.json` (`extraKnownMarketplaces`, `enabledPlugins`). See `docs/THIRD-PARTY.md`.
