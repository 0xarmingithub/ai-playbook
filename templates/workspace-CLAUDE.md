# CLAUDE.md (template)

@AGENTS.md

`AGENTS.md` (imported above) holds the rules for this workspace and works with any coding agent. Claude Code
reads `CLAUDE.md` and does not read `AGENTS.md` by itself, so this file loads it. Add only Claude Code mechanics here.

## Playbook sync

The rules, skills, agents and hooks of this workspace may be mirrored in a personal playbook repo. After you change a
`CLAUDE.md`, `AGENTS.md`, skill, agent, hook or settings file here, follow the "Playbook repo" section of your
user-level rules (`~/.claude/CLAUDE.md`). If you have no such section, ignore this paragraph. It names no path on
purpose, so it is safe in a folder other people use.

## Claude Code mechanics

- Subagents: <<FILL: which ones exist, what each may touch, what to check after each run>>
- Hooks: <<FILL: which hooks guard this workspace, and what each one blocks>>
- Skills: <<FILL: the skills that matter here, and when each fires>>
- Several sessions on one checkout? <<FILL: yes or no. If yes: commit only the files your task produced, by name>>
