---
name: end-of-session
description: >
  Close-out pass before handing work back: verify with evidence, update docs, clean up scratch
  files, branches and worktrees. Use when the user says wrap up, we are done, hand back, close
  out, or before you claim a task is complete.
---

# End of session

Goal: leave a state another person, or a later session, can pick up with no questions. Run it
in the same response as the last change, not later.

## 1. Verify

- [ ] Every "done" claim cites a test run, health check, query result or captured response.
- [ ] Each cited check could have gone red. Say in one line what result would have failed it.
- [ ] The change was exercised, not only written.

## 2. Document

- [ ] The history log (changelog, handoff note) says what changed and why.
- [ ] The current-state reference matches reality. Resolve values from the live artifact, not
      from another document.
- [ ] Find every document the change made untrue by searching the repo for the superseded
      value. Zero hits is the goal. Reading the docs is not a substitute: reading is what fails.
- [ ] New non-obvious facts are recorded in the matching notes file.

## 3. Clean up

- [ ] Scratch files are removed. Detect them by prefix, not by extension, because scratch is
      mostly `.ps1`, `.sh`, `.json` and `.txt`:
      `Get-ChildItem <repo> -File -Force | Where-Object { $_.Name -match '^(tmp|scratch|out|dbg)[-_.]' }`
- [ ] Zero-length files at the repo root are checked. They are usually a truncated download,
      or a shell redirect typo (a file literally named `-`), and a prefix filter misses them:
      `Get-ChildItem <repo> -File -Force | Where-Object Length -eq 0`
- [ ] Anything you did not create this session is reported, not deleted.
- [ ] `git status` shows only intended changes. Generated files are ignored, not committed.
- [ ] No credential material is tracked:
      `git ls-files | Select-String '(\.pfx|\.cer|\.key|\.p12|\.env)$|secret|password'`
      Review every hit.
- [ ] Merged branches are deleted. Their worktrees are removed with `git worktree remove`,
      never by hand. Remote-tracking branches are pruned if you pushed.

A detection command that returns nothing is evidence only if it was capable of matching.

## 4. Hand back

Say what changed, what was verified and how, and what is left open or risky. End with one
concrete next action.
