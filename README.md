# Codex Skills and Protocols

Operational protocols and Codex skills for using the current First Principles Framework (FPF) specification in Codex work.

This repository is not the FPF specification. It is the user-specific procedure layer that tells Codex how to classify incoming user messages, choose a short or long FPF-backed protocol, execute every required checklist step, disclose evidence/cache status/remaining uncertainty, and reuse selected skills.

Canonical registry: [registry.yaml](registry.yaml)

Skills index: [skills-index.md](skills-index.md)

Plugin marketplace metadata: [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json)

## Core Rule

Before any substantive answer, code edit, review, research task, plan, or delegated agent task:

1. Refresh the FPF specification cache.
2. Refresh this protocol repository cache.
3. Classify the normalized task, not only the raw user message.
4. Select exactly one baseline protocol: `simple-medium` or `complex`.
5. Execute every checklist item in the selected protocol.
6. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.
7. Include protocol and FPF commit identifiers in the engineering basis when the answer is substantive.

## Repository Layout

- [registry.yaml](registry.yaml) - current file registry and protocol routing anchors.
- [skills-index.md](skills-index.md) - inventory of staged skills and their intended use.
- [skills/](skills/) - staged public copies of local Codex skills.
- [plugins/](plugins/) - Codex plugin distribution artifacts for reusable installable skill packages.
- [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json) - machine-readable repo-local catalog that tells Codex which plugins this repository exposes.
- [docs/skill-artifact-model.md](docs/skill-artifact-model.md) - layer model for public staged copies, installed operational copies, private overlays, runtime dependencies, cache/state, outputs, and personal automation.
- [docs/adr/0001-fpf-latest-architecture.md](docs/adr/0001-fpf-latest-architecture.md) - accepted architecture decisions for `fpf-latest`.
- [docs/install.md](docs/install.md) - installation instructions for selected skills.
- [docs/validation.md](docs/validation.md) - validation checklist and local validation command.
- [docs/workflows/promote-local-skills.md](docs/workflows/promote-local-skills.md) - workflow for promoting local skills into public staged skills.
- [protocols/00-definitions.md](protocols/00-definitions.md) - message/request/question/task distinctions.
- [protocols/01-classification.md](protocols/01-classification.md) - task complexity classification.
- [protocols/02-routing-table.md](protocols/02-routing-table.md) - protocol routing and OpenAI-guideline handling.
- [protocols/checklists/simple-medium.md](protocols/checklists/simple-medium.md) - mandatory short checklist.
- [protocols/checklists/complex/00-master.md](protocols/checklists/complex/00-master.md) - mandatory complex checklist bundle.
- [protocols/sop/simple-medium-sop.md](protocols/sop/simple-medium-sop.md) - explanations for the short checklist.
- [protocols/sop/complex-sop.md](protocols/sop/complex-sop.md) - explanations for the complex checklist bundle.
- [protocols/templates/protocol-execution-record.yaml](protocols/templates/protocol-execution-record.yaml) - protocol execution record template.
- [docs/process-models/](docs/process-models/) - reference process models, including the assistant-user interaction model used to align OpenAI/API-facing terms with protocol-local terms.
- [docs/examples.md](docs/examples.md) - worked examples and collaboration usage scenario.

## Staged Skills

The `skills/` directory contains staged public copies of selected Codex skills. It is meant for installation, review, issue/PR collaboration, and adaptation by another user. It is not a guarantee that every local machine already has the required optional runtimes installed.

Use [docs/skill-artifact-model.md](docs/skill-artifact-model.md) to distinguish public staged copies, installed operational copies, private overlay skills, runtime dependencies, cache/state, generated outputs, upstream sources, and personal automation.

Personal automation around `fpf-latest`, such as launchers, session-start hooks, LaunchAgents, workspace jobs, and local state files, is local infrastructure around the public skill. It is not a public skill overlay and is not staged under `skills/`.

Use [docs/validation.md](docs/validation.md) before installing or sharing skills from this repository.

Use [docs/workflows/promote-local-skills.md](docs/workflows/promote-local-skills.md) when updating public staged skills from local Codex skills.

## Plugins

The `plugins/` directory contains installable Codex plugin packages for sharing selected public skills beyond one local checkout. The current public plugin is [`plugins/fpf-latest`](plugins/fpf-latest/). It bundles the public skill without personal launchers, LaunchAgents, workspace jobs, cache, logs, local state, private overlays, or generated outputs.

Use `scripts/validate-plugins.sh` before sharing plugin artifacts.
