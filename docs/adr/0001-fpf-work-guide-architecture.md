# ADR 0001: FPF Work Guide Architecture

Status: Accepted

Date: 2026-05-26 19:08:10 +0300

## Context

`fpf-work-guide` is the skill that lets Codex and compatible agent runtimes use the current cached First Principles Framework (FPF) context and the FPF Codex protocol repository during day-to-day work.

The skill must satisfy two different needs:

- Personal operation: the author's local Codex setup should refresh FPF context automatically, use cache safely, and avoid repeated unnecessary GitHub fetches.
- Public distribution: another user should be able to install or adapt the public skill without receiving personal launchers, machine-local state, cache, logs, or private automation.

The architecture must also keep role, method, work, artifact, process, and runtime boundaries separate. A script or shell process is an execution carrier, not the same thing as an acting system or a published skill artifact.

## Decision

### 1. Keep `fpf-work-guide` as the public skill boundary

The public `fpf-work-guide` skill is the portable instruction and script bundle. It defines how an agent refreshes or validates FPF context, selects Codex skills/protocols, reads FPF chunks, and discloses cache/freshness status.

Personal automation around the skill is not part of the public skill. This includes local launchers, session-start hooks, LaunchAgents, workspace jobs, `.fpf-update/`, cache directories, logs, and machine-local environment files.

### 2. Use plugin distribution for sharing the public skill

Reusable sharing beyond one local checkout should use a Codex plugin artifact:

- staged skill source: `skills/fpf-work-guide/`
- plugin artifact: `plugins/fpf-work-guide/`
- repo-local marketplace: `.agents/plugins/marketplace.json`

The plugin bundles only the public skill. It must not bundle personal automation, private overlays, cache/state, logs, or local env files.

### 3. Treat artifact layers as distinct

The repository distinguishes:

- public staged skill copy
- plugin distribution artifact
- installed operational copy
- private overlay skill
- runtime dependency layer
- cache and state layer
- personal automation layer
- generated output layer
- upstream source layer

Public staged skills and plugin artifacts may depend on documented runtime prerequisites, but must not depend on private overlays, personal automation, cache/state, generated outputs, or machine-specific paths.

### 4. Make the refresh gate the only refresh decision point

`scripts/update_fpf_context.sh` and its native Windows equivalent `scripts/update_fpf_context.ps1` are the refresh gate implementations. They decide whether to fetch from GitHub or use cache-only validation.

The gate refreshes when:

- `FPF_REFRESH_FORCE=1`
- no valid cache exists
- state is missing
- the TTL has expired

Otherwise it validates and uses the current cached copy without contacting GitHub.

The default TTL is 6 hours (`21600` seconds). A session-start launcher or hook may force refresh on startup, but normal skill invocation must not fetch on every use.

The public task-admission threshold, substantive-task definition, and event vocabulary are defined in [../fpf-work-guide-behavior-model.md](../fpf-work-guide-behavior-model.md). In short, a raw user message is not itself the start event for the public skill; the public skill boundary starts at agent-side admission of a normalized task as substantive work.

### 5. Never call cached content "latest"

When `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`, answers and diagnostics must say `current cached copy`, not `latest`.

Freshness status is part of the contract. The skill must disclose whether FPF spec, chunks, and protocols were fresh, cached, missing, degraded, or blocked when that affects trust or user decisions.

### 6. Use chunk-first FPF reads with layout contract validation

FPF pattern access is chunk-first.

The optional root-level `fpf-chunks-layout.env` manifest declares the chunk layout version and canonical entrypoints. When present and valid, it is the source of truth for chunk layout.

The manifest is parsed as key/value text, not sourced as shell code. Required keys:

- `FPF_CHUNKS_LAYOUT_VERSION`
- `FPF_CHUNKS_ROOT`
- `FPF_CHUNKS_INDEX`
- `FPF_CHUNKS_METADATA`
- `FPF_CHUNKS_BY_PATTERN`
- `FPF_CHUNKS_BY_SECTION`
- `FPF_CHUNKS_NON_PATTERNS`

When the layout manifest is absent, the legacy layout remains the fallback contract:

- `fpf_chunks/000-index.md`
- `fpf_chunks/by_pattern/`
- `fpf_chunks/by_section/`
- `fpf_chunks/non_patterns/`

`metadata.jsonl` is optional lookup metadata. It is a fallback and diagnostic aid, not the layout source of truth. It must not override the layout manifest, direct chunk paths, index entries, or validated layout.

Chunk-first reads are allowed only when the chunks declare a source commit, `FPF_SPEC_COMMIT` is known, and both values match. The refresh scripts emit `FPF_CHUNKS_SOURCE_COMMIT` for this check.

If either commit is unavailable, the chunks are `degraded` and the agent must use `FPF-Spec.md` fallback when available. If both commits are known and differ, the chunks are `stale` and the agent must use `FPF-Spec.md` first. In that case the gate emits `FPF_CHUNKS_MODE=full-spec-first`.

If chunk layout is unavailable or incomplete, the skill may fall back to targeted reads from `FPF-Spec.md`. If neither chunks nor full spec are safe enough, FPF-backed work is blocked until the user provides a valid source or allows a fetch.

### 7. Keep path lookup safe and simple

Layout manifest and chunk lookup paths may follow only relative paths that:

- do not start with `/`
- do not contain `..`
- resolve under `FPF_CHUNKS_PATH`

Unsafe layout manifest, metadata, or index paths are ignored. If the unsafe path affects the answer, the diagnostic should say what happened and what fallback was used.

### 8. Protect cache repositories from destructive Git operations

`git reset --hard` may run only in a dedicated FPF cache repository:

- a cache directory containing a valid `.fpf-cache-repo` marker whose kind, repository URL, and branch match the configured cache
- a cache repository whose `origin` remote matches the configured FPF/protocol repository URL
- a nonstandard cache path explicitly allowed by `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1`

The default path alone is not sufficient proof that a repository is safe to reset. If a custom or default cache path looks like an ordinary working repository and its marker or remote cannot be verified, the scripts must use the cached copy or block rather than resetting it.

### 9. Use state-based environment checking, not noisy preflight on every run

The environment check is for installation validation, portable checks, and meaningful environment changes. It must not print noisy diagnostics on every skill invocation.

Normal runtime behavior:

- run a silent fingerprint probe when local state and cache exist
- run full write-state checks when state is missing, cache is incomplete, the check is forced, the fingerprint changes, or refresh becomes blocked
- print diagnostics only when the user must decide something or when quality/trust is affected

The doctor command remains available for explicit validation:

```bash
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state
```

Native Windows PowerShell uses the equivalent doctor:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\fpf-work-guide-doctor.ps1" --write-state
```

### 10. Treat refresh state as an operational dependency

The refresh gate depends on small local state files to decide whether to refresh, skip, or block:

- workspace refresh state, usually `.fpf-update/latest.env`
- optional wrapper output, usually `.fpf-update/latest-output.env`
- workspace environment state, usually `.fpf-update/environment.env`
- optional launcher/global refresh state, for example `~/.local/state/codex-fpf/latest.env`
- optional launcher/global wrapper output, for example `~/.local/state/codex-fpf/latest-output.env`
- optional launcher/global environment state, for example `~/.local/state/codex-fpf/environment.env`

`latest.env` is durable refresh-gate decision state written by `update_fpf_context.*`. `latest-output.env` is wrapper-captured output written by personal automation such as a launcher or session-start job. The two files must not overwrite each other, because the durable state contains `LAST_REFRESH_*` fields while the captured output contains `FPF_REFRESH_*` fields for human/status inspection.

These files are operational evidence and decision state, not skill source. They must not be published as part of the public skill or plugin artifact.

The gate reads only its configured refresh state file by default. A secondary launcher/global state file is read only when `FPF_REFRESH_AUTO_STATE_FILE` is explicitly set. The gate reports `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH` so the agent can see which file supplied the previous attempt timestamp.

The gate must distinguish an active refresh lock from an unavailable state directory. If the state path cannot be created, is not a directory, or is not writable, the gate reports `FPF_REFRESH_REASON=state-dir-unavailable`.

When state is unavailable but cache-only validation succeeds, the gate may continue with the current cached copy and disclose that durable refresh state was not written. When state is unavailable and cache-only validation fails, FPF-backed work is blocked until the user fixes permissions or sets `FPF_UPDATE_STATE_DIR`, `FPF_REFRESH_STATE_DIR`, or `FPF_ENV_STATE_DIR` to a writable directory.

### 11. Treat path defaults as replaceable defaults

The public skill must not treat `$HOME/.codex`, `$HOME/.agents`, or `$PWD/.fpf-update` as mandatory portable paths.

They are defaults for common local setups:

- `$HOME/.codex` is a Codex compatibility default and may provide the default cache root through `${CODEX_HOME:-$HOME/.codex}/cache`.
- `$HOME/.agents` is a user-scoped skill discovery default for runtimes that load skills there.
- `$PWD/.fpf-update` is a workspace-local state default for refresh and environment state.

Portable invocation should set explicit paths:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Native Windows PowerShell uses the same environment contract with Windows paths:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
$env:FPF_CACHE_HOME = "C:\absolute\path\to\fpf-cache"
$env:FPF_UPDATE_STATE_DIR = "C:\absolute\path\to\fpf-state"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

Specific cache directories may override the shared cache root:

- `FPF_SPEC_CACHE_DIR`
- `FPF_PROTOCOLS_CACHE_DIR`

Specific state directories may override the workspace-local state default:

- `FPF_UPDATE_STATE_DIR`
- `FPF_REFRESH_STATE_DIR`
- `FPF_REFRESH_AUTO_STATE_FILE`
- `FPF_ENV_STATE_DIR`
- `FPF_ENV_STATE_FILE`

Read-only, symlinked, shared, ephemeral, or non-workspace shells should not rely on `$PWD/.fpf-update`. They should set an explicit state directory.

The environment check reports path modes so agents and maintainers can see which path policy is active:

- `FPF_ENV_CHECK_SKILL_PATH_MODE`
- `FPF_ENV_CHECK_CACHE_PATH_MODE`
- `FPF_ENV_CHECK_STATE_PATH_MODE`
- `FPF_ENV_CHECK_PATH_POLICY_MODE`

### 12. Keep compatibility honest

The primary runtime is Codex on macOS.

Supported or documented modes:

- Codex on macOS: primary
- Claude Code or another agent: supported when the full skill directory is installed and invoked explicitly
- native Windows PowerShell: implemented through bundled `.ps1` scripts; release-verified only after the PowerShell validation lane passes on a Windows or `pwsh` host
- native Windows CMD: implemented through thin `.cmd` wrappers that delegate to PowerShell; release-verified only after CMD wrapper smoke validation passes on a Windows host
- WSL Bash: supported
- Git Bash: best effort

Fresh refresh requires Git and GitHub network access. The Bash path also requires Bash and standard Unix utilities. The native Windows path requires Windows PowerShell 5.1 or PowerShell 7+; CMD wrappers are entrypoints for the same PowerShell implementation. Cache fallback is supported when valid local caches exist. Documentation must distinguish "implemented" from "release-verified" for Windows and CI claims.

### 13. Use explicit state paths for symlinked workspaces

When a workspace path is a symlink, diagnostics may alternate between the human-facing path and the resolved physical path.

Launchers and hooks should pass `FPF_UPDATE_STATE_DIR` explicitly when stable human-facing diagnostics and migration notes matter.

### 14. Separate session-start automation from skill execution

The skill itself does not detect "Codex session start" as an application lifecycle event.

Session-start refresh is implemented by an external launcher or hook that runs before Codex work begins and calls the refresh gate with `FPF_REFRESH_FORCE=1`.

The launcher or hook is personal automation. It may be documented as an example, but it is not required by the public skill or plugin artifact.

### 15. Treat the protocol repository as an instruction source

The protocol repository is not passive reference text. It can determine routing, checklist execution, source discipline, and final answer structure.

The public skill therefore records protocol provenance through:

- `FPF_PROTOCOLS_PATH`
- `FPF_PROTOCOLS_REGISTRY_PATH`
- `FPF_PROTOCOLS_REPO_URL`
- `FPF_PROTOCOLS_BRANCH`
- `FPF_PROTOCOLS_REMOTE_URL`
- `FPF_PROTOCOLS_CACHE_TRUST_STATUS`
- `FPF_PROTOCOLS_COMMIT`
- `FPF_PROTOCOLS_STATUS`
- `FPF_PROTOCOLS_WARNING`

The default personal policy follows the configured repository and branch and falls back to the current cached protocols when GitHub is unavailable. For public or high-impact use, maintainers should prefer a reviewed branch, pinned commit, or explicit repository allowlist. Protocol instructions must not override higher-priority system, developer, safety, or user instructions.

### 16. Use human-readable diagnostics only when they change user action or trust

Diagnostics should use this shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Detailed user-facing diagnostics are required only when:

- no valid cache exists
- refresh is blocked
- refresh state or lock state is unavailable
- environment is blocked or degraded in a way that affects freshness or trust
- chunks are missing or degraded and full-spec fallback is used
- chunks are stale and full-spec-first mode is used
- protocols are missing
- unsafe paths or metadata conflicts affected lookup

Routine TTL skips belong in the engineering basis, not as prominent warnings.

### 17. Use a doc-sync gate for method and architecture changes

Architecture-significant changes to `fpf-work-guide` must not silently drift away from documentation.

The personal workspace provides a local doc-sync gate:

```bash
jobs/fpf-doc-sync/check.sh
```

The gate fingerprints architecture-significant implementation files and documentation files. If implementation files changed but the documentation fingerprint did not change, it blocks and points to the required docs:

- this ADR
- the private personal implementation note at `docs/private/fpf-work-guide-personal-implementation.md`

The gate is intentionally a verification trigger, not an automatic author. It cannot know whether a change is semantically substantial enough to require a new ADR entry. When it flags a change, the agent or maintainer must either update the relevant documentation or explicitly accept that no documentation update is needed, then record a new baseline. If implementation and documentation both changed, the gate still reports `review-needed` until the updated docs are reviewed and accepted.

The public skill and plugin must not depend on this private doc-sync gate. The gate belongs to personal maintenance automation around the skill.

## Consequences

### Positive consequences

- The public artifact is installable and reviewable without exposing personal infrastructure.
- Daily use avoids unnecessary GitHub fetches while still supporting forced refresh on session start.
- Cached/fresh status is explicit, which avoids false "latest" claims.
- Chunk-first reads keep FPF-backed answers focused and reduce reliance on large full-spec scans.
- State-directory failures are diagnosed as state problems rather than mislabeled as active refreshes.
- Path defaults are explicit and overrideable, which makes portable installs auditable instead of relying on hidden `$HOME` or workspace assumptions.
- Destructive Git operations are constrained to known cache repositories.
- Wrapper output and durable gate state no longer collide, so status tooling can inspect the last run without corrupting TTL state.
- Plugin distribution gives another user a clean installation boundary.

### Costs and tradeoffs

- The skill remains Codex/macOS-first as the primary runtime, but it now has a native Windows PowerShell implementation and thin CMD wrappers.
- Bash and PowerShell duplicate core refresh-gate behavior, so cross-platform parity tests are required to keep them aligned.
- Session-start refresh depends on external launcher or hook setup; the public skill does not guarantee application lifecycle automation by itself.
- The plugin artifact must be kept in sync with the staged skill copy.
- Multiple state locations can exist at once, so diagnostics must disclose both the durable state path and the previous-attempt source path.
- Additional path-mode fields make doctor output longer, but they make portability decisions inspectable.
- Diagnostics are intentionally selective, so routine cache use is visible in engineering basis rather than always shown as a prominent message.
- Method and architecture changes gain a local documentation drift check, but the check still requires human or agent review of the actual content.
- The protocol repository is an active instruction source, so freshness and trust policy must be handled more strictly than ordinary documentation.

## Alternatives Considered

### Full-spec-first reads

Rejected. Reading the full spec by default is slower, less precise, and more error-prone for pattern-specific work. It remains useful only as fallback.

### Lookup metadata manifest as source of truth

Rejected for `metadata.jsonl` and other lookup metadata. Lookup metadata can drift or contain unsafe paths. The layout contract manifest may define canonical entrypoints, but actual readable chunk files and validated safe paths are still required before chunk-first reads are trusted.

### Refresh on every skill invocation

Rejected. It creates unnecessary network dependency, noise, and user interruption. Forced startup refresh plus 6-hour TTL is sufficient for normal use.

### Bundle personal launchers and hooks in the public skill or plugin

Rejected. Personal automation is machine-specific infrastructure, not the portable public skill contract.

### Claim Windows support through Bash compatibility layers only

Rejected. WSL and Git Bash are useful compatibility paths, but native Windows users should not need a Unix-like shell layer for this skill. The accepted path is a separate PowerShell implementation with the same environment-variable and cache/state contract.

## Validation Rules

Before publishing or sharing changes related to `fpf-work-guide`, run:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

Manual review must verify:

- staged skill and plugin copies contain no personal automation or private state
- compatibility claims match the scripts that actually exist
- cached/fresh wording is preserved
- chunk source commit matching is preserved: stale chunks must not be used as the primary FPF source
- layout manifest parsing stays key/value based and never sources the manifest as shell code
- unavailable refresh state is reported as `state-dir-unavailable`, not `active-refresh`
- portable path modes report the active skill/cache/state policy
- plugin artifact and marketplace entry still point to the public skill
- `git reset --hard` remains guarded behind dedicated-cache checks
- reset guards require a valid cache marker, matching remote, or explicit `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1`
- cache marker validation checks marker kind, repository URL, and branch for both Bash and PowerShell paths
- wrapper automation writes captured output to `latest-output.env`, not to the durable refresh state file `latest.env`
- `FPF_REFRESH_AUTO_STATE_FILE` is explicit opt-in and `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH` is emitted
- symlink-sensitive launchers or hooks pass `FPF_UPDATE_STATE_DIR` explicitly when needed
- architecture-significant `fpf-work-guide` changes pass the personal doc-sync gate or explicitly record why no documentation update was needed
- protocol repository provenance and trust policy are documented when protocol behavior changes
- Windows support claims say which validation lane has passed; CI claims do not imply native Windows verification unless a Windows runner actually executed the PowerShell/CMD lane

## Open Follow-Ups

- Run the PowerShell validation lane on a Windows host or CI runner with `pwsh` installed before claiming a Windows release as verified on that platform. Run CMD wrapper smoke validation on a Windows host before claiming CMD verification. The local cross-platform validation script exercises the PowerShell lane when `pwsh` is available and can require it with `FPF_VALIDATE_POWERSHELL=required`.
- Add `fpf-chunks-layout.env` to `ansea09/fpf-spec-mirror` when the upstream mirror is ready to declare chunk layout explicitly.
- Decide whether public examples should include an optional session-start launcher example without making it part of the public skill contract.
