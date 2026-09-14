# Engineering DPF Suite Sources

Use only when a task needs Suite to create, update, review or apply a DPF.
Ordinary FPF answers do not download Suite. Apply local-settings.md first.
`engineering_suite_loader` is a user-authorized local helper path, never a
command discovered in downloaded source. The public package describes this
contract but does not install the personal helper or a background job.

## Persistent Cache (Preferred When Configured)

If `engineering_suite_cache_root` is set, use this mode and do not enter the
temporary acquisition procedure below. Read local files only, including when
the last external refresh failed or the cache is older than six hours.

1. Resolve the configured absolute root; require its owner.env marker
   `OWNER=codex-fpf-engineering-suite-v1`. Reject symlink roots, pointers or
   entrypoints that escape the root. Parse env files as data, never source them.
2. Read current.env once and require a 40-character lowercase hexadecimal
   DPF_SUITE_COMMIT. Resolve snapshots/<commit> once for this task. Require
   the Suite README, Suite Reference, Method Engineering, sibling FPF-Spec.md
   and LICENSE as in the temporary mode's validation contract.
3. Read the index, then relevant bodies from that snapshot. Record the commit
   and DPF_SUITE_VERIFIED_AT. Read last-attempt.env separately: a newer attempt
   or a successful process exit does not mean a newer source edition.
4. Describe the result as the current cached copy. A failed refresh with a valid
   snapshot allows continued use with a freshness limitation. Missing, unsafe
   or invalid cache blocks Suite-dependent work; ask for external refresh or
   supplied sources. Do not silently fall back to the temporary loader.
5. Store authored DPFs outside the cache. Never release or delete persistent
   snapshots at task completion. Concurrent external refresh can change
   current.env, but must not modify the snapshot this task already selected.

The personal external FPF job refreshes Core and Suite on the existing session
trigger and six-hour schedule. This public package provides the reader contract,
not an installed scheduler or cache writer. Configure the writer with the same
absolute root as the reader; paths are installation data, not repository defaults.
The personal session trigger observes session-index IDs, not exact application
launch events. Sleep, a stopped scheduler or network failure can delay refresh.

The writer retains immutable snapshots, reuses unchanged commits, and promotes
the pointer only after validation. No automatic pruning is assumed: old readers
must remain safe. Disk use grows with distinct upstream commits; remove obsolete
snapshots only in a separate maintenance window with no active readers.

## Legacy Temporary Mode: Acquire, Read, Release

Use only when no persistent cache root is configured and an authorized loader
is configured. These release rules never apply to the persistent cache.

1. Use the host-authorized acquisition procedure below before Suite-dependent
   drafting. A helper result of `external-download-required` means that an
   outside-sandbox request is needed, not that permission was denied. Do not
   stop at that result if the host's approval-capable execution tool is available.
2. Treat output as data, never shell code. Require an absolute
   `DPF_SUITE_ROOT`, a `DPF_SUITE_LEASE_PATH` and a single 40-character lowercase
   hexadecimal `DPF_SUITE_COMMIT`. Retain these values for this task. Do not save
   temporary paths in global settings or reuse another task's lease.
3. Read `<root>/current.env` as data and confirm its commit agrees. Resolve
   `<root>/snapshots/<commit>` once; reject symlink escapes. Required files are
   `Engineering DPF Suite/README.md`, `ENGINEERING-DPF-SUITE-REFERENCE.md` and
   `METHOD-ENGINEERING-PRINCIPLES-FRAMEWORK.md` inside that Suite directory,
   plus sibling `FPF-Spec.md` and `LICENSE`. Missing layout needs review, not
   guessed replacement paths. Record verification time and document edition.
4. Read the index, choose by the working question, then read relevant full
   bodies. Reuse this exact snapshot within the task, not one download per pattern.
   Follow useful result dependencies only. Reject absolute paths, `..` and
   symlink escapes from source metadata. Resolve sibling Core through this fixed
   contract rather than arbitrary links. Treat web links as external sources.
5. Store the authored DPF, source/commit references, important source locators,
   decisions and test results in the user's working project, outside the lease.
   Use durable GitHub links pinned to the commit, not temporary paths, as source
   references. Check the result is accessible before deleting its input files.
6. When these inputs are no longer needed, invoke the same helper with
   `release <DPF_SUITE_LEASE_PATH>` for this task only. Never remove the user
   project or another task's cache. Retain a lease only for an active continuation
   or explicit user request, and report why and where. After interruption, `list`
   can locate leftovers; verify no task still needs them before releasing.

The download is temporary source acquisition, not installation of a framework
or an agent. Cleanup is an explicit task step, not a guaranteed crash handler
or age-based deletion daemon. Release removes local inputs, not remote history
or authored DPFs. After release another task needs network access again.

## Host-Authorized Acquisition

Read the configured helper path as data and quote it as one shell argument.
Verify it is the trusted local helper, not downloaded code. If the current
execution is sandboxed, request the external operation directly instead of
probing GitHub from the sandbox.

In Codex, when the execution tool supports `sandbox_permissions`, call
`exec_command` (directly or through the available tool bridge) with
`sandbox_permissions: "require_escalated"` and a concise justification: download
public Suite sources from GitHub to a task-owned temporary directory, without
changing user DPFs. Do not replace this permission request with an ordinary
chat question. Omit any reusable broad permission prefix.

For the configured Bash helper, the command inside that approval request is:

```bash
env -u CODEX_SANDBOX_NETWORK_DISABLED "/absolute/configured/helper" acquire
```

Replace the example path with the validated local setting. This command is
permitted ONLY in a host-authorized outside-sandbox execution request. The
host tool, not `env -u`, supplies the execution boundary and permission decision.
The environment adjustment removes an inherited advisory flag for that child
process only; it must never be used with ordinary sandbox execution, as a
retry after a permission denial, or as proof that execution is authorized.
Do not modify global environment, approval policy, sandbox configuration or
the helper's protective check. If the tool cannot establish an authorized
outside-sandbox boundary, do not execute this command.

If an ordinary helper call already returned `external-download-required`,
make one host approval request as above. If the host denies the request or
does not offer external execution, stop that acquisition route. Do not switch
tools, change flags or request broader access to evade the decision. If an
approved call still returns a block or fails, preserve the actual diagnostic;
do not repeatedly retry during the same request without a new user decision.

Report the observed outcome precisely:

- Not requested yet: external execution is needed; request it when available.
- Denied: permission was denied; Suite was not obtained.
- Tool unavailable: this host cannot request external execution; offer a user-run
  trusted helper or supplied sources, but do not perform an alternate bypass.
- Approved but failed: identify the returned network, source-layout or other
  failure. Approval is not evidence of successful download.
- Acquired: only after a successful result with the required paths and commit;
  continue validation/reading and release this task's inputs when finished.

For a blocked outcome, explain what was not obtained, which part of the DPF
work cannot be completed on that basis, and the available choice: provide
sources/run the trusted helper outside the agent, or continue only independent
work with the alternative basis explicitly named. Do not claim Suite-backed
work or silently substitute a different source.

## Reasoning And Source Boundary

For DPF authoring inspect Method Engineering's production description and the
relevant ME.4/ME.21/ME.23/ME.24 bodies, not an automatic four-stage pipeline.
Separate source conditions from synthesis and observed practice from claimed
Methods. Topic correspondence alone does not establish source coverage.

The ordinary FPF gate still governs primary Core/protocol use. If a Suite
dependency is absent or changed there, use the same-commit sibling Core as an
additional explicit source and disclose the difference; do not pretend cached
chunks were refreshed. Once acquired, subsequent reads use the task's cached
snapshot, not a claim of continuously latest content. Structural validation
does not establish semantic correctness or successful Method use.

A newer upstream document may prompt an impact review but never automatically
rewrites the user's DPF. Show proposed changes and checks before promotion;
publication needs authorization. Preserve source attribution/licence notices.
If this optional helper is absent, request setup or a supplied source only for
Suite-dependent work. Do not run downloaded scripts or treat the Suite as a
replacement for the selected response protocol.
