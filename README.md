# Agent Skills and Protocols

Russian version: [`README.ru.md`](README.ru.md)

This repository publishes reusable Codex skills, Codex plugin packages, Claude Code install profiles, and FPF-backed protocol documentation.

Use it when you want to:

- install a public skill for Codex;
- install a Codex plugin that bundles a public skill;
- install a Claude Code profile for a supported public skill;
- inspect how skills, plugins, runtime files, and local state are separated;
- contribute fixes without publishing private local configuration.

## Choose What To Install

| You want to | Install | Start here |
| --- | --- | --- |
| Make Codex use current FPF context and FPF-backed protocols before substantive work | `fpf-work-guide` | [`skills/fpf-work-guide/README.md`](skills/fpf-work-guide/README.md) |
| Convert trusted local documents to Markdown | `doc-to-md` | [`skills/doc-to-md/README.md`](skills/doc-to-md/README.md) |
| Transcribe trusted local speech audio into Markdown bundles | `speech-to-md` | [`skills/speech-to-md/README.md`](skills/speech-to-md/README.md) |
| Install through Codex plugin packaging | Codex plugin package | [`plugins/`](plugins/) |
| Use a supported public skill from Claude Code | Claude Code source-only profile | [`claude-code/`](claude-code/) |

Available public skills:

| Skill | What it does |
| --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Validates or refreshes local FPF context and applies FPF-backed protocols before substantive Codex work. |
| [`doc-to-md`](skills/doc-to-md/) | Converts trusted local files to Markdown with MarkItDown, optional PDF audit bundles, and optional OCR preprocessing. |
| [`speech-to-md`](skills/speech-to-md/) | Converts trusted local speech recordings or existing transcripts into Markdown transcript bundles for LLM analysis. |

Full inventory: [`skills-index.md`](skills-index.md).

## Quick Start

For most Codex users, start with `fpf-work-guide`.

If your Codex setup supports repo-local plugin marketplace discovery, use the plugin package:

```text
.agents/plugins/marketplace.json
```

Available plugin packages:

- [`plugins/fpf-work-guide`](plugins/fpf-work-guide/)
- [`plugins/doc-to-md`](plugins/doc-to-md/)
- [`plugins/speech-to-md`](plugins/speech-to-md/)

If plugin marketplace discovery is not available, install the skill manually.

## Install Manually For Codex

Manual installation copies public skill source into the skill directory used by your local agent runtime.

Recommended user-scoped target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Install `fpf-work-guide`:

```bash
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

Install `doc-to-md` and build its core runtime:

```bash
cp -R skills/doc-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh"
```

Install `speech-to-md` and its command shim:

```bash
cp -R skills/speech-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/speech-to-md/scripts/install.sh"
speech-to-md --doctor
```

Local ASR needs user-installed `whisper-cli` and a model. MP3/M4A and other
container normalization paths also need local `ffmpeg`; the public skill does
not bundle those runtime binaries or models.

For legacy Codex setups that still load skills from `${CODEX_HOME:-$HOME/.codex}/skills`, or for WSL and non-default paths, read [`docs/install.md`](docs/install.md).

## Install In Claude Code

Claude Code does not use Codex plugins. Use source-only install profiles under [`claude-code/`](claude-code/).

Current profile:

- [`claude-code/fpf-work-guide`](claude-code/fpf-work-guide/) installs Claude Code slash commands and a subagent that invoke the public `fpf-work-guide` skill.

## What Gets Installed Locally

This repository separates source, packaging, runtime dependencies, and generated files.

| Layer | Examples | Published here? |
| --- | --- | --- |
| Public skill source | `skills/fpf-work-guide`, `skills/doc-to-md`, `skills/speech-to-md` | Yes |
| Codex plugin package | `plugins/fpf-work-guide`, `plugins/doc-to-md`, `plugins/speech-to-md` | Yes |
| Claude Code profile | `claude-code/fpf-work-guide` | Yes |
| Runtime dependencies | Python virtual environments, installed command shims, OCR tools, ASR models, external ASR binaries | No |
| Local state and cache | `.fpf-update`, FPF caches, logs | No |
| Generated outputs | Markdown files, OCR PDFs, audit bundles | No |
| Private local policy | Personal defaults, private overlays, local launchers | No |

Detailed model: [`docs/skill-artifact-model.md`](docs/skill-artifact-model.md).

## If Something Fails

Open an issue or PR for:

- installation failures;
- unclear diagnostics;
- portability problems on another OS, shell, or agent runtime;
- documentation errors;
- changes needed for a real workflow without publishing private local state.

Include:

- skill or plugin name;
- OS and runtime;
- installation path;
- command you ran;
- diagnostic output or warning.

For `fpf-work-guide`, include whether the run used fresh data or the current cached copy when that status is shown.

## Maintainer Docs

Use these before publishing or reviewing changes:

- [`docs/install.md`](docs/install.md)
- [`docs/validation.md`](docs/validation.md)
- [`docs/skill-artifact-model.md`](docs/skill-artifact-model.md)
- [`docs/workflows/promote-local-skills.md`](docs/workflows/promote-local-skills.md)

Run structural checks before sharing changes:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

For `doc-to-md` source or plugin release checks, also run the release gate described in [`docs/validation.md`](docs/validation.md).

## Repository Map

| Path | What it is |
| --- | --- |
| [`.agents/`](.agents/) | Repo-local Codex plugin marketplace metadata. |
| [`claude-code/`](claude-code/) | Source-only Claude Code install profiles. |
| [`docs/`](docs/) | Installation, validation, artifact model, ADRs, process models, and workflows. |
| [`plugins/`](plugins/) | Codex plugin packages that bundle public skill source. |
| [`protocols/`](protocols/) | FPF-backed protocol definitions, routing rules, checklists, SOPs, and templates. |
| [`scripts/`](scripts/) | Validation, promotion, drift-check, and release-gate scripts. |
| [`skills/`](skills/) | Public staged skill source. |
| [`registry.yaml`](registry.yaml) | Canonical registry and protocol routing anchors. |
| [`skills-index.md`](skills-index.md) | Human-readable inventory of public staged skills. |

## License

This repository is licensed under the [MIT License](LICENSE), unless otherwise noted.

Third-party tools and dependencies keep their own licenses. Review skill-specific third-party notices before redistributing optional runtimes or dependency bundles.
