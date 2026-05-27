# Examples

## Simple-Medium Example

User message:

> Explain what a bounded context is in simple words.

Classification:

- Normalized task: explain a stable concept.
- Protocol: simple-medium.
- Reason: low-risk, one objective, no external current facts needed.

Answer shape:

1. Plain explanation in the user's language.
2. One short example.
3. Engineering basis with FPF commit and protocol commit.

Checklist status summary:

- FPF and protocol refreshed: done or cached with warning.
- Scope stated: done.
- Active system/role/work identified internally: done.
- Evidence needed: not_applicable, FPF spec only.
- Consistency and temporal adequacy checked: done.
- Simple-medium checklist complete.

## Complex Example

User message:

> Create a new Codex skill that refreshes FPF and applies my protocols before every answer.

Classification:

- Normalized task: create durable automation instructions and scripts for future Codex behavior.
- Protocol: complex.
- Reason: file creation, tool behavior, external GitHub source, cache fallback, future agent behavior.

Phase summary:

- 10 Intake and Scope: define skill boundaries, fallback behavior, installation path, and user-facing limitations.
- 20 Actors, Roles, Work: Codex edits files; shell runs scripts; GitHub mirror supplies source; future agents consume the skill.
- 30 Sources and Evidence: FPF spec path and commit; skill-creator instructions; script test output.
- 40 Reasoning and Answer: implement skill files, test script, explain how to invoke.
- 50 Final Audit: report commit, cache status, validation limits, and residual risk.

Checklist status summary:

- Complex checklist bundle complete unless blocked by missing permissions or unavailable network.

## Collaboration Use Case

Another Codex user receives this repository and wants to reuse one or more skills in their own workflow.

The user can:

- inspect available skills in [`../skills-index.md`](../skills-index.md);
- install selected skills using [`install.md`](install.md);
- run validation using [`validation.md`](validation.md);
- open an issue or pull request when a skill is unclear, broken, or missing a needed use case;
- adapt a skill for their own process while preserving the original repository as a reference.

Expected outcome: the repository works as a reusable skill pack that another person can install, review, improve, or adapt.
