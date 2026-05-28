# Skills Index

This index lists the public Codex skills currently staged in this repository.

| Skill | Purpose | Main use case | Runtime notes |
| --- | --- | --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Maintain and use current cached FPF context and Codex FPF protocols. | FPF-backed reasoning, planning, review, coding, and source-backed answers. | Cross-platform shell entrypoints: Bash, PowerShell, and CMD wrappers. Requires `git` for refresh. Personal launchers/hooks are local automation, not a public skill overlay. |

## Discoverability Rule

This file is the human-readable inventory. It is not a runtime registry by itself.

Layer boundaries for staged skills, installed operational copies, private overlays, runtime dependencies, cache/state, generated outputs, upstream sources, and personal automation are defined in [docs/skill-artifact-model.md](docs/skill-artifact-model.md).

Reusable plugin packages are listed in [plugins/README.md](plugins/README.md). The repo-local plugin marketplace is [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json).

When adding or removing a skill, update:

- the skill directory under `skills/`;
- `skills/promote-manifest.yaml`;
- this index;
- [docs/skill-artifact-model.md](docs/skill-artifact-model.md) if the new skill introduces a new layer or dependency pattern;
- [docs/install.md](docs/install.md) if install steps change;
- [docs/validation.md](docs/validation.md) if validation expectations change.
- [plugins/README.md](plugins/README.md) and [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json) if the skill is distributed as a plugin.
