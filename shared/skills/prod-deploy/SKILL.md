---
name: prod-deploy
description: >
  Optional template. Production deployment sequence with falsifiable verification: confirm
  context, promote the artifact the lower environment verified, deploy by digest, verify by
  digest. Use when asked to deploy, promote, roll out or release to production. Fill in the
  placeholders for your stack before relying on it.
---

# Production deploy (template)

Stop at the first failed check. Replace every `<placeholder>` with your own values first. If
your stack has no container images, keep the structure and swap the digest steps for your
artifact's immutable identifier (a build id, a commit hash, a content hash).

## 1. Confirm context

Print the account, tenant and project you are about to act on, with a command, and compare it
with `<production account>`. Shared context is process state: another session can move it, so
read it again right before each mutating call.

## 2. Confirm the lower environment verified this exact artifact

- [ ] The test suite passed there. Cite what the run printed, not a remembered count.
- [ ] The same artifact, by digest or content hash, is deployed there. A rebuild of the same
      commit is a different artifact.

## 3. State what is changing

Component, artifact id, the change, your assumptions. If you cannot name the exact artifact,
stop.

## 4. Record the ownership baseline

Anything unaccounted for in the tree or on the branch belongs to another session. State what
you found and ask.

## 5. Deploy through the path of record

Use the release definition that owns production. A build definition should not be able to
reach production; a manual command is break-glass only.

Never reference a container image by a mutable tag. An unchanged tag creates no new revision,
so the command succeeds and ships nothing. Use `<registry>/<repo>@sha256:<digest>`.

Where two pipelines write the same resource, serialise them. They silently revert each other.

## 6. Verify, and name the red case first

Write down what result would mean the deploy failed, and confirm that result was reachable.

- [ ] The digest on the live resource equals the promoted digest. Not the tag.
- [ ] A new revision or instance exists, created inside the deploy window.
- [ ] It reached a healthy state. Poll: rollouts are asynchronous and tens of seconds is normal.
- [ ] A request through the front door exercises the change.

A health endpoint returning success proves the previous instance is alive. A version string the
service reports is usually tracked apart from the artifact.

## 7. Close out

- [ ] Switch context back to the default environment and confirm it.
- [ ] Changelog entry cites the evidence, including the promoted digest.
- [ ] The current-state reference holds durable facts only (names, routes), never a mutable tag.
- [ ] Any non-obvious fact is recorded in the notes file.

## Rolling back

There is no rollback button: rolling back means promoting an earlier artifact. Find the last
known-good artifact, run the release definition pinned to it, verify from the child run's own
timeline. Do not rebuild from a source tree that has moved on.
