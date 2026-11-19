# Writing and testing a skill

A skill is a folder with a `SKILL.md`. Its short description is always in context. The body loads only
when the task matches the description, or when you run the skill by name. That makes it the right
home for a procedure that some tasks need and most do not.

## Where they live

| Place | Reaches |
|---|---|
| `~/.claude/skills/<name>/SKILL.md` | Every workspace on this machine |
| `<workspace>/.claude/skills/<name>/SKILL.md` | That workspace |
| `shared/skills/<name>/SKILL.md` in this repo | The canonical copy. Install it byte-identical where it is needed |

A workspace skill and a user-level skill with the same name collide. Rename one, or keep the
workspace one and delete the other.

## Anatomy

```yaml
---
name: my-skill
description: What it does, and WHEN to use it, with the phrases a person would type.
disable-model-invocation: true   # optional: only runs when invoked by name
---
```

The body is a procedure: numbered steps, checklists and decision tables. Put long reference
material in a neighbouring file the body points to, so it loads only when needed.

## What makes a good one

- **A sharp description.** The model matches on this text alone. Name the trigger phrases, and
  say what the skill is not for.
- **One domain per skill.** A skill that covers everything fires for everything.
- **Procedure over prose.** A numbered list is followed more reliably than a paragraph.
- **Few skills.** Every installed skill adds its description to every request, and overlapping
  descriptions make it harder to choose the right one. Install what you use.
- **Positive wording.** Write each step as an action. The `directional-prompting` skill shows how.
- **Specifics live beside the skill.** For a skill installed unchanged in several workspaces, put
  the differences in a `PROFILE.md` next to it. Never fork the shared file.

## Test that it fires

1. Ask for the task using words from the description.
2. Look for behaviour only the skill produces: a named check, a fixed output shape.
3. Ask for it again in different words. A skill that fires only for your exact phrase has a
   description that is too narrow.
4. If it does not fire, check the folder first, then the description, then restart the session.

## Third-party skills

Treat a skill from someone else as code that will run with your permissions. Read it before you
install it. See "Vetting before adoption" in `THIRD-PARTY.md`. If you keep a frozen copy in a
repo, record where it came from, which version, whether upstream still ships it, and how to
refresh it, in a provenance table next to it, and keep the licence notice with the copy.
