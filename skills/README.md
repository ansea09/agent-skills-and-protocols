# Skills

This directory contains staged public copies of selected local Codex skills.

Each skill is stored in its own directory and must include:

- `SKILL.md`;
- YAML frontmatter with `name` and `description`;
- optional `agents/openai.yaml`;
- optional `references/`, `scripts/`, or requirements files when the skill needs supporting material.

The source of truth for the staged list is [`../skills-index.md`](../skills-index.md).

The layer model is [`../docs/skill-artifact-model.md`](../docs/skill-artifact-model.md). Local automation around a skill, including `fpf-work-guide` session-start hooks or workspace launchers, is not a staged public skill overlay. Keep those files outside `skills/` unless they become an explicitly reviewed public skill artifact.

Install and validation instructions:

- [Install selected skills](../docs/install.md)
- [Validate staged skills](../docs/validation.md)
