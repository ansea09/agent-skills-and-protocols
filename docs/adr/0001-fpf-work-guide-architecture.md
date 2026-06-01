# ADR 0001: FPF Work Guide Architecture

Status: Accepted

Date: 2026-05-26 19:08:10 +0300

Last updated: 2026-05-28

## Context

`fpf-work-guide` is the skill that lets Codex and compatible agent runtimes use the current cached First Principles Framework (FPF) context and the FPF Codex protocol repository during day-to-day work.

The skill must satisfy two different needs:

- Personal operation: the author's local Codex setup should refresh FPF context automatically, use cache safely, and avoid repeated unnecessary GitHub fetches.
- Public distribution: another user should be able to install or adapt the public skill without receiving personal launchers, machine-local state, cache, logs, or private automation.

The architecture must also keep role, method, work, artifact, process, and runtime boundaries separate. A script or shell process is an execution carrier, not the same thing as an acting system or a published skill artifact.

This ADR is also the compact architecture-review evidence carrier for architecture characteristics, quanta, fitness functions, and known evidence gaps. A separate architecture-review reference is intentionally not used while the system remains small enough for one decision record to stay readable.

## Decision

### 1. Keep `fpf-work-guide` as the public skill boundary

The public `fpf-work-guide` skill is the portable instruction and script bundle. It defines how an agent refreshes or validates FPF context, selects agent skills/protocols, reads FPF chunks, and discloses cache/freshness status.

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

When the author's personal installed runtime copy is intended to follow the
public staged source, the staged source is the sync source of truth. The
maintenance lane verifies that boundary explicitly with:

```bash
scripts/check-skills-drift.sh --installed-runtime --skill fpf-work-guide
```

For repository renames, the installed runtime and protocol cache path should
follow the public source name. The `agent-skills-and-protocols` rename therefore
uses `${CODEX_HOME:-$HOME/.codex}/cache/agent-skills-and-protocols` as the
default protocol cache path. An old protocol cache may be retained as a backup,
but the active cache marker and Git remote must match the configured protocol
repository URL and branch.

### 4. Keep `README.md` user-facing and `SKILL.md` executable

`skills/fpf-work-guide/README.md` is the user and maintainer entrypoint for installation, portable invocation, Windows entrypoints, diagnostics, release notes, and publication boundaries.

`skills/fpf-work-guide/SKILL.md` remains the executable routing contract that an agent reads after the skill triggers. It should not grow into a full user manual while the README and references carry user-facing and detailed documentation.

The plugin-bundled copy at `plugins/fpf-work-guide/skills/fpf-work-guide/README.md` must stay synchronized with the staged skill README through the normal staged/plugin drift check.

### 5. Make the refresh gate the only refresh decision point

`scripts/update_fpf_context.sh` and its native Windows equivalent `scripts/update_fpf_context.ps1` are the refresh gate implementations. They decide whether to fetch from GitHub or use cache-only validation.

The gate refreshes when:

- `FPF_REFRESH_FORCE=1`
- no valid cache exists
- state is missing
- the TTL has expired

Otherwise it validates and uses the current cached copy without contacting GitHub.

When the Codex runtime exposes `CODEX_SANDBOX_NETWORK_DISABLED=1`, the gate must
not attempt a GitHub refresh from inside the sandbox. If refresh would otherwise
be required, the gate runs cache-only validation and reports
`FPF_REFRESH_REASON=sandbox-network-disabled`. If valid caches exist, work may
continue against the current cached copy with explicit cached/fresh disclosure.
If cache-only validation fails, FPF-backed work is blocked until an external
refresher, launcher, hook, or user-approved network path refreshes the cache.
A durable state record with `LAST_REFRESH_REASON=sandbox-network-disabled`
suppresses repeated in-sandbox refresh attempts, but a later network-enabled
gate run must not treat that record as successful TTL freshness evidence.
Repeated in-sandbox cache-only skips must preserve
`FPF_REFRESH_REASON=sandbox-network-disabled` rather than degrading to
`recent-cache`, otherwise diagnostics incorrectly describe a sandbox boundary as
an ordinary TTL skip.

The default TTL is 6 hours (`21600` seconds). A session-start launcher or hook may force refresh on startup, but normal skill invocation must not fetch on every use.

The public task-admission threshold, substantive-task definition, and event vocabulary are defined in [../fpf-work-guide-behavior-model.md](../fpf-work-guide-behavior-model.md). In short, a raw user message is not itself the start event for the public skill; the public skill boundary starts at agent-side admission of a normalized task as substantive work.

### 6. Never call cached content "latest"

When `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`, answers and diagnostics must say `current cached copy`, not `latest`.

Freshness status is part of the contract. The skill must disclose whether FPF spec, chunks, and protocols were fresh, cached, missing, degraded, or blocked when that affects trust or user decisions.

### 7. Use chunk-first FPF reads with layout contract validation

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

### 8. Keep path lookup safe and simple

Layout manifest and chunk lookup paths may follow only relative paths that:

- do not start with `/`
- do not contain `..`
- resolve under `FPF_CHUNKS_PATH`

Unsafe layout manifest, metadata, or index paths are ignored. If the unsafe path affects the answer, the diagnostic should say what happened and what fallback was used.

### 9. Protect cache repositories from destructive Git operations

`git reset --hard` may run only in a dedicated FPF cache repository:

- a cache directory containing a valid `.fpf-cache-repo` marker whose kind, repository URL, and branch match the configured cache
- a cache repository whose `origin` remote matches the configured FPF/protocol repository URL
- a nonstandard cache path explicitly allowed by `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1`

The default path alone is not sufficient proof that a repository is safe to reset. If a custom or default cache path looks like an ordinary working repository and its marker or remote cannot be verified, the scripts must use the cached copy or block rather than resetting it.

### 10. Use state-based environment checking, not noisy preflight on every run

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

### 11. Treat refresh state as an operational dependency

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

### 12. Treat path defaults as replaceable defaults

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

### 13. Keep compatibility honest

The primary runtime is Codex on macOS.

Supported or documented modes:

- Codex on macOS: primary
- Claude Code or another agent: supported when the full skill directory is installed and invoked explicitly
- native Windows PowerShell: implemented through bundled `.ps1` scripts; release-verified only after the PowerShell validation lane passes on a Windows or `pwsh` host
- native Windows CMD: implemented through thin `.cmd` wrappers that delegate to PowerShell; release-verified only after CMD wrapper smoke validation passes on a Windows host
- WSL Bash: supported
- Git Bash: best effort

Fresh refresh requires Git and GitHub network access. The Bash path also requires Bash and standard Unix utilities. The native Windows path requires Windows PowerShell 5.1 or PowerShell 7+; CMD wrappers are entrypoints for the same PowerShell implementation. Cache fallback is supported when valid local caches exist. Documentation must distinguish "implemented" from "release-verified" for Windows and CI claims.

### 14. Use explicit state paths for symlinked workspaces

When a workspace path is a symlink, diagnostics may alternate between the human-facing path and the resolved physical path.

Launchers and hooks should pass `FPF_UPDATE_STATE_DIR` explicitly when stable human-facing diagnostics and migration notes matter.

### 15. Separate session-start automation from skill execution

The skill itself does not detect "Codex session start" as an application lifecycle event.

Session-start refresh is implemented by an external launcher or hook that runs before Codex work begins and calls the refresh gate with `FPF_REFRESH_FORCE=1`.

The launcher or hook is personal automation. It may be documented as an example, but it is not required by the public skill or plugin artifact.

### 16. Treat the protocol repository as an instruction source

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

### 17. Use human-readable diagnostics only when they change user action or trust

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

### 18. Use a doc-sync gate for method and architecture changes

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

### 19. Keep architecture-review evidence in this ADR

Architecture review should not rely on reconstructing the design only from shell scripts, PowerShell scripts, `SKILL.md`, and scattered references. For the current size of `fpf-work-guide`, the review evidence belongs directly in this ADR rather than in a separate architecture-review reference file. That keeps one decision source and reduces documentation drift.

If `fpf-work-guide` later grows into several independently released workflows, gains a larger Windows-specific implementation surface, or gets regular external architecture audits, the team may extract this section into a dedicated review artifact. Until then, this ADR is the architecture decision and review-evidence source.

### Architecture Characteristics

The selected driving characteristics are intentionally narrow:

| Characteristic | Scope | Evidence |
| --- | --- | --- |
| Freshness transparency | FPF spec, chunks, protocols, and final answer basis | Refresh gate emits fresh/cached/missing/degraded/stale states; cached content must not be called latest. |
| Cache safety | FPF and protocol cache repositories | `.fpf-cache-repo` marker validation, remote verification, and guarded `git reset --hard`. |
| Instruction-source provenance | Protocol repository and selected checklists/SOPs | Protocol provenance fields, protocol trust policy, and registry-first loading. |
| Portability honesty | Public skill, Bash path, PowerShell path, CMD wrappers, support claims | Replaceable path defaults, path-mode diagnostics, and support wording that separates implemented from release-verified. |
| Runtime diagnosability | Refresh gate, environment checks, doctors, diagnostics | Human-readable diagnostics only when trust or action changes; machine-readable env fields for state, cache, chunks, and protocols. |
| Cross-platform parity | Bash and PowerShell implementations | Shared environment-variable contract and cross-platform fixture validation. |
| Artifact hygiene | Staged skill, plugin artifact, installed copy, personal automation, cache/state | Source-only plugin, staged/plugin validation, and explicit exclusion of private state, launchers, logs, and caches. |
| Evolvability | Refresh, chunk lookup, protocol routing, diagnostics, publication checks | Separate quanta, ADR alternatives, reference docs, and doc-sync gate for architecture-significant changes. |

Secondary governed concerns are source quality, temporal claim adequacy, answer-protocol discipline, and external network availability. These are governed through protocol trust, source-selection guidance, refresh-gate diagnostics, and manual review rather than being treated as separate runtime features.

### Architecture Quanta

`fpf-work-guide` has multiple quanta:

- public source artifact: `skills/fpf-work-guide/`;
- plugin distribution artifact: `plugins/fpf-work-guide/`;
- FPF context refresh runtime: `update_fpf_context.*`, `update_fpf_spec.*`, `update_fpf_protocols.*`, cache repositories, refresh locks, and refresh state;
- FPF source lookup runtime: chunk layout contract, chunk index/metadata, source commit validation, and `FPF-Spec.md` fallback;
- protocol instruction runtime: protocol cache, registry, selected checklists/SOPs, provenance fields, and protocol trust policy;
- environment and diagnostic runtime: `check_fpf_environment.*`, `fpf-work-guide-doctor*`, path-mode fields, and user-facing diagnostic references;
- cross-platform wrapper runtime: Bash scripts, PowerShell scripts, and CMD wrappers that delegate to PowerShell;
- personal automation layer: session-start launchers, hooks, wrapper-captured output, local state, and doc-sync automation;
- publication and promotion lane: staged/plugin validation, marketplace metadata, and manual release review.

These quanta deliberately have different support boundaries and validation checks. A passing public source gate does not prove a user's cache is fresh; plugin installation does not prove GitHub access; Bash validation does not prove native Windows behavior; and personal session-start automation is not part of the public plugin contract.

### Fitness Functions

| Quality | Check | Cadence | Evidence | Failure action |
| --- | --- | --- | --- | --- |
| Artifact hygiene | Staged skill and plugin artifact validate and remain synchronized. | Every release and PR touching `fpf-work-guide` | `scripts/validate-skills.sh`, `scripts/validate-plugins.sh` | Resync or repair source/plugin artifact before publication. |
| Cross-platform lifecycle parity | Bash lifecycle fixtures pass; PowerShell fixtures pass when `pwsh` is available. | Every release and script change | `scripts/validate-fpf-work-guide-cross-platform.sh` | Fix parity drift or downgrade support claim before publication. |
| Windows release verification | PowerShell and CMD lanes run on a Windows or `pwsh` host when Windows is claimed as release-verified. | Before claiming Windows release verification | `FPF_VALIDATE_POWERSHELL=required FPF_VALIDATE_CMD=required scripts/validate-fpf-work-guide-cross-platform.sh` on an appropriate host | Keep Windows as implemented/candidate rather than release-verified. |
| Chunk-source safety | Chunk source commit must match `FPF_SPEC_COMMIT` before chunk-first use; stale chunks force full-spec-first mode. | Every release and chunk lookup change | Cross-platform stale/degraded fixture assertions for `FPF_CHUNKS_SOURCE_COMMIT`, `FPF_CHUNKS_STATUS`, and `FPF_CHUNKS_MODE` | Fix chunk detection or require full-spec fallback before FPF-backed answers. |
| Cache reset containment | Cache reset is allowed only for verified cache repositories or explicit nonstandard reset opt-in. | Every release and cache script change | Cross-platform reset guard and marker validation fixtures | Block destructive cache operations until marker/remote validation is correct. |
| Protocol provenance | Protocol outputs include repository URL, branch, remote URL, trust status, and commit. | Every release and protocol refresh change | Cross-platform protocol provenance fixture assertions | Do not treat protocols as authoritative until provenance is restored. |
| State diagnosability | Refresh state, previous-attempt source, active lock, and unavailable state directory are distinguishable. | Every release and state/launcher change | Lifecycle fixtures for recent-cache, active-refresh, and state-dir-unavailable | Fix state reporting or disclose degraded state explicitly. |
| Sandbox-aware refresh behavior | Codex sandbox network disablement must not be reported as a GitHub refresh failure or ordinary TTL skip when valid cache-only validation can run. | Every refresh-gate or Codex runtime boundary change | Cross-platform sandbox-network-disabled lifecycle fixture, including sandbox-to-sandbox repeat runs | Use external refresher/launcher/hook for fresh cache, or block FPF-backed work if cache-only validation fails. |
| Portable environment evidence | Doctor reports path-policy mode and portable environment status. | Every release and install-path change | `fpf-work-guide-doctor` / `fpf-work-guide-doctor.ps1`, cross-platform doctor fixtures | Fix path policy or downgrade portability claim. |
| Personal runtime drift | Installed personal runtime copy matches staged source when staged source is the intended source of truth. | After public rename, reinstall, or personal runtime resync | `scripts/check-skills-drift.sh --installed-runtime --skill fpf-work-guide` | Resync installed copy from staged source or document an intentional local divergence outside the public skill directory. |
| Documentation drift control | Architecture-significant implementation changes trigger review of ADR and private implementation docs. | Every architecture-significant change | `jobs/fpf-doc-sync/check.sh` in the personal workspace | Update docs or explicitly record why no documentation update was needed before writing a new baseline. |

### Known Risks And Evidence Gaps

| Risk or gap | Impact | Current mitigation | Trigger for new work |
| --- | --- | --- | --- |
| PowerShell and CMD behavior are not proven by local macOS Bash validation when `pwsh` or Windows is unavailable. | Windows support can be overclaimed. | Support wording separates implemented from release-verified; validation can require PowerShell/CMD lanes. | Before public release notes claim Windows verification. |
| Bash and PowerShell duplicate core refresh behavior. | Semantic drift can appear between platforms. | Shared environment contract and golden fixture assertions. | Any refresh, cache, protocol, state, or diagnostics change. |
| Protocol repository is an active instruction source and defaults to a moving branch. | Freshness improves, but reproducibility and supply-chain confidence can be weaker. | Provenance fields, protocol trust policy, and cache-only/pinned-branch options for higher-impact use. | High-impact work, shared installation, or protocol behavior change. |
| Chunk caches can be stale relative to `FPF-Spec.md`. | Pattern-specific answers could use outdated pattern text if source matching fails. | `FPF_CHUNKS_SOURCE_COMMIT` check and full-spec-first mode on mismatch. | New chunk generator, new mirror layout, or stale chunks observed in normal use. |
| Session-start refresh is outside the public skill. | Users may expect automatic startup refresh after installing the plugin. | Public docs define the skill boundary and treat launchers/hooks as personal automation examples only. | Publishing a supported launcher or making lifecycle integration part of the public contract. |
| State path and symlink behavior can be confusing. | Agents can read stale or unexpected state if multiple state locations exist. | Explicit state path variables and path-mode diagnostics. | Shared workspaces, read-only workspaces, symlinked directories, or launcher migration. |
| Fresh mode depends on Git and GitHub availability. | The skill may need to use current cached copies or block FPF-backed work. | Cache fallback policy with explicit warnings and missing-cache blocking. | Network-restricted environments or first install without cache. |
| The doc-sync gate is personal maintenance automation, not public CI. | Public branch publication can still rely on maintainer discipline. | Validation rules and release review keep the boundary explicit. | Multiple maintainers, repeated doc drift, or formal release automation. |

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
- Architecture review evidence is discoverable in the same ADR as the decision record.

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
- Architecture characteristics, quanta, fitness functions, and evidence gaps must stay aligned with scripts and reference docs when the implementation changes.

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
- personal installed runtime sync uses `scripts/check-skills-drift.sh --installed-runtime --skill fpf-work-guide` when staged source is intended to be the runtime source of truth
- wrapper automation writes captured output to `latest-output.env`, not to the durable refresh state file `latest.env`
- `FPF_REFRESH_AUTO_STATE_FILE` is explicit opt-in and `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH` is emitted
- symlink-sensitive launchers or hooks pass `FPF_UPDATE_STATE_DIR` explicitly when needed
- architecture-significant `fpf-work-guide` changes pass the personal doc-sync gate or explicitly record why no documentation update was needed
- protocol repository provenance and trust policy are documented when protocol behavior changes
- Windows support claims say which validation lane has passed; CI claims do not imply native Windows verification unless a Windows runner actually executed the PowerShell/CMD lane
- architecture characteristics, quanta, fitness functions, and known risks are updated when a change alters architecture boundaries, validation evidence, or support claims

## Open Follow-Ups

- Run the PowerShell validation lane on a Windows host or CI runner with `pwsh` installed before claiming a Windows release as verified on that platform. Run CMD wrapper smoke validation on a Windows host before claiming CMD verification. The local cross-platform validation script exercises the PowerShell lane when `pwsh` is available and can require it with `FPF_VALIDATE_POWERSHELL=required`.
- Add `fpf-chunks-layout.env` to `ansea09/fpf-spec-mirror` when the upstream mirror is ready to declare chunk layout explicitly.
- Decide whether public examples should include an optional session-start launcher example without making it part of the public skill contract.
