---
name: pre-close-verification
description: >
  Cross-repository sweep before declaring a body of work closed: open pull requests, unmerged
  branches, the latest CI run, linked tickets. Use when asked to run a full check before closing
  out, make sure nothing is pending, or confirm all PRs are merged and pipelines green across
  several repositories.
---

# Pre-close verification across repositories

After a change lands in more than one repository, ask the hosting service, not your memory, what
state each one is in. Run this before `end-of-session`, which cleans the current checkout.

## Procedure

1. **List every repository the work touched.** Derive the list from the pull requests and
   commits made in this session, not from what usually changes together.
2. **For each repository, check three things and report each one:**
   - No pull request from this work is still open
     (`gh pr list --state open`, or your host's equivalent).
   - The working branch is merged into the default branch, and the local and remote copies of
     the feature branch are gone (`git branch --merged main`, `git branch -r --merged main`).
   - The latest relevant CI run succeeded. Cite the run id. "Should have passed" is not a
     citation.
3. **Check the linked tickets or work items.** Done work should not still be open. Check that
   pull request text carries no accidental auto-links. On some hosts a bare `#123` links an
   unrelated item.
4. **Name each gap.** "Repo X still has PR 1234 open" beats "mostly done, maybe check X".
5. **Run `end-of-session` last,** only after every repository is clean.

## Anti-pattern

Answering "all green and merged, can we close this?" by summarising what was built. The
question is about current state. Re-query every repository.
