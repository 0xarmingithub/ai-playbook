# Before you share your playbook

Your own playbook repo mirrors your rules, so it carries your workspace names, folder paths, employers, clients and
internal details. Treat it as confidential. This page says what to check before you add a person or publish.

## Options

| Option | Verdict |
|---|---|
| Keep your playbook private, add trusted collaborators | Possible after you clean its git history and decide what they may see |
| Make your playbook public | No. It holds identifying and possibly third-party content |
| Publish a separate template repo built from the engine | Yes. This repository is that kind of repo |

## What blocks publishing a personal playbook

| ID | Blocker | Fix |
|---|---|---|
| B1 | Content that belongs to other organisations (employer, client, shared drive) | Their owners decide. Leave it out of anything public |
| B2 | Personal data: your name, account handles, folder paths, cloud-drive folder ids, employer names, server addresses, key file paths | Remove it, or keep it only in a private repo |
| B3 | Security and money detail: risk limits, account sizes, the hooks that defend a system | Private only. A map of your defences helps attackers |
| B4 | Licences: copied skills may require a notice, or have no stated licence | Keep only what you can satisfy. Link to the rest (`THIRD-PARTY.md`) |
| B5 | Git history: an old commit can hold what you later removed | Publish from fresh history only |
| B6 | The scan finds patterns, not meaning | A human reads every file before it goes public |

## What collaborators would see

On a personal GitHub repo a collaborator gets write access (read-only needs an organisation), and can read all history.
If that is more than they should see, share a template repo, or split sensitive workspaces into separate private repos.

To add someone, with the owner's explicit yes:

```powershell
gh api -X PUT repos/<owner>/<repo>/collaborators/<username> -f permission=push
```

## Cleaning history

Back up first. If the repo has no other users, push one fresh commit of the current tree over the old history, or delete
and recreate the repo. Deleting needs the `delete_repo` permission: `gh auth refresh -h github.com -s delete_repo`.
Overwriting history can leave old commits reachable by their id on the host for a while, so deleting is the stronger fix.

## Recipe for a public template repo

1. Start from an empty directory, not a clone: no history carries over.
2. Copy only: `tools/` (never `redact.local.json`), `.githooks/`, `.gitattributes`, `.gitignore`, `templates/`, generic
   docs, shared skills whose licence you can satisfy, and a README.
3. Do not copy `core/`, `domains/` or `ops/`: they are your content, not the method.
4. Run `tools/playbook.ps1 scan`, then search for your own names, handles, paths and employers, then read every file once.
   To make this automatic, keep your list of confidential terms in a private place outside the public repo and run it
   from a local-only commit hook (inside `.git`) over added paths, added lines and the commit message. Give the repo a
   neutral commit identity too, because an account handle in an author address is also a personal detail.
5. Add a `LICENSE` for your own text and a `NOTICE` crediting each third-party item you keep.
6. Make the repo public only after steps 1 to 5 pass.
