# Skills Index

This index lists the public Codex skills currently staged in this repository.

| Skill | Purpose | Main use case | Runtime notes |
| --- | --- | --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Improve LLM answer quality with current FPF context and Codex FPF protocols checked before substantive work. | FPF-backed reasoning, planning, review, coding, and source-backed answers. | Start with [`skills/fpf-work-guide/README.md`](skills/fpf-work-guide/README.md). Cross-platform shell entrypoints: Bash, PowerShell, and CMD wrappers. Requires `git` for refresh. Personal launchers/hooks are local automation, not a public skill overlay. |
| [`doc-to-md`](skills/doc-to-md/) | Convert trusted local documents to Markdown with MarkItDown, optional PDF audit bundles, and optional OCR preprocessing. | Local document conversion, textbook-like PDF audit, scanned-PDF OCR preprocessing, and clean Markdown intermediates before analysis. | Start with [`skills/doc-to-md/README.md`](skills/doc-to-md/README.md). Curated public skill. Core runtime is pinned MarkItDown; optional book/OCR runtimes are installed explicitly. Codex/macOS arm64 is supported for core/book/OCR on `macos-arm64-py313`; Intel macOS is supported for core/book on `macos-intel-py312`; unlisted Python minors are candidate/unverified; WSL is candidate; Claude Code needs explicit runtime paths; native Windows PowerShell/CMD is unsupported. |

## Discoverability Rule

This file is the human-readable inventory. It is not a runtime registry by itself.

Layer boundaries for staged skills, installed operational copies, private overlays, private local policy files, runtime dependencies, cache/state, generated outputs, upstream sources, and personal automation are defined in [docs/skill-artifact-model.md](docs/skill-artifact-model.md).

Reusable plugin packages are listed in [plugins/README.md](plugins/README.md). The repo-local plugin marketplace is [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json).

When adding or removing a skill, update:

- the skill directory under `skills/`;
- `skills/promote-manifest.yaml`;
- this index;
- [docs/skill-artifact-model.md](docs/skill-artifact-model.md) if the new skill introduces a new layer or dependency pattern;
- [docs/install.md](docs/install.md) if install steps change;
- [docs/validation.md](docs/validation.md) if validation expectations change.
- [plugins/README.md](plugins/README.md) and [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json) if the skill is distributed as a plugin.
