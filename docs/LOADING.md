# What Claude Code loads, and how to check

A rule file that is never read looks the same as one that is. Nothing errors. The file sits there,
correct and committed, and the assistant behaves as if it did not exist. This page lists what Claude
Code loads on its own, and how to prove that a given file reached the session.

Scope: Claude Code only. Other tools read other files (for example `.github/copilot-instructions.md`
or scoped instruction files), and some rank `AGENTS.md` above `CLAUDE.md`. If you add a second tool,
look up what it reads before you copy anything, and re-check this page.

## What loads, and when

| Artifact | When it loads |
|---|---|
| `~/.claude/CLAUDE.md` | Every session, every workspace |
| `CLAUDE.md` in the working folder and its parent folders | Every session started there |
| `CLAUDE.md` in a subfolder | When the assistant reads files in that subfolder |
| `@path/to/file.md` inside a `CLAUDE.md` | Inlined with the file that names it |
| `AGENTS.md` | Read on its own only when no `CLAUDE.md` exists in the working folder or above it (newer versions only). With both present, only `CLAUDE.md` loads, so import it with a line `@AGENTS.md` |
| `.claude/rules/*.md` and `~/.claude/rules/*.md` | At session start, or only when a matching file is open if the rule sets a `paths` field |
| `.claude/skills/<name>/SKILL.md` and `~/.claude/skills/<name>/SKILL.md` | The description is always in context. The body loads when the task matches it, or when you run `/<name>` |
| A skill with `disable-model-invocation: true` | Only when you run it by name |
| `.claude/agents/*.md` | Read at session start. A new agents folder needs a restart |
| Hooks and permissions in `settings.json` | At session start. Edit, then restart or reload |
| `settings.local.json` | Per machine. Never copy it into a repo |

This table was checked against the Claude Code memory and skills documentation on 2026-11-19. Versions
differ (for example, reading `AGENTS.md` directly needs a recent release), so check the documentation for
your version before you rely on a row.

## Two shapes that work for `AGENTS.md`

- **Rules in `AGENTS.md`, one line in `CLAUDE.md`:** `@AGENTS.md`. Any agent that reads `AGENTS.md`
  sees the rules, and Claude Code reads them through the import. This is the shape the templates use.
- **Rules in `CLAUDE.md`, no `AGENTS.md`.** Pick this if you only use Claude Code.

Never keep full copies in both files. They drift, and a tool that reads both loads each copy.

## Prove it loaded

1. Put a distinctive sentence in the file, for example a made-up codeword.
2. Start a fresh session in the workspace and ask the assistant to quote that sentence.
3. If it cannot, the file is in the wrong place, the import path is wrong, or the session predates
   the edit. Fix that before you build anything on top.

For a skill: ask a question that uses the words in its description and look for behaviour only the
skill produces (a named checklist, a fixed output shape). A skill that never fires gives no error,
only a slightly worse answer. Run `/<skill-name>` once to prove the file is found.

## If it does not work

| Symptom | Likely cause |
|---|---|
| The assistant ignores the rules | Wrong file name or folder. `AGENTS.md` with no import line |
| Rules worked, then stopped | A new file now takes precedence over the old one, or the import line was removed |
| A skill never fires | Its description does not use the words you type. Rewrite it, then test again |
| A new subagent is missing | Restart the session. The agents folder is read at start |
| An edit to a rule file has no effect | The session started before the edit. Start a new one |
| A rule is applied twice | The same text sits in two files that both load. Keep one copy and point to it |

## Where to put a rule

Ask which file loads where before you write the rule. A rule placed where only one tool reads it
has not been fixed for the others. Universal rules go in the user-level `CLAUDE.md`. Workspace rules go
in the workspace `CLAUDE.md` or `AGENTS.md`. A procedure that only some tasks need goes in a skill.
