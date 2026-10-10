# Third-party skills, plugins and servers

Everything here was written by someone else. It is listed so you can decide, one item at a time, what to adopt.
Nothing in this file is installed for you, and no copy of these projects is included in this repository.

**How to read the columns.** *Licence* shows only what the project's own files record. "not recorded" means it could
not be verified: read the source before reusing. This list was checked against local files on 2026-10-10. Re-check
the source for current versions and licences.

## 1. Plugins (install from their marketplaces)

Add a marketplace once, then install: `/plugin marketplace add <owner/repo>` then `/plugin install <plugin>@<marketplace>`.

| Plugin | Marketplace source | What it does | Licence |
|---|---|---|---|
| `codex` | `openai/codex-plugin-cc` | Hands tasks to OpenAI Codex as a second reviewer or implementer | not recorded |
| `i-have-adhd` | `ayghri/i-have-adhd` | Shapes every answer for an ADHD reader: next action first, numbered steps, short lists | not recorded |
| `mattpocock-skills` | `mattpocock/skills` | Engineering skills: TDD, diagnosing bugs, code review, grilling, specs, tickets, handoff | not recorded |
| `show-me`, `visual-pr`, `improve-claude-md` | `humanlayer/skills` | Visual explanations; visual pull requests; rewrites a CLAUDE.md for better adherence | not recorded |
| `answer-me-with-html` | `QingYunA/answer-me-with-html` | Turns an answer into a one-page visual HTML explainer | not recorded |
| `auto-handoff` | `obie/auto-handoff` | Writes a handoff document so a fresh session can continue | not recorded |

Anthropic's own marketplaces: `anthropics/claude-plugins-official`, `anthropics/knowledge-work-plugins`,
`anthropics/claude-plugins-community`.

## 2. Skills installed globally

These sit in `~/.claude/skills`. Find them at the source and install them yourself if you want them.

| Skill | What it does | Source and licence as recorded in the skill |
|---|---|---|
| `archify` | Architecture, workflow and sequence diagrams as standalone HTML | author `tt-a1i`, MIT, based on `Cocoon-AI/architecture-diagram-generator` (MIT) |
| `diagram-design` | 27 branded diagram types as HTML/SVG | MIT; author not recorded |
| `fde-engagement`, `fde-readout` | Forward-deployed-engineering delivery lifecycle; decision readouts | author `likamrat`, MIT |
| `hallmark` | Anti-"AI slop" design rules for pages and redesigns | version 1.1.0; licence and source not recorded |
| `claude-api` | Reference for the Claude API and SDKs | Anthropic; terms in the skill's `LICENSE.txt` |
| `codebase-memory` | Companion skill for the `codebase-memory-mcp` server (section 3) | source not recorded |
| `kimi-webbridge` | Controls your real browser through the Kimi browser extension | needs that extension; licence not recorded |
| `skill-doctor` | Grades your skills from real conversation history | licence and source not recorded |

Skills delivered through your Claude account (for example by an organisation administrator) are not redistributable
here. They show up in your own inventory (`playbook.ps1 inventory`).

## 3. MCP servers (names only)

| Server | What it does |
|---|---|
| `codebase-memory-mcp` | Code knowledge graph for structural questions. Source not recorded; check its project page |
| `docs-mcp-server` | Indexes documentation for search |
| `chrome-devtools` | Browser debugging and performance traces |
| `mcp-image` | Image generation |

Server definitions can hold tokens. Never store them in a playbook repo: record names only.

## 4. Skills others publish that are often adapted

These are public projects whose skills have been adapted for private use. Copies are not included here. Install from
the source, or write your own.

| Skill | Source | Licence as recorded |
|---|---|---|
| `humanizer` | `blader/humanizer` | MIT |
| `systematic-debugging` | `obra/superpowers` | MIT |
| `test-driven-development`, `testing-anti-patterns`, `defense-in-depth-validation` | `obra/superpowers-skills` | not recorded |
| `improve-codebase-architecture`, `grill-me`, `caveman`, `write-a-skill` | `mattpocock/skills` | not recorded |
| `tech-debt-audit` | `ksimback/tech-debt-skill` | not recorded |
| `gemini-api` | `google/skills` | not recorded |
| `skillspector` | NVIDIA SkillSpector (`pip install git+https://github.com/nvidia/skillspector.git`) | Apache 2.0 |
| `technical-documentation` | `dsebastien/technical-documentation-skill` | Apache-2.0 |
| `deep-audit` | drew on a public gist and the `openclaw/openclaw` test-audit skill | not recorded |
| `llm-council` | origin not recorded | MIT |
| foundation of a `.claude/skills` system | `addyosmani/agent-skills` | not recorded |

## 5. Keeping your own list

When you install or adapt something, add a row: name, source, licence as the source states it, and whether a copy sits
in your repo. A copy with an unknown licence should stay out of any repo you make public (see `docs/SHARING.md`).
