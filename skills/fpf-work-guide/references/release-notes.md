# FPF Work Guide Release Notes

## Unreleased - Persistent Engineering Suite Cache

- Add `engineering_suite_cache_root` with precedence over the temporary loader.
  Agents read a pinned local snapshot and do not fetch or release it per task.
- The personal external FPF job refreshes Suite on its existing schedule.
  Public distribution supplies the reader contract, not the personal scheduler.
- Preserve cached snapshots after refresh failure and retain old snapshots for
  active readers. Repeated identical commits reuse files; automatic pruning is
  not included. Personal settings and cache files remain outside this package.

This file is for users and maintainers. It is not part of the runtime protocol
that an agent must read before every task.

## Unreleased - Host-Authorized Suite Acquisition

- Make the host permission request explicit before acquisition. Distinguish
  external-download-required from a host denial and from an approved fetch
  failure. Stop on denial; never bypass the sandbox or silently claim Suite use.
- Document the exact Codex execution-tool route and child-only inherited-flag
  handling, without changing the helper guard, runtime scripts or global policy.
- Earlier 0.2.1 acquisition evidence remains historical; see the repository's
  authorized-acquisition follow-up record for the new checks and their limits.

## 0.2.1 - DPF Discovery And Optional Engineering Suite

- Added explicit DPF creation, update and review triggers to the description.
- One independent local creation probe selected the skill and invoked the
  helper, but source acquisition was blocked by the sandbox. This is not a
  successful download or public-install end-to-end validation.

- Added an optional `engineering_suite_loader` setting and per-task temporary
  source contract. Download only for Suite-dependent work; release source files
  after retaining authored results and provenance outside the temporary directory.
- No public scheduler or Suite loader is bundled. User-authored DPFs remain
  separate and are never rewritten merely because an upstream source changes.
- Same-commit Core is an explicit additional reference when a Suite dependency
  cannot be satisfied from the ordinary Core cache, not silent chunk refresh.

No runtime refresh script or network permission policy changes in this batch.
ADR 0005 and the repository's 0.2.1 release evidence describe the decisions,
replay checks and known acquisition gap. Publication identity is the merging PR;
this version heading does not claim a GitHub release or tag exists.

## 0.2.0 - Protocol Revision 2.0

### Protocol Revision Changes

- Two depth profiles share six stages and 17 conditional pattern routes.
  Applied patterns require source-body reading and useful results; no recursive
  whole-cluster traversal or universal multi-view/measurement apparatus.
- Compact basis is the default; detailed traces remain available when needed.
  Check execution and check outcome are distinct.
- Added conditional source-fidelity checks, SC-01 regression inputs and an
  optional non-public observation log. SC-01 remains open-monitoring; passing
  local examples does not prove reliability or causal improvement.
- Codex, plugin and Claude-native routing require protocol revision 2.0.
  Publish their source changes together with the protocols. A stale v1 cache
  produces an explicit mismatch, not silent mixed-version execution.
- Optional agent-read local settings support reviewed protocols before
  publication without repointing or changing refresh caches. No new runtime
  library, refresh algorithm, hook, scheduler or automatic logger is added.
- Structural validation and behavioral evaluation have separate boundaries;
  see the protocol ADR and repository validation instructions.
- Corrected the former nested `compatibility` object to the specification's
  string form; detailed requirements remain in README. A pinned reference
  format validator and negative fixtures are development/release tooling only.
  The bundled generic validator is not modified. See ADR 0004 for boundaries.

## 0.1.0 - 2026-05-28

Initial public `fpf-work-guide` release after the rename from `fpf-latest`.

### Changed

- Renamed the public skill and plugin package from `fpf-latest` to
  `fpf-work-guide`.
- Added `README.md` to the public `fpf-work-guide` skill and plugin-bundled
  skill copy as the user/maintainer entrypoint, keeping `SKILL.md` as the
  executable routing contract.
- Added migration guidance for installed copies, launchers, prompts, and
  environment variables that still reference `fpf-latest`.
- Added explicit portable path policy for skill, cache, refresh state, and
  environment state paths.
- Separated durable refresh-gate state (`latest.env`) from wrapper-captured
  output (`latest-output.env`).
- Made secondary launcher/global state explicit opt-in through
  `FPF_REFRESH_AUTO_STATE_FILE`.
- Added `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH` so diagnostics can identify the
  state file that supplied the previous refresh attempt.
- Added native PowerShell refresh, spec, protocol, environment-check, and doctor
  scripts.
- Added CMD wrappers that delegate to PowerShell instead of reimplementing
  refresh logic.
- Reduced Windows support claims: Windows paths are implemented, but release
  verification requires the PowerShell/CMD validation lane.
- Added protocol repository provenance fields:
  `FPF_PROTOCOLS_REPO_URL`, `FPF_PROTOCOLS_BRANCH`,
  `FPF_PROTOCOLS_REMOTE_URL`, and `FPF_PROTOCOLS_CACHE_TRUST_STATUS`.
- Strengthened cache reset guards so `.fpf-cache-repo` is valid only when its
  kind, repository URL, and branch match the configured cache.
- Added chunk source commit validation through `FPF_CHUNKS_SOURCE_COMMIT`.
- Split FPF spec provenance into `FPF_SPEC_REPO_COMMIT` and
  `FPF_SPEC_SOURCE_COMMIT`; chunk freshness now compares
  `FPF_CHUNKS_SOURCE_COMMIT` with `FPF_SPEC_SOURCE_COMMIT`, not with the mirror
  repository commit.
- Added `full-spec-first` behavior when chunk source commit differs from the FPF
  spec source commit.
- Added user-facing diagnostics documentation for refresh, environment, chunk,
  and protocol trust states.
- Added a public behavior model for task admission, substantive task start,
  refresh gate use, and FPF-backed work lifecycle.
- Added a public ADR describing architecture boundaries, cache/state behavior,
  protocol trust policy, and validation rules.
- Added a cross-platform validation script with Bash golden-output fixtures and
  optional PowerShell/CMD lanes.

### Operational Notes

- Cached FPF or protocol content must be described as the current cached copy,
  not as latest.
- If chunks are stale, use `FPF-Spec.md` first and disclose the stale chunk
  cache when FPF pattern content affects the answer.
- If protocol cache trust is ambiguous, disclose it when protocol instructions
  affect the answer or planned action.
- The public skill and plugin do not include personal launchers, LaunchAgents,
  session-start hooks, `.fpf-update/`, cache directories, logs, or local env
  files.

### Validation Evidence

- `scripts/validate-fpf-work-guide-cross-platform.sh` passed on macOS Bash.
- `SKILLS_VALIDATE_ONLY=fpf-work-guide scripts/validate-skills.sh` passed.
- `PLUGINS_VALIDATE_ONLY=fpf-work-guide scripts/validate-plugins.sh` passed.
- Staged skill, plugin-bundled skill, and installed local skill copies matched
  after synchronization.
- `pwsh` was not available on the local machine, so PowerShell validation was
  skipped locally and remains a separate release-verification lane.
