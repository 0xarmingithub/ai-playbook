---
name: double-critique
description: >
  Two-challenge rule: two sequential expert self-critique rounds, each followed by a full rewrite,
  with EVERY version recorded. Use on written deliverables where being wrong is costly: verdicts,
  audits, preregistrations, root-cause diagnoses, and the rationale for risky changes. PROFILE.md
  next to this file names the classes this workspace requires and says whether the skill runs
  automatically or only on /double-critique. Also invocable as /double-critique on any prior answer.
---

# Double-Critique (the two-challenge rule)

Standing rule: a deliverable in a class that matters gets a second and a third opinion from the
same author, forced into an adversarial stance, before the reader sees it as final. This skill
is the exact procedure.

**Read `PROFILE.md` in this folder first.** It names the deliverable classes for this workspace,
says whether the skill runs automatically, lists the repo rules a critique must check, and holds
the worked examples. This file is identical in every workspace (it is installed from the shared
playbook). Only `PROFILE.md` differs.

## The two challenges (verbatim contract)

**Challenge 1** — after the initial deliverable (v1):
> Critique your own answer as if a subject-matter expert were reviewing it. Identify its
> weak points, gaps, and anything that's lacking or could be misleading, explain why each is
> a problem, and then rewrite the response as a stronger, improved version that addresses
> those issues. Make sure the full report and response is recorded.

**Challenge 2** — after the rewrite (v2):
> One more time: critique your own answer as if a subject-matter expert were reviewing it.
> Identify its weak points, gaps, and anything that's lacking or could be misleading,
> explain why each is a problem, and then rewrite the response as a stronger, improved
> version that addresses those issues. Make sure to update your report md file with the
> initial response as well as all subsequent updates.

## Execution rules

1. **Record everything.** The deliverable's md file carries: v3 FINAL (operative, at top) →
   critique-1 → critique-2 → v1/v2 history (verbatim or as explicit deltas). Chat-only
   answers with no file get the rounds inline. Never overwrite a version; supersede it.
2. **Critiques must draw blood.** A round that finds only cosmetic issues must say WHY the
   substance survived (what was checked and held). Prefer: unstated assumptions, unverified
   load-bearing claims, silently-resolved disagreements, missing confidence statements,
   conclusions outrunning evidence, missing counter-analysis of cost, blast radius and
   rollback, and conformance to the repo rules that `PROFILE.md` lists.

2a. **The predictability gate.** Applies to every challenge point, and to any hypothetical or
   counter-scenario a round invents:

   > **Delete and replace any point whose answer you can predict.** If you already know how the
   > rewrite will answer it, it is not a challenge — it is a rehearsal, and it inflates the round
   > without testing anything.

   A point survives the gate only if it sits on a genuine fault line where **both answers are
   defensible**, and the round states the strongest case for each side before resolving it.
   Steelman both, then decide. A round that resolves every point the same way it drafted them has
   failed round 1 and should be re-run, not recorded as a pass.

   This is the sharper test for rule 2. "Draw blood" says find something real; this says prove the
   thing you found could have gone the other way.
2b. **A FIX is a new deliverable, not an amendment to a discharged one.** When a review (a
   subagent, an outside panel, a stop-gate) returns findings on a change that carried this rule,
   the *fix* re-enters the rule from the top. It does NOT inherit the original change's discharge.
   The evidence for the rule is in `PROFILE.md`.

   Two cheap questions the fix round must answer, because a green test suite cannot:
   - **What did this edit newly make possible?** Not "does it fix the finding" — the reviewer
     already told you that. Defects created by a fix passed green suites because no test
     exercised the state the edit created.
   - **What did it MOVE?** Mutate the guards the fix relocated, not only the ones it added.
2c. **The predictability gate needs a MEASUREMENT, not a better argument.** Rule 2a says delete
   any point whose answer you can predict. The stronger form: if a point turns on a fact about
   the deployed system — what a unit file sets, what signal a supervisor sends, what a filter's
   step size is — the round must **run the command**, not reason about it. Self-critique cannot
   falsify a premise its author does not know they hold; a measurement can, and so can a second
   party. `PROFILE.md` carries the worked example for this workspace.

3. **New evidence beats new rhetoric.** If a critique point is checkable cheaply (a code
   read, a probe, a small computation), CHECK it in the rewrite rather than hedging it.
   A hedge is a critique that gave up.
4. **Scope guard.** Mandatory only for the classes `PROFILE.md` names. For everything else
   state `two-challenge: exempt` and move on. The rounds cost about 3× the output, so they are
   reserved for work where being wrong is expensive. When a deliverable sits on the boundary AND
   real money or production depends on it, run it.
5. **Code deliverables:** round 1 critiques the DESIGN+diff (missed twin call sites, fail-open
   residues, test gaps); round 2 critiques the VERIFICATION (what was actually executed vs
   asserted). Rewrites may change code, not just prose — re-run the checks after.
6. **Version discipline in files:** label sections `v1`, `Self-critique 1`, `v2`,
   `Self-critique 2`, `v3 FINAL (operative)`. The final chat message summarizes v3 and names
   where the history lives. `PROFILE.md` may fix the file location and the message shape.
