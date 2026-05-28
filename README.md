# Codex Skills and Protocols

Installable Codex skills, plugin packages, and FPF-backed protocol docs for reproducible Codex work.

Use this repository when you want to:

- install a reusable Codex skill;
- inspect how a skill is packaged before using it;
- open an issue or PR to improve a skill;
- adapt a public skill to your own workflow without copying private local state.

## What Can I Install?

| Skill | What it does | Best use case | Start here |
| --- | --- | --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Maintains and uses current cached FPF context and Codex FPF protocols. | FPF-backed reasoning, planning, review, coding, and source-backed answers. | [`plugins/fpf-work-guide`](plugins/fpf-work-guide/) or [`skills/fpf-work-guide`](skills/fpf-work-guide/) |

For the full inventory, see [`skills-index.md`](skills-index.md).

## Install Via Plugin

Use plugin installation when you want the cleanest reusable distribution unit.

This repository exposes plugin metadata here:

```text
.agents/plugins/marketplace.json
```

Available plugin packages:

- [`plugins/fpf-work-guide`](plugins/fpf-work-guide/) - plugin package for the public `fpf-work-guide` skill.

If your Codex setup supports repo-local plugin marketplace discovery, point it at this repository's marketplace metadata. If not, use the manual skill-folder install below.

## Install Manually

Manual installation copies a public staged skill into the skill directory used by your agent runtime.

Recommended user-scoped Codex target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Install `fpf-work-guide`:

```bash
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

For legacy/current local Codex setups that still load from `${CODEX_HOME:-$HOME/.codex}/skills`, or for Claude Code, WSL, and non-default paths, use the detailed instructions in [`docs/install.md`](docs/install.md).

## Open Issue Or PR

Issues and PRs are useful for:

- installation failures;
- unclear diagnostics;
- portability fixes for another shell, OS, or agent runtime;
- docs corrections;
- adapting a skill to a real workflow without adding private local state to the public artifact.

Include the skill name, OS/runtime, installation path, command you ran, and the relevant diagnostic output. For `fpf-work-guide`, include whether the run used fresh data or the current cached copy when that status is shown.

## Validate Before Sharing

Run the structural checks before publishing or sharing changes:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

More detail: [`docs/validation.md`](docs/validation.md).

## Top-Level Map

| Path | What it is | Who usually reads it |
| --- | --- | --- |
| [`.agents/`](.agents/) | Machine-readable Codex agent configuration. Currently contains repo-local plugin marketplace metadata. | Codex/plugin tooling and maintainers checking plugin discovery. |
| [`docs/`](docs/) | Installation docs, validation docs, architecture notes, ADRs, process models, and examples. | Users, reviewers, maintainers. |
| [`plugins/`](plugins/) | Installable Codex plugin packages that bundle public skills for distribution. | Users installing via plugin and maintainers validating packaging. |
| [`protocols/`](protocols/) | FPF-backed response protocol definitions, routing rules, checklists, SOPs, and templates. | Users who want to inspect the reasoning protocol internals. |
| [`scripts/`](scripts/) | Validation, promotion, drift-check, and release-gate scripts. | Maintainers and contributors. |
| [`skills/`](skills/) | Public staged skill source. This is reviewable source, not necessarily the active local runtime copy. | Users installing manually and contributors reviewing skill behavior. |
| [`.gitignore`](.gitignore) | Rules that keep local state and generated files out of the public artifact. | Maintainers. |
| [`README.md`](README.md) | This entrypoint. | Everyone. |
| [`registry.yaml`](registry.yaml) | Canonical file registry and protocol routing anchors. | Maintainers and protocol tooling. |
| [`skills-index.md`](skills-index.md) | Human-readable inventory of staged skills and runtime notes. | Users and maintainers. |

Local-only state directories such as `.fpf-update/` may exist in a working checkout, but they are intentionally ignored and should not be published as public skill or plugin content.

## FPF Protocol Internals

This repository is not the FPF specification. It is a procedure and packaging layer around selected Codex skills and FPF-backed protocols.

Canonical registry: [`registry.yaml`](registry.yaml)

Skills index: [`skills-index.md`](skills-index.md)

Plugin marketplace metadata: [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json)

### Core Rule

Before any substantive answer, code edit, review, research task, plan, or delegated agent task:

1. Refresh or validate the FPF specification cache.
2. Refresh or validate this protocol repository cache.
3. Classify the normalized task, not only the raw user message.
4. Select exactly one baseline protocol: `simple-medium` or `complex`.
5. Execute every checklist item in the selected protocol.
6. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.
7. Include protocol and FPF commit identifiers in the engineering basis when the answer is substantive.

## Artifact Boundary

The staged public copy under `skills/` is not the same artifact as an installed operational copy under `$HOME/.agents/skills`, `${CODEX_HOME:-$HOME/.codex}/skills`, or another agent-specific runtime location.

Plugin packages under `plugins/` bundle public skill source only. They must not include personal launchers, LaunchAgents, session-start hooks, workspace jobs, cache, logs, local state, private overlays, private local policy files, runtime venvs, OCR binaries, or generated outputs.

Use [`docs/skill-artifact-model.md`](docs/skill-artifact-model.md) as the public repository contract before packaging, redistributing, or reviewing skill artifacts.

Use [`docs/workflows/promote-local-skills.md`](docs/workflows/promote-local-skills.md) when updating public staged skills from local operational skills.

## License

This repository is licensed under the [MIT License](LICENSE), unless otherwise noted.

Third-party tools and dependencies keep their own licenses. Review skill-specific third-party notices before redistributing optional runtimes or dependency bundles.
