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
| `show-me` | `humanlayer/skills` | Visual explanations | not recorded |

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
| `claude-image-gen` | Image generation with Gemini and OpenAI; used as the base of a self-hosted, organisation-wide connector (not installed per machine). Source: github.com/guinacio/claude-image-gen. Licence: MIT |

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

### Skill sets published by vendors

| Skill set | Source | Licence as recorded |
|---|---|---|
| `azure-*`, `entra-*`, `microsoft-foundry` and related (about 28 skills) | `microsoft/azure-skills`, folder `.github/plugins/azure-skills/skills/` | MIT, declared in each skill's own frontmatter |

Install such a set from its source, not from a copy someone else froze. Pick only the skills you
use: each one adds its description to every request, and overlapping descriptions make the
right choice harder. Check the source for current names; they change.

## 5. Vetting before adoption

Run this before you install a skill, MCP server or plugin that did not come from a first-party
vendor or from your own folders.

1. **Read it.** A skill is instructions plus scripts that run with your permissions. Look for
   downloads piped to a shell, `eval`, encoded blobs, reads of environment variables or key files,
   and network calls to hosts you do not know.
2. **Check source and licence.** If either is not recorded, do not copy it into a repo.
3. **Scan one skill folder at a time** with a static scanner (SkillSpector, listed above, runs
   offline with `--no-llm`). Pointing it at a whole tree gives a meaningless total, because it
   treats the tree as one skill and flags ordinary provisioning commands.
4. **Read the findings.** Install when the score is low, or when you have reviewed every high
   finding. Treat the score as advice: the tool is young and has one maintainer.
5. **Record it** in your own list (next section), with the date and the result.

Heavy runtime governance proxies are the wrong tool for a local setup: they intercept all traffic
and conflict with corporate proxies and local tooling. Revisit only if you ingest outside registries
at scale.

## 6. Keeping your own list

When you install or adapt something, add a row: name, source, licence as the source states it, and whether a copy sits
in your repo. A copy with an unknown licence should stay out of any repo you make public (see `docs/SHARING.md`).
