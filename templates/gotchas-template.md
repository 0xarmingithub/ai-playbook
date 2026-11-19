# Area gotchas (template)

Copy this to `gotchas-<area>.md`, one file per area. Read it before non-trivial work in that area.
Add an entry in the same turn a correction lands or a non-obvious trap is diagnosed.

Rules for entries:

- One entry per trap. The title is a short imperative: "Sequential writes time out", not
  "Performance issue".
- Verified facts only. Delete an entry that turns out to be wrong.
- No dates, ticket numbers or change stories in the entry. Say what is durably true. History goes
  in the changelog.
- No resource ids, internal host names or credentials. Keep the pattern and the fix.
- Link to the working reference for values that change. A value copied into two places goes stale
  in one of them.
- Past about 40 KB, turn this file into an index of headings and move detail into part files.

Where the mechanism is the lesson (why a check passed when it should have failed), flowing prose
under the heading reads better than the four labels. Use the labels for a trap with one crisp
cause and one fix.

---

## <<FILL: Imperative trap title>>

**Symptom:** What you see. The exact error text, or the unexpected behaviour, and where.

**Root cause:** The mechanism, not the symptom.

**Fix:** What to do. Copy-pasteable where possible.

**Verified:** The evidence, and what result would have made the check red. "Tests pass" is not
evidence if the tests could not have failed.

---

## Suggested sections for a service

- Startup traps: environment variables that must be set, order of loading.
- Auth and token lifetime.
- Writes and consistency.
- Retries and timeouts.
- Dependency pinning.
- Pipeline behaviour.
- Gaps in monitoring.
