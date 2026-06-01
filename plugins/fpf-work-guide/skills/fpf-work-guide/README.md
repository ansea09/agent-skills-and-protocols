# fpf-work-guide

Public Codex skill for refreshing or validating the current FPF context and
using the `agent-skills-and-protocols` repository as the FPF-backed procedure
layer for substantive Codex work.

This README is for users and maintainers. `SKILL.md` is the executable routing
contract that an agent reads after the skill triggers. Detailed runtime field
meanings live in `references/`.

## Install

Recommended user-scoped Codex target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
```

Run the portable doctor once after installation:

```bash
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

For legacy/current local Codex setups that still load skills from
`${CODEX_HOME:-$HOME/.codex}/skills`, use that path as the install target:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export CODEX_SKILLS_TARGET="$CODEX_HOME/skills"
mkdir -p "$CODEX_SKILLS_TARGET"
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

Fresh refresh requires Git and GitHub network access. If network access is
unavailable but valid FPF and protocol caches already exist, the skill can use
the current cached copy and must disclose cached/fresh status.

## Portable Invocation

`$HOME/.codex`, `$HOME/.agents`, and `$PWD/.fpf-update` are defaults, not a
portable installation contract. For Claude Code, WSL, Git Bash, shared
workspaces, symlinked workspaces, read-only checkouts, or non-default runtime
locations, set explicit paths:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Run the portable doctor with the same explicit path policy:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state
```

## Native Windows Entry Points

The skill includes native PowerShell scripts and CMD wrappers. Windows paths are
implemented, but a release should claim Windows verification only after the
PowerShell and CMD validation lanes have passed on a Windows or `pwsh` host.

PowerShell refresh gate:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
$env:FPF_CACHE_HOME = "C:\absolute\path\to\fpf-cache"
$env:FPF_UPDATE_STATE_DIR = "C:\absolute\path\to\fpf-state"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

PowerShell doctor:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\fpf-work-guide-doctor.ps1" --write-state
```

CMD wrappers delegate to PowerShell:

```bat
set "FPF_WORK_GUIDE_SKILL_DIR=C:\absolute\path\to\fpf-work-guide"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\update_fpf_context.cmd"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\fpf-work-guide-doctor.cmd" --write-state
```

## Usage

Before substantive reasoning, coding, review, research, planning, document
drafting, agent work, or source-backed answers, run the refresh gate:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Modern user-scoped Codex install:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.agents/skills/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Read the gate output before using FPF or protocols. Important fields include:

- `FPF_REFRESH_DECISION`
- `FPF_SPEC_COMMIT` and `FPF_SPEC_STATUS`
- `FPF_CHUNKS_SOURCE_COMMIT`, `FPF_CHUNKS_STATUS`, and `FPF_CHUNKS_MODE`
- `FPF_PROTOCOLS_COMMIT`, `FPF_PROTOCOLS_STATUS`, and protocol cache trust fields
- `FPF_REFRESH_STATE_PATH` and `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`

Never describe cached FPF or cached protocol content as latest. Say `current
cached copy` when the gate reports cached status.

## Protocol Use

The protocol repository is treated as an instruction source, not merely
reference text. Before using it, apply `references/protocol-trust.md`.

For substantive tasks:

1. Read the registry from `FPF_PROTOCOLS_REGISTRY_PATH`.
2. Read `protocols/00-definitions.md` when message/request/question/task
   distinctions matter.
3. Read `protocols/01-classification.md`.
4. Read `protocols/02-routing-table.md`.
5. Select exactly one baseline protocol: `simple-medium` or `complex`.
6. Execute every selected checklist item without silent skips.
7. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.

Use `simple-medium` for bounded low-risk tasks. Use `complex` for high-stakes,
source-sensitive, multi-view, external-action, architecture, automation,
large-code-change, or ambiguous ontology tasks.

## FPF Source Use

Use `references/chunk-lookup.md` for chunk lookup.

Chunks are primary only when `FPF_CHUNKS_MODE=chunk-first`. If chunks are stale
or degraded, use `FPF_SPEC_PATH` first or as fallback according to the gate
mode. If neither chunks nor full spec are safe enough, stop FPF-backed work and
ask the user to allow a fetch or provide valid sources.

## User-Facing Diagnostics

Show diagnostics only when the state affects what the user can trust or decide.
Routine TTL skips belong in the engineering basis, not as prominent warnings.

Use `references/diagnostics.md` for field meanings and diagnostic triggers.
Common diagnostic cases include:

- missing FPF spec or protocol cache;
- blocked refresh gate;
- unavailable or unwritable state directory;
- degraded environment check;
- stale chunks and full-spec-first mode;
- ambiguous protocol cache provenance;
- Codex sandbox networking disabled, with cache-only validation used instead
  of a GitHub refresh;
- missing GitHub/network access when no valid cache exists.

## Release Notes

Read `references/release-notes.md` before publishing or installing a new
version. Release notes describe public source changes and required maintainer or
user actions. They do not treat local cache, generated outputs, personal
launchers, session-start hooks, or installed wrapper state as release payloads.

## Publication Notes

This public skill must not include personal launchers, LaunchAgents,
session-start hooks, workspace jobs, `.fpf-update/`, cache directories, logs,
machine-local env files, private overlays, or generated outputs.

Plugin distribution is source-only. Installing a plugin does not prove GitHub
access, cache freshness, Windows validation, or personal session-start
automation.

Before publishing or sharing changes, run from the repository root:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

For `fpf-work-guide` script or compatibility changes, also review
`docs/adr/0001-fpf-work-guide-architecture.md`,
`docs/fpf-work-guide-behavior-model.md`, `docs/install.md`,
`docs/validation.md`, `docs/skill-artifact-model.md`, and
`docs/workflows/promote-local-skills.md`.
