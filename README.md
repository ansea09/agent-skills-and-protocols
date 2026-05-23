# FPF Codex Protocols

Operational protocols for using the current First Principles Framework (FPF) specification in Codex work.

This repository is not the FPF specification. It is the user-specific procedure layer that tells Codex how to classify incoming user messages, choose a short or long FPF-backed protocol, execute every required checklist step, and disclose evidence, cache status, and remaining uncertainty.

Canonical registry: [registry.yaml](registry.yaml)

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
- [protocols/00-definitions.md](protocols/00-definitions.md) - message/request/question/task distinctions.
- [protocols/01-classification.md](protocols/01-classification.md) - task complexity classification.
- [protocols/02-routing-table.md](protocols/02-routing-table.md) - protocol routing and OpenAI-guideline handling.
- [protocols/checklists/simple-medium.md](protocols/checklists/simple-medium.md) - mandatory short checklist.
- [protocols/checklists/complex/00-master.md](protocols/checklists/complex/00-master.md) - mandatory complex checklist bundle.
- [protocols/sop/simple-medium-sop.md](protocols/sop/simple-medium-sop.md) - explanations for the short checklist.
- [protocols/sop/complex-sop.md](protocols/sop/complex-sop.md) - explanations for the complex checklist bundle.
- [examples/](examples/) - worked examples.
