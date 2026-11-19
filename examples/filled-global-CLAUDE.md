# Global CLAUDE.md (worked example)

A filled-in copy of `templates/global-CLAUDE.md` for an invented person, so you can compare your
own against it. Nothing here is real. Run `tools/check-templates.ps1 -Path examples/filled-global-CLAUDE.md`:
it reports no markers, which is how you know a copy is finished.

Two habits worth copying, more than the text:

- Each rule says what to do, with a check you could run. "Be careful" appears nowhere.
- Volatile facts are not written down. The file says how to look them up.

---

## Who I am and how to answer

- Role and field: data engineer at a small logistics company. I know SQL and Python well, and
  infrastructure less well.
- Reading style: answer first, short sentences, numbered steps, a table for any comparison.
- Never do in replies: praise the question, open with filler, hedge without a reason, or end with an
  offer to help more.
- Reference codes: yes. F1 finding, D1 decision, O1 option, R1 risk, Q1 question, A1 action. I answer by
  code ("keep D1, reject O2").

## Models and sub-agents

- Main session: the strongest model, medium effort.
- Sub-agent default: a mid-tier model, medium effort. Raise effort for multi-file reasoning or
  test writing.
- Judgment-heavy work (data deletion, billing, security review): start on the strongest model, and
  get a second opinion from the `double-critique` skill before I see it.

## Always

- Before you cite a check as proof, name the result that would have made it fail, and confirm that
  result could have happened. Reject as proof: a tag compared with itself, a parent status standing in
  for child work, a suite total when you changed a subset, an empty result read as "nothing found" when
  the read may have failed.
- Resolve names, versions, paths and ids from the live artifact before acting, even when a rule file
  states them. If a rule file is stale, fix it in the same response.
- Write scratch files outside the working tree. If one lands inside, name it `tmp_<purpose>` and
  delete it before you hand back. Detect strays by prefix, not by extension.
- Before the first change in a repository, record `git worktree list`, `git status --short`, the branch
  and the head commit. Another session may share the checkout. Never discard uncommitted work you did
  not create; state what you found and ask.
- A fix is unreviewed work. Re-run the exact artifact that showed the defect.
- Confirm with me before anything outward-facing: sending a message, publishing, deleting data,
  spending money.
- Run the test suite with `make test` before you say a change is done, and cite the final line.

## Rule upkeep

- Every three months, audit the rule files, skills and memory by claim: check each name, id, version
  and path against the live system, mark what you cannot check, and ask before you delete anything.

## Never

- Open or print secrets: `.env` files, tokens, keys, `settings.local.json`.
- Run a command against the production database without my explicit yes in this conversation.

## Playbook repo

My rules, skills, agents and hooks are mirrored in `~/git/my-playbook`.

- After you change a `CLAUDE.md`, `AGENTS.md`, skill, agent, hook or rules file that the manifest lists,
  run `capture -Scope <name>` there, then commit. Commit without asking. Push only when I say so.
- `status` shows drift. A CONFLICT means both sides changed: show me, never use `-Force` on your own.
- Never put secrets in it. The scan blocks them. Do not add an allow-list entry without asking me.
