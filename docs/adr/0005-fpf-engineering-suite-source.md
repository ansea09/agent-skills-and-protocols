# ADR 0005: Optional Engineering DPF Suite Source And DPF Discovery

Status: accepted, 2026-09-11. Publication identity is recorded by the merging PR.

Personal cache lifetime superseded on 2026-09-14 by
[ADR 0006](0006-persistent-engineering-suite-cache.md). The temporary acquisition
and permission route below remains historical/legacy, not the active personal mode.

## Context

DPF authoring, updating and review should be discoverable without requiring
users to remember a skill invocation. Suite sources need not occupy permanent
local storage or be downloaded for ordinary FPF answers. Source acquisition,
skill selection and successful DPF authoring are separate operations.

## Decision

Keep Engineering DPF Suite as a separately versioned, read-only reference source.
The optional local setting `engineering_suite_loader` selects a user-authorized
helper for per-task temporary acquisition and release. It does not replace
Core/protocol caches or grant permission to update user-authored frameworks.

The public skill supplies read and source-selection instructions only. An
external helper, if configured by the user, obtains source material outside
the sandbox on demand. No Suite background refresh or six-hour timer is needed.
Its implementation, permissions and installation are separate responsibilities.

Include DPF creation, update and review explicitly in the skill description.
After selection, the agent follows the Suite reference only for work that needs
it. Opening a chat alone does not trigger a download. This is instruction-based
routing, not a deterministic application hook or guaranteed implicit selection.

The public package does not provide an out-of-the-box Suite downloader. Users
must configure a trusted local helper or supply sources for Suite-dependent
work. No local machine settings or personal helper paths are published.

## Consistency And Failure

Resolve one commit snapshot per task. Retain source editions and provenance.
Validate structural entrypoints before switching the current pointer; structural
validity is not evidence of semantic accuracy or successful Method use.
Reuse the acquired snapshot within the task and disclose its cached status.
If initial acquisition fails, report the missing source; no permanent fallback
is assumed. Retain another task's source only with its own explicit lifecycle.
Missing Suite blocks only the work that needs it. Do not execute fetched source.

An `external-download-required` result is an acquisition block, not a successful
refresh. The agent must disclose it and cannot claim to have read Suite. A
draft using other available sources must identify that different basis. The
contract does not authorize bypassing sandbox restrictions or guarantee an
agent will successfully request and execute an outside-sandbox operation.

### Authorized Acquisition Transition (2026-09-11)

The agent now requests the host's approval-capable execution operation before
Suite acquisition, instead of treating the helper's sandbox refusal as a host
permission denial. In Codex this is exec_command with require_escalated, not a
chat-only consent question or an ordinary shell retry. The reference includes
the bounded command and outcome handling. No change to the helper guard,
sandbox policy, scheduler or global environment is required.

Only within the approved external child process, remove the inherited advisory
CODEX_SANDBOX_NETWORK_DISABLED variable. Removing a variable is not permission
or proof of a sandbox boundary; the host execution tool is the authority. If
the host denies external execution or does not expose it, stop. Do not retry
through another tool to evade that decision. A permitted but failed operation
remains a failure with its actual diagnostic. No unattended success guarantee
is introduced by this instruction change.

The earlier 0.2.1 probe remains failed at acquisition; do not rewrite that
historical result. Follow-up checks are recorded separately in
[authorized-acquisition evidence](../release-evidence/fpf-suite-authorized-acquire.md).

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

## Validation And Reopen Conditions

The [discovery probe](../release-evidence/fpf-dpf-discovery-0.2.1.md) observed
implicit selection, Suite-reference reading and helper invocation in one new
local task. Acquisition was blocked; Suite-based authoring was not demonstrated.
This is not a causal before/after test or evidence for every DPF request.

Revisit routing if creation/update/review requests miss the skill. Revisit
integration if a supported deployment is expected to download without manual
setup, or if source layout, helper output or host permissions change. Test the
affected boundary rather than weakening permission checks to obtain a pass.
