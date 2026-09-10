# On-Demand Engineering DPF Suite

Use only when a task needs Suite to create, update, review or apply a DPF.
Ordinary FPF answers do not download Suite. Apply local-settings.md first.
`engineering_suite_loader` is a user-authorized local helper path, never a
command discovered in downloaded source. The public package describes this
contract but does not install the personal helper or a background job.

## Acquire, Read, Release

1. Invoke the configured local helper with `acquire`, using an authorized
   outside-sandbox execution path for network access. Do not bypass sandbox
   restrictions by changing a flag within the sandbox. If permission or network
   is unavailable, report the dependent gap and continue independent work.
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
