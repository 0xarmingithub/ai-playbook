# Memory and notes conventions

A memory lets an assistant carry facts from one session to the next instead of rediscovering
them. Used well it is the difference between a tool that relearns your project every time and one
that already knows. Used badly it is a pile of stale claims that read as current.

## Scopes

| Scope | Lifetime | What goes here |
|---|---|---|
| User | Every workspace, until deleted | Personal preferences and habits. Keep it tiny: it loads every session |
| Session | One conversation | Working state and the running plan |
| Project | One codebase | Verified build and deploy facts, conventions, gotchas |

## What earns an entry

- A correction the user made that you would otherwise repeat.
- A non-obvious trap that cost real time to diagnose.
- A verified fact about how the project builds, deploys or behaves.
- A stable preference.

Not: anything you can cheaply read from a file, one-off details, guesses.

## Habits that keep it healthy

- **Write when it lands.** Record the lesson in the same turn, not at the end, when it is forgotten.
- **Keep user-scope entries to one line.** They are loaded automatically, so every line costs.
- **One file per area.** A notes file you must read before acting has to fit in context beside the
  task. Past about 40 KB, turn it into an index of headings and move the detail into part files.
- **Read the matching file before non-trivial work in that area.**
- **Do not put dates, ticket numbers or change stories inside an entry.** Say what is durably true.
  History belongs in the changelog and the commit message.

## Audit by claim, not by file

A memory that describes code which has since changed still reads as current. When you audit:

1. List each checkable claim (names, ids, versions, paths, line numbers, merge state).
2. Check each one against the repo or the live system.
3. Correct what is wrong. Mark what you could not check as unverified. Mark a lesson whose code
   has since changed as historical.
4. Never delete a safeguard because it is old. Age is not evidence that the risk is gone.

## Gotcha files

For one area with real traps, keep a `gotchas-<area>.md` from `templates/gotchas-template.md`. Each
entry has a short imperative title and four parts: Symptom, Root cause, Fix, Verified. Strip
identifiers (resource ids, internal host names, ticket numbers) before sharing a file outside the
workspace. Keep the pattern and the fix.

Whether to publish sanitized gotcha files in a public repo is a separate decision. This repository
ships only the template, not anyone's gotchas.
