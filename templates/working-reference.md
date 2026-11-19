# WORKING-REFERENCE (template)

Copy this to a workspace as `WORKING-REFERENCE.md` and fill every placeholder (two angle brackets, the word FILL, a colon, text). Delete this
paragraph when you do.

**What it is.** The single place that holds every value an assistant or a new person would
otherwise guess: names, identifiers, URLs, paths, versions, environment variables. It describes
current state, in the present tense.

**What it is not.** History. Changes go in the changelog. If a line starts explaining how
something came to be, move it.

**The rule that matters.** A wrong value here is worse than no value, because it loads
automatically and reads as current. For anything volatile (deployed versions, image digests,
branch names, how far behind production is), write how to resolve it live, not a number. Where you
do state a number, say when it was read and by what command.

## Environments

| Environment | Purpose | Account or project | Region | Notes |
|---|---|---|---|---|
| <<FILL: dev>> | | | | |
| <<FILL: prod>> | | | | |

How to confirm which environment this session targets, before any mutating call:

```
<<FILL: a command that prints the active account and project>>
```

## Repositories

| Repository | Local path | Purpose | Default branch | Pipeline |
|---|---|---|---|---|
| <<FILL>> | | | | |

Note any repository with more than one checkout, and any mirrored or parallel source tree. Those
are the places where a change lands on one side only.

## Components

| Component | Source | Language | Deploy target | Deployed by |
|---|---|---|---|---|
| <<FILL>> | | | | |

## Build and release

Say which definition builds and deploys the lower environment, and which one promotes to
production. A reader should be able to tell, without asking, that a build cannot reach production.

## Secrets and configuration

Names and locations only. Never values.

| Name | Stored in | Used by | Rotation |
|---|---|---|---|
| <<FILL>> | | | |

## Versions: resolve live

| What | How to resolve it |
|---|---|
| Deployed artifact | <<FILL: a command that returns an immutable id, not a tag>> |
| Latest build | <<FILL>> |

## Local conventions

| Purpose | Path |
|---|---|
| Scratch files (outside the repo) | <<FILL>> |

## Upkeep

Update this file in the same response as the change that makes a line untrue. Where a value can be
checked by a script, prefer the script to a table row.
