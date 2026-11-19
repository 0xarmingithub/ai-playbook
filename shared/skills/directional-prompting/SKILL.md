---
name: directional-prompting
description: >
  Write or review prompts, rule files, skill descriptions, agent briefs and slash commands so a
  model can act on them: open with the outcome (goal, checkable success, stop condition), then
  state every step as a positive action. Use when authoring or auditing CLAUDE.md, AGENTS.md, a
  SKILL.md, a sub-agent prompt, or any text an LLM will read as instructions.
---

# Directional prompting

Two layers. Use both.

1. **Outcome.** Name the destination before any step: what to produce, how "done" is checked,
   and when to stop.
2. **Direction.** Inside that frame, each sentence names an action that moves toward the
   outcome, led by a verb: trace, build, read, return, ask, run.

An outcome with no direction leaves the model guessing the path. Direction with no outcome
walks a clear path to nowhere.

## The outcome block

```
Goal: <one sentence>
Success means:
  - <checkable element 1>
  - <checkable element 2>
Stop when: <explicit condition>
Constraints: <only true invariants: safety, required fields, hard limits>
```

- One goal. Two goals are two prompts.
- Success is checkable. "Valid JSON matching schema X" beats "high quality".
- A stop condition prevents a loop that keeps refining past usefulness.
- Reserve ALWAYS, NEVER and MUST for things that truly cannot vary. Decorating ordinary advice
  with them drains the force from the ones that matter.

## Direction rules

1. Lead the sentence with the verb of the right action.
2. Describe the destination, not the failure: "return JSON matching this schema" beats "do not
   return prose".
3. Pair each prohibition with the positive action that makes the mistake impossible.
4. Fill the prompt with the correct path so the wrong one has no foothold.
5. Cut hedges and warnings ("be careful with", "make sure you do not"). Replace each with the
   concrete action.

| Plants the wrong action | Names the right action |
| --- | --- |
| Do not make assumptions. | Read the file before answering. |
| Avoid `any` types. | Type every parameter and return value. |
| Do not write tests that mock everything. | Call the real function and assert on its return value. |
| Do not be verbose. | Answer in one or two sentences. |
| Try not to break existing tests. | Run the suite after each edit and keep it green. |

## Audit pass

Search the draft for: don't, do not, never, avoid, instead of, rather than, not allowed,
shouldn't, "be careful", "watch out", "make sure you don't". Rewrite each hit as its positive
replacement. If none exists, check the cases below, and if none apply, delete the line.

A negation is fine when:

1. It is a hard safety boundary the model must recognise to refuse (pair it with what to do
   instead).
2. It separates two near-identical paths: "use `pytest`, not `unittest`; this project is on
   pytest."
3. The allowed space is too large to list and the forbidden space is small.
4. A positive paraphrase would be vaguer than the plain ban.

## Final read

Read the finished prompt through. Every sentence should name the destination or a step toward
it. Delete any that does neither.

Apply this when you write: system prompts, rule files, skill bodies and descriptions, tool
descriptions, slash commands, sub-agent prompts, eval rubrics.
