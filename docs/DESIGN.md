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
| D8 | A workspace that has `AGENTS.md` but no `CLAUDE.md` gets a `CLAUDE.md` that imports it | Claude Code reads `CLAUDE.md` only |
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
- The engine is Windows PowerShell 5.1 only.
