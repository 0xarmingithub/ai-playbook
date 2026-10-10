# Global CLAUDE.md (template)

Fill every <<FILL: ...>>. Delete a section you do not need. Keep the file short: long files get ignored, and
procedures belong in skills that load only when needed.

## Who I am and how to answer

- Role and field: <<FILL: one line>>
- Reading style: <<FILL: for example plain language, short sentences, answer first, numbered steps>>
- Never do in replies: <<FILL: for example praise, filler openers, dashes, hedging without a reason>>
- Reference codes: <<FILL: yes or no. If yes: F1 finding, D1 decision, O1 option, R1 risk, Q1 question, A1 action>>

## Models and sub-agents

- Main session: <<FILL: model and effort>>
- Sub-agent default: <<FILL: model and effort>>
- Judgment-heavy work (architecture, security, money): <<FILL: which model, and whether a second opinion is required>>

## Always

- <<FILL: a rule that holds in every workspace, for example "confirm before anything outward-facing">>
- <<FILL: another>>

## Never

- Open or print secrets: `.env` files, tokens, keys, `settings.local.json`.
- <<FILL: another hard limit>>

## Playbook repo

My rules, skills, agents, hooks and guardrails are mirrored in `<<FILL: path to my personal playbook repo>>`.
<<FILL, optional: if I also publish a generic method repo, name its path here.>>

- After you change a `CLAUDE.md`, `AGENTS.md`, skill, agent, hook or rules file that `tools/manifest.json` lists, run
  `powershell -NoProfile -File <<FILL: path>>\tools\playbook.ps1 capture -Scope <name>`, then commit in that repo.
  Commit without asking. Push only when I say so.
- Optional, only if I publish a generic repo: update it when the change is to the method itself (the engine,
  templates, its docs, a shared skill, or a row for a third-party tool I start or stop using). Keep
  `tools/playbook.ps1` byte-identical in both repos. The generic repo must never contain workspace names, paths,
  employers, handles or other personal detail: a local commit hook that runs a private term list enforces it. Never
  bypass the hook. Never copy any other file between the two repos. Pushing needs my yes each time.
- Files under `shared/` must stay identical in every workspace that uses them. After editing one, run
  `capture -Scope shared`, then `install -Scope shared`. Workspace-specific rules go in that skill's `PROFILE.md`.
- `playbook.ps1 status` shows drift. A CONFLICT means both sides changed: show me, never use `-Force` on your own.
- Never put secrets or another organisation's infrastructure details in it. The scan blocks them. Do not add an
  allow-list entry without asking me.
