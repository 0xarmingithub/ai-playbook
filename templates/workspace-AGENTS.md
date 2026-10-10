# AGENTS.md (template)

Router for any coding agent. Keep it short: link to detail instead of copying it.

## What this workspace is

<<FILL: two lines. What it does, and what is at stake: money, production, personal data, other people's data>>

## Commands

- Setup: <<FILL>>
- Verify (the one command that decides "done"): <<FILL>>. A task is not done until it passes, with the count stated.
- Run: <<FILL: and anything that must never be run from this machine>>

## Guardrails (non-negotiable)

| Rule | Why | Enforced by |
|---|---|---|
| <<FILL: never do X>> | <<FILL: what went wrong once>> | <<FILL: hook, test, or "prose only">> |
| <<FILL: always ask before Y>> | <<FILL>> | <<FILL>> |

## Traps

| # | The mistake | The rule that prevents it |
|---|---|---|
| T1 | <<FILL>> | <<FILL>> |

## Every task

- <<FILL: for example "end every report with a PENDING line naming follow-ups not done">>
- <<FILL: for example "a bug fix includes a search for the same pattern elsewhere">>

## When unsure

1. <<FILL: the document that wins over everything>>
2. Fresh evidence over any note: if they disagree, trust what you just measured, then fix the note.
3. Still unclear: ask me, marking each question BLOCKING or OPTIONAL with a proposed default.
