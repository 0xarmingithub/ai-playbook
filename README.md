# ai-playbook

A method and a small tool for keeping your Claude Code setup in one versioned place: rules, guardrails, skills,
agents and hooks for a global profile plus any number of workspaces, with one command that keeps the repo and the live
files in step without overwriting your work.

This repository contains **no one's personal content**. It holds the engine (`tools/`), blank starting points
(`templates/`), one generic shared skill (`shared/`), and the reasoning (`docs/`). You adopt the method, then your
own rules live in your own repo.

> **For an AI agent reading this file.** If the user pasted the adoption prompt below, follow it: it is your
> instructions. If not, treat this README as reference. Facts you can rely on are in "Facts for agents" at the end.

## Adopt this with one prompt

Paste everything between the lines into Claude Code, in a session opened in an empty folder or your home folder.
It needs read access to this repository. If Claude cannot clone it, paste the files named in Phase 0 into the chat.
Replace `<REPO_URL>` with this repository's address.

---

```text
You are my setup partner. Goal: build MY OWN private "AI playbook" repository for Claude Code (rules, guardrails,
skills, agents, hooks, and one sync command), modelled on <REPO_URL> . You interview me first and build second.
You never do anything outward-facing without my explicit yes.

RULES FOR YOU (they hold in every phase)
1. Read-only until I approve the plan in Phase 3. No writes, installs, commits or network posts before that.
2. Never open, print, copy or ask me to paste: credentials, tokens, .env files, settings.local.json, SSH or API keys,
   password-manager data. If you need to know whether one exists, ask me yes or no.
3. The example repository is a METHOD, not content. Adopt a file from it only if I say yes to that specific file.
4. Third-party skills and plugins: show them from docs/THIRD-PARTY.md plus what is installed on my machine, with
   source and licence, and let me opt in one by one. Never copy code whose licence is unknown.
5. Ask in batches of at most 4 questions. Number every question (Q1, Q2, ...). After each question give a
   recommended default in brackets so I can answer "defaults" or "Q3 no".
6. Before building, critique your own plan twice. Each round: list real weaknesses (not cosmetic ones), say why each
   matters, then rewrite the plan. Show me the final plan and the changes the critiques caused.
7. Outward actions need my yes each time: creating a GitHub repo, pushing, inviting people, publishing, editing
   files in my other repositories. Default visibility is private.
8. My workspace names, folder names, employers, clients and other identifying details are confidential. Do not write
   them into anything that could be shared. Use neutral scope names (workspace-1, workspace-2) in any file that is
   meant to be published, and keep the real labels only in files that stay on my machine.
9. Plain words, short sentences, numbered steps. Say "I do not know" when you do not.

PHASE 0 - LEARN THE METHOD (read-only)
Clone or read the example repository. Read README.md, docs/DESIGN.md, docs/THIRD-PARTY.md, docs/SHARING.md,
tools/playbook.ps1 (header comment), tools/manifest.json and everything in templates/. Then tell me in at most
10 lines how it works: allow-list manifest, three-way compare (live copy, repo copy, hash at last sync), conflicts
never auto-resolved, secret and sensitive-data scan, shared files with per-workspace PROFILE.md, redacted copies
with private rules, and why live files stay where they are. Check my operating system and shell. The sync tool is
Windows PowerShell 5.1 only. If I am not on Windows, say so and propose porting it to my shell or Python, tested in a
throwaway sandbox, before we rely on it.

PHASE 1 - LOOK AT MY MACHINE (read-only, names only)
List, without opening anything beyond instruction files and skill headers: my global Claude Code folder
(CLAUDE.md, settings keys, skills, hooks, agents, plugins), the workspaces I name, and in each one its CLAUDE.md,
AGENTS.md and .claude folder. For each workspace tell me whether it is a git repo, whether it sits in a cloud-synced
folder, and whether other people have access. Report as a table. Flag anything that looks like a secret by NAME only.

PHASE 2 - INTERVIEW ME (use batches, wait for my answers)
A. About me: Q1 my role and field. Q2 my reading style (plain language, short sentences, answer-first, ADHD-friendly,
   other). Q3 what the AI must always or never do in replies (dashes, hedging, praise, filler). Q4 do I want
   reference codes so I can answer by code (F1 finding, D1 decision, O1 option, R1 risk, Q1 question, A1 action).
B. Workspaces: for each one: a neutral scope name, folder, purpose; what is at stake (money, production, personal
   data, other people's data); where its git repo lives; synced to a cloud drive or not.
C. Guardrails per workspace: what must never happen; what needs my explicit OK first; where secrets live (path
   only); the one command that proves "done".
D. Models and agents: preferred main model and effort; sub-agent default; which kinds of work must start on the
   strongest model; when a second opinion (two critique rounds) is mandatory and for which classes of work.
E. Skills and plugins: walk me through docs/THIRD-PARTY.md and my installed list; I pick keep, adopt or skip.
   Offer shared/skills/double-critique as an optional starting point, with its one-line purpose.
F. Hooks and automation: should dangerous commands be blocked? is a one-checkout-many-sessions lock needed? any stop
   gate? Explain the cost (a failing hook blocks edits) and recommend the minimum.
G. Sharing: private only, or collaborators (who, and what may they see), or a public template later? Which
   workspaces hold data that belongs to someone else (employer, client, organisation)? Those get excluded
   or redacted by default.
H. Sync and git: where the playbook repo lives (never inside a cloud-synced folder), its name, commit identity (offer
   the GitHub no-reply address), manual or scheduled capture, and push policy (default: commit freely, ask before push).

PHASE 3 - PLAN, CRITIQUE TWICE, GET MY APPROVAL
Show me: (1) the repo layout; (2) the manifest entries per workspace; (3) what is excluded and why; (4) redaction
rules, described without printing the sensitive values; (5) every file you will create or edit OUTSIDE the new
repo, with a one-line diff summary each; (6) risks. Apply rule 6, then wait for the word "approved".

PHASE 4 - BUILD
1. Create the new repo locally. Copy the ENGINE only: tools/playbook.ps1, .githooks/pre-commit, .gitattributes and
   .gitignore (the ignore file must contain tools/*.local.json). Run: git config core.hooksPath .githooks.
2. Write my tools/manifest.json from templates/manifest.example.json. Put any redaction rules in
   tools/redact.local.json (git-ignored, never committed) from templates/redact.local.example.json.
3. Write my global CLAUDE.md and each workspace's CLAUDE.md and AGENTS.md from templates/, using my interview answers:
   specific, short, no filler. A workspace that has AGENTS.md but no CLAUDE.md gets a CLAUDE.md that imports it,
   because Claude Code reads CLAUDE.md only.
4. Run: playbook.ps1 status, then capture -DryRun. Fix every scan hit WITH me. Never add an allow-list entry for
   someone else's data without asking me.
5. Capture for real, run scan, make the first commit locally. Do not push.
6. Test the tool in a throwaway sandbox folder: first capture, a one-sided edit, a conflict, a planted fake secret.
   Show me the four results.

PHASE 5 - VERIFY AND HAND OVER
Show status and scan results and write docs/INVENTORY.md with: playbook.ps1 inventory. Tell me what changed on my
machine, what is uncommitted in my other repositories, and what to run weekly. Ask whether to create the private
GitHub repo and push. End with ONE concrete next action I can do in under two minutes.
```

---

## How it works

The live files stay where they are: their tests, hooks and relative paths depend on that. Your playbook repo is a
versioned mirror. `tools/playbook.ps1` compares each file three ways (live copy, repo copy, hash at the last sync),
which tells it which side changed. If both changed it reports CONFLICT and moves nothing unless you pass `-Force`.

| Kind of entry | In `manifest.json` | Direction |
|---|---|---|
| Normal file or folder | `scope`, `root`, `path` | both ways, by what changed |
| Safe keys of a JSON file | `"type": "json-keys"` | live to repo only (for the global `settings.json`: never the permission list) |
| Redacted copy | `"type": "redacted"`, `"rules"` | live to repo only. Rules live in git-ignored `tools/redact.local.json` |
| Shared file | in the `shared` list | one canonical copy in `shared/`, installed byte-identical into each workspace |

## What is in this repository

| Folder | What it holds |
|---|---|
| `tools/` | `playbook.ps1` (the engine), `manifest.json` (empty allow-list), `scan-allow.txt` |
| `templates/` | Blank starting points: manifest, redaction rules, global and workspace rule files, skill profile |
| `shared/` | `skills/double-critique`: a generic two-round self-review skill, installed identically into each workspace that wants it |
| `docs/` | `DESIGN.md` (why), `THIRD-PARTY.md` (what others made), `SHARING.md` (before you publish), `RESTORE.md` |

Your own copy will add `core/` (global files), `domains/<scope>/` (one folder per workspace) and, if you like, `ops/`.

## Commands

```powershell
.\tools\playbook.ps1 status               # what drifted (-All lists every file)
.\tools\playbook.ps1 capture -Scope myapp # live -> repo (add -DryRun to preview)
.\tools\playbook.ps1 install -Scope core  # repo -> live (backs up what it overwrites)
.\tools\playbook.ps1 scan                 # secrets and sensitive data (also the pre-commit hook)
.\tools\playbook.ps1 inventory            # write docs/INVENTORY.md: every plugin, skill, agent, hook
```

## Daily flow

1. Edit rules or skills where you always do (the workspace or `~/.claude`).
2. `capture -Scope <name>`, then `git add -A` and `git commit`.
3. Push when you decide to. A line in your global rules file can tell Claude to do steps 1 and 2 and to ask before step 3.

To change a shared skill: edit it in any one workspace, run `capture -Scope shared`, then `install -Scope shared`.
Workspace-specific rules go in that skill folder's `PROFILE.md`, never in the shared `SKILL.md`.

## Safety model

- **Allow-list.** Only paths named in the manifest are copied. Always skipped: `.env*`, `settings.local.json`, keys,
  `.credentials.json`, `*.bak*`, logs, caches, archives, and files over 1.5 MB.
- **Scan.** Blocks tokens and keys, and sensitive identifiers: public IP addresses, emails, Azure subscription ids.
  It checks what git would commit, before every capture and on every commit. A reviewed false positive goes in
  `tools/scan-allow.txt` with a comment. Never allow-list another organisation's data without asking its owner.
- **Redaction.** For files that mix rules with infrastructure details. The patterns name what they hide, so they live
  in git-ignored `tools/redact.local.json`. With that file missing, the tool refuses to copy those files at all.
- **Not copied by design.** Project knowledge (changelogs, runbooks, server notes, session state).
- **Per-machine state** (`.playbook-state.json`) and backups (`~/.playbook-backup`) are never committed.

## Third-party material

`docs/THIRD-PARTY.md` lists plugins, skills and servers made by others that are commonly used with this setup, with
source, licence as recorded, and install command, so you can choose what to adopt.

## Licence

MIT. See `LICENSE`. Third-party projects named in `docs/THIRD-PARTY.md` have their own licences; none of their code is included here.

## Sharing

Read `docs/SHARING.md` before adding anyone or making anything public. Your playbook repo will hold your own
workspace names, paths and rules: keep it private, and publish only a template built from the engine.

## Facts for agents

- Language and runtime: Windows PowerShell 5.1 (`tools/playbook.ps1`). Not tested elsewhere.
- Repo location rule: outside any cloud-synced folder.
- Entry points: `tools/manifest.json` (what is synced), `tools/playbook.ps1` (how), `docs/DESIGN.md` (why).
- Invariants: the manifest is an allow-list; conflicts are never auto-resolved; redacted and json-keys entries are
  never installed over live files; nothing is pushed without the user's yes; a missing redaction file means skip,
  never copy unredacted; workspace names and other identifying details stay out of anything that may be shared.
- Verify after any change: `playbook.ps1 status` shows no CONFLICT, and `playbook.ps1 scan` prints "Scan: clean."
