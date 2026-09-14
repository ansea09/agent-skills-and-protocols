# ADR 0006: Persistent Engineering Suite Cache

Status: accepted, 2026-09-14; local candidate, not a publication record.
Supersedes the personal temporary-cache choice in ADR 0005. The legacy
temporary helper remains supported for installations that explicitly select it.

## Decision

Use an explicitly configured dedicated persistent Suite cache. The optional
engineering_suite_cache_root reader setting takes precedence over the legacy
engineering_suite_loader. Agents read one validated immutable commit snapshot
for a task and never fetch or delete that shared cache in ordinary task use.
The existing external FPF job supplies refresh; the reader and writer must use
the same root. Public distribution contains the reader contract, not the
personal job, LaunchAgent or machine configuration.

Keep Core and Suite state and failure reporting separate. The personal wrapper
runs Suite when configured, even if Core subsequently reports a failure. Suite
failure is logged but does not turn a valid Core result into a failure; the
status command exposes the Suite result independently and warns on a failed
last attempt. A valid old snapshot remains usable after fetch failure.

The existing personal scheduler polls every 900 seconds and triggers on a new
session-index ID or Core refresh-attempt TTL of 21600 seconds. The joint job
uses that trigger; no second timer is added. This is neither an exact app-start
event nor a hard six-hour availability guarantee. Sleep, network failures,
session-index changes and independent Core refreshes can affect scheduling.
Supply the root explicitly in the LaunchAgent environment: an inherited
environment can bypass env-file discovery. Never disable sandbox restrictions.

## Snapshot Lifetime And Cost

The writer shallow-fetches upstream, validates the required layout, exports an
immutable snapshots/<commit> tree and atomically replaces current.env only after
validation. Matching Core and licenses are retained for Suite dependencies.
Readers pin the commit once, not a moving pointer for each pattern read.

Repeated refresh at the same commit reuses files. Distinct commits retain old
snapshots to avoid deleting another task's live source. No automatic pruning
is implemented; disk usage grows with upstream revisions. Pruning requires a
separate maintenance window without active readers. Stale writer locks require
inspection before removal. These limits are explicit, not automatic recovery
or bounded-disk guarantees.

## Migration And Verification

Switch the personal reader setting from loader to cache root, configure the
same writer root in env files and LaunchAgent, install the external job/updater,
reload the existing agent and perform an authorized initial refresh. Preserve
authored DPFs outside the cache. No temporary lease needs to be repurposed.

Observed locally: 18 disposable-Git tests passed, including cached fallback,
same-commit reuse, sandbox refusal, separate Core/Suite outcomes, lease safety
and invalid layout rejection. Required format, protocol, Bash lifecycle and
plugin structural checks passed; Windows execution is not verified.

An initial attempt omitted the Suite root because inherited environment skipped
env-file loading. Explicit LaunchAgent environment configuration corrected it.
The configured joint job then fetched Suite commit
fba9bffe778115893984407c82cc962aff1481b0 at 2026-09-14T08:32:46Z. Read-only
status inside the sandbox returned cached/read-only for that commit; files were
read successfully. Cache size was about 30 MiB. The loaded LaunchAgent reported
the configured root, 900-second interval and last exit 0. Six hours of wall-clock
operation were not observed; TTL behavior is fixture-tested, schedule is inspected.

## Alternatives And Reopen Conditions

Temporary acquisition saves idle disk space but repeats network/approval work.
A new timer duplicates scheduling and failure ownership. Automatic pruning
without reader tracking risks breaking active tasks. Revisit retention if disk
growth matters, or use explicit reader leases if automatic pruning is needed.
Revisit scheduling if the product requires exact app-start or independent Suite
deadlines. The public helper-install story remains a separate concern.
