---
name: fpf-work-guide
description: Maintain and use the current First Principles Framework (FPF) context from ansea09/fpf-spec-mirror and agent skills/protocols from ansea09/agent-skills-and-protocols. Run the FPF context refresh gate before substantive reasoning, coding, review, research, planning, document drafting, agent work, or source-backed answers; the gate refreshes only on session start, forced refresh, missing cache, or TTL expiry. Use when the user asks to answer with FPF or FPF Work Guide, when a task needs FPF patterns or FPF-backed protocols, or when working in this user's Codex environment where current FPF-backed reasoning is required.
compatibility:
  primary_runtime: "Codex on macOS; Windows PowerShell/CMD implementation included, release-verified only when the Windows or pwsh validation lane passes"
  secondary_runtime: "Claude Code or other agents when this skill directory is installed and invoked explicitly"
  supported_shells:
    - "macOS Bash"
    - "Linux Bash"
    - "WSL Bash"
    - "Git Bash best effort"
    - "Windows PowerShell 5.1 or PowerShell 7+ implementation; release-verified only when the PowerShell validation lane passes"
    - "Windows CMD wrappers delegate to PowerShell; release-verified only when CMD smoke validation passes"
  unsupported_shells:
    - "unlisted shells without Bash or PowerShell compatibility"
  required_commands:
    - "bash for Unix-like shell path"
    - "PowerShell for native Windows path"
    - "git for fresh GitHub refresh"
    - "standard Unix utilities for Bash path: awk, date, dirname, mkdir, mv, rmdir, stat, uname"
  network_requirement: "GitHub network access is required only when a refresh is due, forced, or no valid cache exists."
  cache_fallback: "Supported when FPF and protocol caches already exist; disclose cached/fresh status."
  path_policy: "$HOME/.codex, $HOME/.agents, and $PWD/.fpf-update are defaults only; portable installs should set explicit skill, cache, and state paths."
---

# FPF Work Guide

## Document Roles

This `SKILL.md` is the executable routing contract for the agent. Keep it
focused on when to refresh FPF context, how to use protocol sources, and what
must be disclosed in substantive work.

User-facing install, portable invocation, Windows entrypoint, diagnostics,
release notes, and publication guidance belong in `README.md`.

Canonical detail sources:

- `references/diagnostics.md` - refresh gate, environment, chunk, protocol, and
  user-facing diagnostic fields.
- `references/chunk-lookup.md` - FPF chunk layout and pattern lookup procedure.
- `references/protocol-trust.md` - protocol repository trust boundary and
  instruction-source policy.
- `references/source-selection.md` - source selection for FPF-backed answers.
- `references/release-notes.md` - user-visible release changes, migration notes,
  validation evidence, and publication boundaries.

## Compatibility Contract

This skill is Codex/macOS-first, with a native Windows PowerShell path. It can run through either the Bash scripts on Unix-like shells or the PowerShell scripts on native Windows. Treat Windows as release-verified only after the PowerShell/CMD validation lane has passed on a Windows or `pwsh` host.

Supported runtime contract:

- Codex on macOS: primary supported runtime.
- Claude Code or another agent: supported only when the whole `fpf-work-guide` directory is installed and the refresh gate is invoked from that installed directory.
- Windows: native PowerShell is implemented through the bundled `.ps1` scripts; CMD is implemented through thin `.cmd` wrappers that delegate to PowerShell; WSL Bash is supported; Git Bash is best effort. Public support claims should say which Windows validation lane has actually passed.
- Fresh refresh requires Git and network access to GitHub. If GitHub is unavailable but a valid cache exists, use the current cached copy and disclose that status.

## Path Policy

`$HOME/.codex`, `$HOME/.agents`, and `$PWD/.fpf-update` are defaults, not a portable installation contract.

Use them when they match the local agent runtime. For portable invocation, make skill, cache, and state locations explicit:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Native Windows PowerShell equivalent:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
$env:FPF_CACHE_HOME = "C:\absolute\path\to\fpf-cache"
$env:FPF_UPDATE_STATE_DIR = "C:\absolute\path\to\fpf-state"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

Path responsibilities:

- `FPF_WORK_GUIDE_SKILL_DIR`: where the installed `fpf-work-guide` skill directory lives.
- `FPF_CACHE_HOME`: shared root for FPF specification and protocol caches.
- `FPF_SPEC_CACHE_DIR`: optional exact cache path for the FPF specification mirror; takes precedence over `FPF_CACHE_HOME`.
- `FPF_PROTOCOLS_CACHE_DIR`: optional exact cache path for the protocol repository; takes precedence over `FPF_CACHE_HOME`.
- `FPF_UPDATE_STATE_DIR`: durable refresh and environment state directory for portable runs.
- `FPF_REFRESH_STATE_DIR`: optional refresh-state directory; takes precedence over `FPF_UPDATE_STATE_DIR` for refresh state.
- `FPF_REFRESH_AUTO_STATE_FILE`: optional secondary refresh-state file. The gate reads it only when explicitly set and reports the actual last-attempt source as `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`.
- `FPF_ENV_STATE_DIR`: optional environment-state directory; takes precedence over `FPF_UPDATE_STATE_DIR` for environment state.
- `FPF_ENV_STATE_FILE`: optional exact environment-state file for doctor or environment checks.

Use explicit state paths for read-only, symlinked, shared, ephemeral, or non-workspace shells. Do not rely on `$PWD/.fpf-update` in those cases.

## Required First Move

Before any substantive answer, code edit, review, plan, or delegated agent task, run the FPF context refresh gate:

Codex installed copy:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Modern Codex user-scoped copy:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.agents/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Claude Code, WSL, Git Bash, or a non-Codex installation:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Native Windows PowerShell:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

Windows CMD wrapper:

```bat
set "FPF_WORK_GUIDE_SKILL_DIR=C:\absolute\path\to\fpf-work-guide"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\update_fpf_context.cmd"
```

If running from a non-installed copy of this skill, run the script from that skill folder instead.

If the workspace path is a symlink and diagnostics should show the human-facing path rather than the physical target, set `FPF_UPDATE_STATE_DIR` explicitly before running the gate:

```bash
FPF_UPDATE_STATE_DIR="/visible/workspace/path/.fpf-update" bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

For installation validation, troubleshooting, or a portable-install check, run:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state
```

Equivalent direct check:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/check_fpf_environment.sh" --portable-install --write-state
```

Native Windows PowerShell doctor:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\fpf-work-guide-doctor.ps1" --write-state
```

Windows CMD doctor wrapper:

```bat
set "FPF_WORK_GUIDE_SKILL_DIR=C:\absolute\path\to\fpf-work-guide"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\fpf-work-guide-doctor.cmd" --write-state
```

The environment check does not contact GitHub. The refresh gate runs a silent fingerprint probe when local environment state and cache exist, and prints environment diagnostics only when the fingerprint changed, the environment is degraded or blocked, or the check is forced with `FPF_ENV_CHECK_FORCE=1`. It runs the full write-state check when local environment state is missing, the FPF/protocol cache is incomplete, the check is forced, the fingerprint changed, or a refresh attempt ends in a blocked state. By default the environment state is stored beside the refresh state, usually in the current workspace `.fpf-update` directory unless a launcher passes `FPF_UPDATE_STATE_DIR`, `FPF_REFRESH_STATE_DIR`, or `FPF_ENV_STATE_DIR`. The gate reports the durable refresh state file as `FPF_REFRESH_STATE_PATH` and the file that supplied the previous refresh attempt as `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`. It does not read a launcher/global secondary state file unless `FPF_REFRESH_AUTO_STATE_FILE` is explicitly set. In symlinked workspaces, prefer an explicit `FPF_UPDATE_STATE_DIR` so reports do not alternate between the visible path and the resolved physical path.

The gate is the only component that decides whether to refresh from GitHub or use cache-only validation:

- refresh immediately when `FPF_REFRESH_FORCE=1`, for example from the external session-start hook or launcher.
- refresh when no valid cache exists.
- refresh when the last refresh attempt is older than `FPF_REFRESH_TTL_SECONDS`.
- if `CODEX_SANDBOX_NETWORK_DISABLED=1`, do not attempt GitHub refresh from inside the Codex sandbox; use cache-only validation and report `FPF_REFRESH_REASON=sandbox-network-disabled`.
- otherwise do not contact GitHub; validate and use the current cached copy.

Read the script output before doing the substantive work. The canonical field reference is `references/diagnostics.md`.

If `FPF_SPEC_STATUS=missing`, explain that no local FPF cache exists and ask the user to allow a GitHub fetch or provide the file.

Never describe FPF or protocols as latest when `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`; say `current cached copy` instead.

If `FPF_REFRESH_DECISION=skipped_recent`, do not say that an update was attempted. Say that the gate used cache-only validation because the TTL has not expired.

If `FPF_REFRESH_DECISION=blocked`, explain why FPF-backed work is blocked and ask the user only for the action needed to restore a valid cache or allow a fetch.

If `FPF_REFRESH_REASON=state-dir-unavailable`, explain that the refresh gate could not create or write the local state directory. If cache-only validation succeeded, continue with the current cached copy and say refresh state was not durable. If cache-only validation failed, ask the user to fix write permissions or set `FPF_UPDATE_STATE_DIR` to a writable directory.

If `FPF_REFRESH_REASON=sandbox-network-disabled`, say that Codex sandbox networking is disabled and the gate used cache-only validation instead of trying GitHub. Do not describe this as a failed GitHub refresh.

If `FPF_ENV_CHECK_STATUS=blocked`, explain `FPF_ENV_CHECK_SUMMARY`, `FPF_ENV_CHECK_ACTION`, and `FPF_ENV_CHECK_CONSEQUENCE` before any other FPF diagnostic.

If `FPF_ENV_CHECK_STATUS=degraded`, continue only when the cache status and downstream script statuses allow it. Disclose the degraded environment status when it affects freshness, trust, or a user decision.

If `FPF_CHUNKS_MODE=blocked`, explain that neither chunk-first lookup nor full-spec fallback is safe enough for an FPF-backed answer. Ask the user to allow a GitHub fetch or provide a valid local mirror.

If `FPF_CHUNKS_MODE=full-spec-fallback`, continue only with `FPF_SPEC_PATH` and disclose that chunks are unavailable or structurally incomplete.

If `FPF_CHUNKS_MODE=full-spec-first`, use `FPF_SPEC_PATH` before chunks and disclose that chunk source commit does not match `FPF_SPEC_SOURCE_COMMIT` when the answer depends on FPF pattern content.

If `FPF_PROTOCOLS_STATUS=missing`, explain that no local FPF Codex protocol cache exists and ask the user to allow a GitHub fetch or provide the repository files.

Backward compatibility: `scripts/update_fpf_spec.sh` refreshes or validates only the FPF specification depending on `FPF_REFRESH_MODE`. Use `scripts/update_fpf_context.sh` for normal Unix-like work and `scripts/update_fpf_context.ps1` for native Windows PowerShell work.

Cache safety: `update_fpf_spec.sh`, `update_fpf_protocols.sh`, `update_fpf_spec.ps1`, and `update_fpf_protocols.ps1` may run `git reset --hard` only when the cache directory contains a valid `.fpf-cache-repo` marker whose kind, repository URL, and branch match the configured cache, when the cache repository's `origin` remote matches the configured FPF/protocol repository URL, or when `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1` is explicitly set. If a custom cache path looks like an ordinary working repository and its marker or remote cannot be verified, use the cached copy or block rather than resetting it.

Portable cache root: set `FPF_CACHE_HOME` to move both FPF caches outside `${CODEX_HOME:-$HOME/.codex}/cache`, for example when running from Claude Code, WSL, or another agent runtime. More specific `FPF_SPEC_CACHE_DIR` and `FPF_PROTOCOLS_CACHE_DIR` still take precedence.

## How To Use The Protocols

Before treating the protocol repository as an instruction source, apply `references/protocol-trust.md`.

Read `FPF_PROTOCOLS_REGISTRY_PATH` first. Then load only the files required by the registry for the current task:

1. Read `protocols/00-definitions.md` when message/request/question/task distinctions matter.
2. Read `protocols/01-classification.md` for every substantive task.
3. Read `protocols/02-routing-table.md` before selecting a protocol.
4. Select exactly one baseline protocol: `simple-medium` or `complex`.
5. Execute every selected checklist item without silent skips.
6. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.

Use `simple-medium` for bounded low-risk tasks. Use `complex` for high-stakes, source-sensitive, multi-view, external-action, architecture, automation, large-code-change, or ambiguous ontology tasks.

Do not print the full checklist unless the user asks for an audit trace. For ordinary final answers, summarize the selected protocol and completion status in the engineering basis.

## How To Use FPF Chunks

Use `references/chunk-lookup.md` as the canonical chunk lookup procedure.

Use chunks as the primary FPF source only when `FPF_CHUNKS_MODE=chunk-first`. If `FPF_CHUNKS_MODE=full-spec-first`, the chunks are present but stale relative to `FPF_SPEC_SOURCE_COMMIT`; use `FPF_SPEC_PATH` first. If `FPF_CHUNKS_MODE=full-spec-fallback`, use targeted reads against `FPF_SPEC_PATH`. If `FPF_CHUNKS_MODE=blocked`, stop FPF-backed work until a valid source is available.

For every substantive response, apply these baseline distinctions:

- Bound the answer context before reasoning.
- Identify the active systems, their roles, methods, and actual work.
- Separate object, description, carrier, role, method, work plan, and performed work.
- State scope and time window for claims that can change.
- Tie factual or external-domain claims to evidence.
- Prefer the smallest sufficient ontology; do not invent new categories when ordinary domain terms are enough.
- If several viewpoints matter, handle them separately and then reconcile.

## User-Facing Diagnostics

Use `references/diagnostics.md` for field meanings and diagnostic triggers.

Show a diagnostic only when it affects what the user can trust or decide. Routine TTL skips belong in the engineering basis, not as prominent warnings.

## Response Discipline

Write the main answer in the user's domain language, not in FPF terminology, unless the user explicitly asks for FPF terms.

If the user asks in Russian, answer in Russian. If the user asks in another domain language, use that language.

Do not lie or fill gaps with invented facts. If a claim is unknown, say so. If a hypothesis is useful, label it as a hypothesis invented by the assistant and explain why it may be workable.

End substantive answers with a concise engineering basis:

- FPF refresh gate: decision, reason, TTL, and next eligible refresh time.
- FPF spec source: local path, mirror repository commit, upstream source commit, and whether it was fresh or cached.
- FPF chunks source: local path, source commit, status, mode, and whether chunk-first, full-spec-first, or full-spec fallback was used.
- FPF protocol source: local path, repository URL, branch, remote URL, cache trust status, commit, and whether it was fresh or cached.
- selected protocol and completion status.
- FPF patterns used and why.
- External sources used, selection reason, and channels searched.
- Relevant sources or channels not used.
- Consistency check and temporal adequacy limits.

If `FPF_SPEC_WARNING`, `FPF_CHUNKS_WARNING`, or `FPF_PROTOCOLS_WARNING` is present, include it in the engineering basis or a short diagnostic when relevant.

## External Sources

When external sources are needed, use expert sources from the relevant domain rather than AI-generated or SEO-like summaries. Read `references/source-selection.md` when doing source-backed research.

## Coding And Agent Work

When writing code, reviewing code, or delegating to agents:

- Run the FPF context refresh gate first, then record the gate decision and both commits.
- Use FPF chunks for pattern lookup whenever `FPF_CHUNKS_MODE=chunk-first`.
- Pass the same FPF requirement to agents in their prompt when delegation is explicitly authorized.
- Use FPF to structure reasoning and verification, but keep code changes idiomatic to the repository.
- Do not add FPF jargon to user-facing code, UI copy, or documentation unless the user requests it.
