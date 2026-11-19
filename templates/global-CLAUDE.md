# Global CLAUDE.md (template)

Fill every placeholder (two angle brackets, the word FILL, a colon, text). Delete a section you do not need. Keep the file short: long files get ignored, and
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

- Before you cite a check as proof, name the result that would have made it fail, and confirm that result could have happened. Reject as proof: a tag compared with itself, a parent status standing in for child work, a suite total when you changed a subset, an empty result read as "nothing found" when the read may have failed, an exit code from a tool that exits zero having done nothing.
- Resolve names, versions, paths and ids from the live artifact before acting, even when a rule file states them. If a rule file is stale, correct it in the same response.
- Write scratch files outside the working tree. If one lands inside, name it `tmp_<purpose>` and delete it before you hand back. Detect strays by prefix, not by extension. Report residue you did not create; do not delete it.
- Before the first change in a repository, record what is already there: `git worktree list`,
  `git status --short`, the branch and the head commit, plus the active cloud account if you use one.
  Another session may share the checkout. Never discard, reset or clean uncommitted work you did not
  create; state what you found and ask. The `session-start` skill has the full procedure.
- A fix is unreviewed work. After one, re-run the exact artifact that showed the defect. If the fix
  changed a failure contract, add a test for the new contract. Where it is cheap, show the check red
  first, then green.
- When several agents run in parallel, give them file tools only and let one agent at a time touch
  shared state. For big rewrites, ask for a patch list (an exact string that occurs once, its
  replacement, the evidence) and apply it yourself. Put the brief in a file. Give each agent its own
  output path.
- Where the same logic exists twice, change both copies or neither. Before a pull request, list what
  the branch touched and check each known pair. The `branch-hygiene` skill has the check.
- Before you install a third-party skill, MCP server or plugin, read it, and scan one skill folder at a
  time with a static scanner. Treat the score as advice. See "Vetting before adoption" in the method
  repo's `docs/THIRD-PARTY.md`.
- Offer a fresh session at a natural breakpoint (a phase done, a change shipped, an investigation
  concluded), and when one request has passed about 40 tool calls or the conversation about 250
  messages, since long threads loop and compact repeatedly. Offer it; never stop mid-task.
- <<FILL: a rule that holds in every workspace, for example "confirm before anything outward-facing">>
- <<FILL: another>>

## Rule upkeep

- Every few months, and after a default model change, audit the rule files, skills and memory for
  duplicates, conflicts, stale assumptions, and descriptions that trigger too broadly. Audit by
  claim, not by file: check each checkable name, id, version and path against the live system.
  Mark what you cannot check as unverified, mark outdated lessons as historical, and never delete a
  safeguard because it is old. Keep the audit read-only until the owner approves a cleanup.

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
