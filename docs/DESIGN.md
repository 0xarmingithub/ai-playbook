# Design record

How and why the playbook is built this way. The design went through two critique rounds (a self-critique, then an
independent reviewer working read-only), following a two-challenge rule: each round finds real weaknesses and ends
in a rewrite, and every version is kept. This file holds the final design and a summary of what the rounds changed.

## Goal

One versioned repository holding the instruction layer (rules, guardrails, skills, agents, hooks) of several Claude
Code workspaces plus the global setup, with one command to keep repository and live files in step.

## Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The playbook repo lives outside any cloud-synced folder | Git inside a sync folder corrupts easily |
| D2 | Live files stay authoritative where they are. The repo is a versioned mirror | A workspace's tests and hooks use relative paths. Moving the source would break them |
| D3 | Sync is three-way: live copy, repo copy, hash at the last sync. Both sides changed means CONFLICT and nothing moves | A fixed "repo wins" or "live wins" rule overwrites work |
| D4 | Allow-list only. The manifest names what is copied | A deny-list leaks whatever it forgot. A home folder holds credentials |
| D5 | The global `settings.json`: copy only named top-level keys, capture-only, never `permissions` | The permission list accumulates one-off commands that reveal what you work on |
| D6 | `scan` blocks tokens, keys, public IPs, emails and Azure ids, before every capture and on commit | Infrastructure details are not "secret" patterns but must not leave their owner's control |
| D7 | The sync rule is written once, in the user-level rules file. Each workspace carries only a short, conditional pointer to it that names no path | The user-level file loads in every workspace. A pointer in each workspace keeps the rule visible there and survives a rule file being read in isolation. It names no path and says "ignore if you have no such section", so it is safe in folders other people use |
| D8 | A workspace that has `AGENTS.md` but no `CLAUDE.md` gets a `CLAUDE.md` that imports it | Claude Code reads `CLAUDE.md` when one exists and ignores `AGENTS.md` beside it. Newer versions read `AGENTS.md` alone when there is no `CLAUDE.md`; the import stays the safe shape for every version |
| D9 | No new hooks, no auto-commit, no auto-push | A failing hook blocks edits. Pushing is outward-facing |
| D10 | A plugin marketplace is deferred | Plugins cannot carry `CLAUDE.md` rules |
| D11 | Skills needed identically in several workspaces have one `SKILL.md` in `shared/`, installed byte-identical. Differences live in a `PROFILE.md` beside it | Equal files cannot hold workspace-specific rules. A profile keeps them without forking the skill |
| D12 | Files that mix rules with infrastructure details are stored redacted: regex find/replace, one-way, never installed over the live file | Keeps the rules and keeps addresses out of the repo |
| D13 | Redaction patterns live in a git-ignored local file. If it is missing, the entry is skipped | Patterns that describe secrets are themselves secrets. An early version stored them in the manifest and leaked what they hid |
| D14 | `inventory` writes a list of everything installed or defined | The repo stores only your own skills. The inventory shows the rest so nothing is invisible |
| D15 | `scan` checks what git would commit, not every file on disk | The private rules file must never be read as repo content, and the scan should match what is published |
| D16 | The published repository holds the method only. Personal mirrors stay in a separate local repo | A mirror carries workspace names, paths and rules, which are confidential |
| D17 | A local-only commit hook (inside `.git`, never published) runs a private term list over every commit to the published repo: added paths, added lines and the message. It fails closed if the list is missing | A rule that says "never include names" fails the first time someone forgets. The term list names the confidential things, so it cannot live in the published repo |
| D18 | The published repo uses a neutral commit identity, with a reserved never-delivered email address | A real or no-reply address embeds an account handle in history, which the term list rightly flags |
| D19 | Both repos are updated when a relevant change is made: the personal mirror for any rule, skill, agent or hook change; the published repo for changes to the method. Only the engine file is shared between them, byte-identical | Two repos drift unless the rule says which change belongs where |
| D20 | `tools/health.ps1` checks the repo against its own invariants and reports SKIP, never PASS, for a check it cannot run. `tools/test-scan.ps1` plants known values and fails when the scan misses one or flags a clean line | A check that cannot go red is not evidence. The first health run found a broken manifest that `status` had been failing on without anyone noticing |
| D21 | Generic working-method procedures (`session-start`, `end-of-session`, `pre-close-verification`, `branch-hygiene`, `directional-prompting`, optional `prod-deploy`) are shared skills, not rules pasted into every workspace file. The few rules that must hold even when no skill fires (ownership baseline, a fix is unreviewed work, mirrored copies, parallel agents, vetting, session breakpoints) are single short lines in the user-level template that point at the skill | A skill's body loads only on demand, so the always-on file stays short. A rule that depends on remembering to invoke a skill needs one line that is always there |
| D22 | Session length is an offer, not a stop. The template says to offer a fresh session at a breakpoint or after about 40 tool calls or 250 messages, and never to stop mid-task | Long threads loop and compact repeatedly, but a hard stop contradicts "finish the whole task". The offer keeps both |
| D23 | `docs/LOADING.md` covers Claude Code only. Rule-file loading differs per tool, so a second tool means a new, verified section, not a guess | Loading fails silently, and a table of unverified cells is worse than none |
| D24 | Third-party skills are installed from their source, never from a frozen copy in a repo. The repo records the source, the licence as stated, and the vetting result | A frozen copy goes stale, drops upstream removals, and carries a licence notice duty. A pointer does none of that |
| D25 | The sync engine supports a `baseline` command, `status -Strict`, and PowerShell 7 | A repo copy that intentionally differs from the live copy (a platform variant) otherwise reads as CONFLICT forever, which hides real conflicts. `-Strict` is opt-in so existing callers keep their exit codes |


## What the critique rounds changed

| Finding | Severity | Outcome |
|---|---|---|
| Rule files can hold organisation infrastructure that a secrets-only scan cannot see | Blocker | Added address, email and subscription-id patterns, and redaction (D6, D12) |
| A whole-file copy of the global settings publishes personal permission history and changes constantly | Blocker | Key subset, capture-only (D5) |
| Editing guarded workspaces to add a pointer risks their tests and checksum-pinned hooks | High | One user-level rule, plus a short conditional pointer per workspace added later with each workspace's own tests run (D7) |
| Mirroring a repo that is already in git duplicates history and secret surface | High | Kept as a snapshot because one searchable place was the goal. Listed as a residual risk |
| Line endings and online-only files cause false drift | Medium | Bytes stored as-is (`* -text`). Unreadable files show UNREADABLE, never "deleted" |
| Installing hooks runs code unprompted | Medium | `install` never touches `settings.json`. Restore notes say to wire hooks last and test each |
| A shared layer for two files is overbuilt | Medium | Shared files only for real duplicates (D11) |

## Residual risks

- A mirror of a repo that has its own git history is a snapshot and can go stale until the next `capture`. `status` shows it.
- The scan finds patterns, not meaning. A human must read anything before it is published.
- `capture` is not automatic. If nobody runs it, the mirror ages.
- The engine runs on Windows PowerShell 5.1 and PowerShell 7. Other shells are untested.
- `install` now restores a file that was synced once and then deleted live (D25). That is the right default for a lost file, but it also brings back a file you deleted on purpose. Delete the repo copy too, or exclude the entry.
- A state file holding baselined entries reads as CONFLICT to an older engine copy on another machine. That is the safe direction.
