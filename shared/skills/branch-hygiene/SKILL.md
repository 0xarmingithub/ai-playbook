---
name: branch-hygiene
description: >
  Before opening a pull request or handing a session back: check that mirrored copies changed
  together, and remove scratch files from the repository. Use before a PR, before hand-back, or
  when a tmp_ or scratch file may be left in the tree.
---

# Branch hygiene

## Mirrored copies change together or not at all

Where the same logic exists twice, the diff shows only the copy you opened, so a one-sided
change is silent until something downstream breaks. Common pairs: a shell script and its
PowerShell twin, two host trees for one service, a rule enforced at two scopes, a script and
the diagnostic that inspects it, and any file kept byte-identical in two repositories.

Keep the list of known pairs in the workspace rule file (add a pair the first time it is
named). Before the pull request:

```powershell
git diff --name-only <default-branch>...HEAD
```

Confirm each known pair appears on both sides, or on neither. A sweep carries the same duty: an
encoding, version or security sweep that covered the scripts but not the documents shipped
beside them has not been run on the change.

## Scratch files

Write scratch scripts, dumps and captures outside the repository. Anything inside the tree can
be committed, picked up by a recursive publish pattern, or shipped. If one lands inside, name
it `tmp_<purpose>` and delete it before hand-back. Detect strays by prefix, never by extension:

```powershell
Get-ChildItem <repo> -File -Force | Where-Object { $_.Name -match '^(tmp|scratch|out|dbg)[-_.]' }
Get-ChildItem <repo> -File -Force | Where-Object Length -eq 0
```

The second line catches residue named after a real artifact, such as a truncated download.
Report what you find. Delete only what you created this session.

## Branch folders

Keep the folder that holds your clones for clones only. Make any other checkout with
`git worktree add <path> -b <branch>` in a sibling folder. When the PR completes, remove it with
`git worktree remove <path>`, then `git branch -d <branch>`, `git worktree prune` and
`git remote prune origin`. Never delete a worktree folder by hand. If `worktree remove` refuses,
the tree holds uncommitted work: report it, do not force it.
