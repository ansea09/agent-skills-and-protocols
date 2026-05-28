# Skill Artifact Model

## Purpose

Use this model when publishing, installing, validating, or reviewing Codex skills in this repository.

A skill can exist in several related layers. These layers must not be collapsed into one "skill" object, because each layer has a different audience, trust boundary, and publication rule.

## Layers

| Layer | Typical location | Purpose | Publication rule |
| --- | --- | --- | --- |
| Public staged copy | `skills/<name>/` in this repository | Reviewed public artifact for installation, issue discussion, and reuse. `SKILL.md` is the executable routing contract; optional `README.md` is user/maintainer documentation for published, operationally complex, or plugin-packaged skills. | May be committed and published after validation and manual diff review. |
| Plugin distribution artifact | `plugins/<name>/` plus `.agents/plugins/marketplace.json` | Installable Codex package for sharing one or more public skills beyond a local checkout. Bundled skill copies include the same optional skill README as the staged source when that README exists. | May be committed and published after plugin validation and manual diff review. |
| Claude Code install profile | `claude-code/<name>/` | Source-only adapter that installs Claude Code-native slash commands, subagents, or settings snippets while reusing public staged skill source. | May be committed and published after profile validation and manual diff review; must not be called a Codex plugin. |
| Installed operational copy | `$HOME/.agents/skills/<name>/`, `$REPO_ROOT/.agents/skills/<name>/`, `${CODEX_HOME:-$HOME/.codex}/skills/<name>/`, or another agent-specific runtime location | Active local copy loaded by Codex or another agent in a user environment. | Not automatically public; may drift from the staged copy. |
| Private overlay skill | `$HOME/.agents/skills/<name>-private/`, `${CODEX_HOME:-$HOME/.codex}/skills/<name>-private/`, or another clearly private skill name | Personal defaults, local workflows, private fixtures, or user-specific policy layered on top of a public skill. | Never publish unless deliberately converted into a reviewed public skill. |
| Private local policy file | `private/local-policies/<name>.md`, private notes, or another approved private repository path | Advisory user-specific defaults for an existing public skill, without creating a second skill. | Never publish in public skill or plugin artifacts; may be versioned only in a private repository. |
| Runtime dependency layer | `${CODEX_HOME:-$HOME/.codex}/tools/`, `~/.local/bin`, system packages, venvs, external CLIs | Executables and libraries used by skill scripts. | Document requirements; do not treat installed binaries or venvs as staged skill source. |
| Cache and state layer | `${CODEX_HOME:-$HOME/.codex}/cache`, `.fpf-update/`, `~/.local/state`, logs | Local refresh state, fetched mirrors, cache status, evidence of recent runs, and diagnostics. | Never publish as skill source; use only as local evidence or troubleshooting context. |
| Personal automation layer | workspace launchers, shell aliases, cron/launchd jobs, Codex automations, local wrapper jobs | Convenience automation that invokes an installed operational copy or its scripts. | Not a public skill overlay; public skills must not depend on it. |
| Generated output layer | converted documents, reports, temp directories, user outputs, generated audit bundles | Results produced by using a skill. | Not part of the skill unless intentionally added as reviewed fixtures or examples. |
| Upstream source layer | package indexes, GitHub source repos, FPF mirrors, third-party docs | External sources used to install, refresh, or verify skill behavior. | Pin, cite, or disclose as needed; do not confuse upstream source with local staged skill content. |

## Typed Artifact Relations

Use typed relations instead of one generic dependency chain. The artifact layers
do not all relate to each other in the same way.

| Relation | From | To | Meaning | Review rule |
| --- | --- | --- | --- | --- |
| `packaged-as` | Public staged copy | Plugin distribution artifact | A plugin bundles reviewed public skill source for distribution. | Plugin content must stay source-only and must match staged skill source where validation requires it. |
| `adapted-for` | Public staged copy | Claude Code install profile | A Claude Code profile installs Claude-native commands or subagents that call the staged skill scripts. | Profiles must stay source-only and must not fork public skill semantics. |
| `installed-from` | Public staged copy or plugin distribution artifact | Installed operational copy | A user or tool copies source into an agent runtime location. | Installed copies may drift; diagnose installed behavior separately from staged source. |
| `uses-runtime` | Installed operational copy | Runtime dependency layer | Skill scripts call local commands, venvs, package managers, or external tools. | Document prerequisites; do not treat installed binaries or venvs as staged source. |
| `writes-state` | Installed operational copy | Cache and state layer | Runtime execution writes cache, logs, status, or diagnostic state. | State is local evidence, not public source. |
| `produces-output` | Installed operational copy | Generated output layer | Skill usage creates user artifacts such as converted files, reports, and audit bundles. | Outputs are not skill source unless deliberately reviewed as fixtures or examples. |
| `invokes` | Personal automation layer | Installed operational copy | Local launchers, hooks, jobs, or aliases call an installed skill. | Public skills may document automation examples but must not require them. |
| `extends-locally` | Private overlay skill | Public staged, plugin-distributed, or installed skill | A private skill layers local policy or workflows on top of public behavior. | Private overlays must not redefine public command semantics or be required by public artifacts. |
| `advises` | Private local policy file | Public staged, plugin-distributed, or installed skill | Private notes record operator preferences without creating a second public skill. | Public artifacts may not require private policy files. |
| `refreshes-from` | Installed operational copy or runtime dependency layer | Upstream source layer | Runtime tools fetch, install, or validate against external repositories, package indexes, or docs. | Pin, cite, or disclose freshness and trust status where it affects behavior. |

Forbidden inverse relations:

- Public staged skills and plugin artifacts must not require private overlays,
  private local policy files, personal automation, local cache/state, generated
  outputs, or machine-specific paths.
- Plugin artifacts must not be treated as runtime state dumps.
- Claude Code install profiles must not be treated as Codex plugins or as
  separate skill implementations.
- Runtime dependencies and generated outputs must not be promoted into public
  skill source unless they are intentionally reviewed fixtures, examples, or
  small scripts that belong under `skills/<name>/`.

## Review Rules

- Review `skills/<name>/` as a publication artifact, not as a live mirror of the local machine.
- Review `plugins/<name>/` as an installable package, not as a local runtime state dump.
- Validate an installed operational copy separately when diagnosing local behavior.
- Treat private overlay skills as local policy and convenience. They can document personal defaults but must not redefine public command semantics.
- Treat private local policy files as advisory preferences for an operator or agent. They are not separate skills and must not redefine public command semantics.
- Treat runtime dependencies as prerequisites or install outputs, not as bundled skill source unless they are small reviewed scripts under `skills/<name>/scripts/`.
- Treat cache/state files and logs as evidence carriers for a local run, not as source files.
- Treat personal automation as local infrastructure. It may call a skill, but the staged skill must still work without it.
- Treat generated outputs as user artifacts. Do not commit them unless they are intentionally reviewed examples or fixtures.

## Current Examples

### fpf-work-guide

- Public staged copy: `skills/fpf-work-guide/`.
- User-facing skill README: `skills/fpf-work-guide/README.md`.
- Plugin distribution artifact: `plugins/fpf-work-guide/`.
- Claude Code install profile: `claude-code/fpf-work-guide/`.
- Installed operational copy: `$HOME/.agents/skills/fpf-work-guide/`, `$REPO_ROOT/.agents/skills/fpf-work-guide/`, `${CODEX_HOME:-$HOME/.codex}/skills/fpf-work-guide/`, or another agent-specific runtime location.
- Runtime dependency layer: shell utilities and `git`.
- Cache and state layer: `${FPF_CACHE_HOME:-${CODEX_HOME:-$HOME/.codex}/cache}/fpf-spec-mirror`, `${FPF_CACHE_HOME:-${CODEX_HOME:-$HOME/.codex}/cache}/codex-skills-and-protocols`, `.fpf-update/`, and `~/.local/state/codex-fpf/`.
- Personal automation layer: workspace launchers, session-start hooks, LaunchAgents, and update jobs that call `fpf-work-guide`.

`fpf-work-guide` personal automation is not a public skill overlay. It must not be staged under `skills/fpf-work-guide/`, and the public skill must not require it.

`fpf-work-guide` refresh decisions are partly state-driven. `latest.env` records the last refresh attempt, TTL, next eligible refresh time, and source commits. `latest-output.env` records wrapper-captured gate output for local status inspection and must not replace the durable gate state file. `environment.env` records the local environment fingerprint used by the doctor and refresh gate. These files may exist both in a workspace state directory such as `.fpf-update/` and in a personal launcher state directory such as `~/.local/state/codex-fpf/`. The refresh gate reads a secondary launcher/global state file only when `FPF_REFRESH_AUTO_STATE_FILE` is explicitly set, and it reports the actual previous-attempt source as `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`. They are evidence carriers for local operation, not public source files.

When state is unavailable, the refresh gate must classify that as `state-dir-unavailable`. It must not report it as `active-refresh`, because an unwritable state path and a real concurrent refresh are different operational conditions.

The public behavior model for task admission, substantive versus non-substantive interactions, and refresh-gate event semantics is [fpf-work-guide-behavior-model.md](fpf-work-guide-behavior-model.md). It is public skill documentation, not a personal automation layer.

The Claude Code install profile installs Claude Code slash commands and a
subagent that invoke the same public staged skill scripts. It is an adapter
profile, not a fork of the skill and not a Codex plugin.

### doc-to-md

- Public staged copy: `skills/doc-to-md/`.
- User-facing skill README: `skills/doc-to-md/README.md`.
- Plugin distribution artifact: `plugins/doc-to-md/`.
- Installed operational copy: `${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/`, `$HOME/.agents/skills/doc-to-md/`, `$REPO_ROOT/.agents/skills/doc-to-md/`, or another agent-specific runtime location.
- Private local policy file: for example `private/local-policies/doc-to-md.md`.
- Runtime dependency layer: MarkItDown core venv, optional book/OCR venvs, installer-generated `~/.local/bin` command shims, Tesseract, Ghostscript, and related external tools.
- Generated output layer: Markdown files, OCR PDFs, audit bundles, conversion reports, extracted assets, and comparison artifacts.

`doc-to-md` uses one public skill, not a required public/private pair of skills. Reusable workflow profiles such as `Standard Local Document Profile` and `Textbook Audit + OCR Profile` belong in the public skill. Personal preferences, such as preferring `eng+rus` for the author's English/Russian OCR materials, belong in private local policy and must not become universal public defaults.
