# FPF Work Guide Release Notes

This file is for users and maintainers. It is not part of the runtime protocol
that an agent must read before every task.

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
