# ADR 0005: Optional Engineering DPF Suite Source

Status: accepted locally, 2026-09-10; not a publication record.

## Decision

Keep Engineering DPF Suite as a separately versioned, read-only reference source.
The optional local setting `engineering_suite_loader` selects a user-authorized
helper for per-task temporary acquisition and release. It does not replace
Core/protocol caches or grant permission to update user-authored frameworks.

The public skill supplies read and source-selection instructions only. An
external helper, if configured by the user, obtains source material outside
the sandbox on demand. No Suite background refresh or six-hour timer is needed.
Its implementation, permissions and installation are separate responsibilities.

## Consistency And Failure

Resolve one commit snapshot per task. Retain source editions and provenance.
Validate structural entrypoints before switching the current pointer; structural
validity is not evidence of semantic accuracy or successful Method use.
Reuse the acquired snapshot within the task and disclose its cached status.
If initial acquisition fails, report the missing source; no permanent fallback
is assumed. Retain another task's source only with its own explicit lifecycle.
Missing Suite blocks only the work that needs it. Do not execute fetched source.

Include same-commit Core as an additional reference for Suite dependencies that
are absent or different in the ordinary Core cache. Disclose differing versions
and recheck the affected claims instead of pretending chunks were refreshed.

## Alternatives And Limits

Manual attachments add repeated work. Repointing the Core mirror at upstream
would lose its separate chunk contract. Bundling the complete Suite into every
skill release duplicates source maintenance. This optional read contract avoids
those couplings while leaving public users responsible for external setup.

The initial persistent-cache proposal was rejected for local disk usage. Each
task instead releases its marked source directory once its inputs are no longer
needed, after storing authored DPFs and commit-pinned provenance outside it.
Concurrent tasks do not share deletion ownership. Crash leftovers need explicit
review/cleanup; no age-based reaper is implied. Later tasks need network again.
No automatic DPF update follows from source availability: promotion/publication
requires impact review, source checks and authorization.

See [engineering-suite.md](../../skills/fpf-work-guide/references/engineering-suite.md).
