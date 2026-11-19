---
name: session-start
description: >
  Load the right context and record an ownership baseline before the first change. Manual only:
  run it with /session-start at the start of work that edits files, deploys, or touches shared
  state.
disable-model-invocation: true
---

# Session start

Walk this before the first edit, deploy or other mutating call. The aim is to enter the work
with the right facts loaded, so the first action is correct and not a guess.

## 1. Say what the request touches

List the components or areas involved. For each, name where its notes live (a notes file, an
architecture doc, a README). Read the matching notes before non-trivial work in that area.

## 2. Load real values

Open the project's current-state reference for the area in scope. Read names, ids, paths and
versions from it, then resolve any volatile one from the live artifact. Do not guess.

## 3. Read the architecture, only for structural changes

If the change touches internals or flows across components, read the design doc first. Skip it
for small local edits.

## 4. Record the ownership baseline

Other sessions, human or agent, may be working in the same checkout. Record what is already
there and keep the output:

```powershell
git -C <repo> worktree list
git -C <repo> status --short
git -C <repo> branch --show-current
git -C <repo> log --oneline -1
```

Add the equivalent for shared cloud context: the active account, subscription or project.

Everything in that baseline belongs to someone else. Uncommitted work was never written to the
object database, so no command can bring it back. Never discard, reset, stash or clean it on a
guess about where it came from. State what you found and ask.

Two traps this catches: a second checkout of the same repo may exist (branching from the wrong
ref silently omits other work), and shared cloud context can change under a long task, so
re-read it right before each mutating call.

## 5. Confirm the environment

State which environment the session targets. Verify it with a command, not from memory.

## 6. State the plan

Before any multi-step or irreversible action, give a short plan and the check you will use to
confirm it worked. Then proceed.

## Long-session drift

Behaviour can drift from the rules in a long conversation. If a rule seems dropped, run this
skill again or restate the rule inline.
