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

- FPF gate executed: done; result may be a valid current cached copy, not a refresh.
- Scope stated: done.
- Formal actor/role inventory: not_applicable if it does not affect this explanation.
- Evidence checked: done, using the relevant specification body and its version.
- Consistency and temporal adequacy checked: done.
- Simple-medium checklist complete.

## Complex Example

User message:

> Create a new Codex skill that refreshes FPF and applies my protocols before every answer.

Classification:

- Normalized task: create durable automation instructions and scripts for future Codex behavior.
- Protocol: complex.
- Reason: file creation, tool behavior, external GitHub source, cache fallback, future agent behavior.

Six-stage summary:

- C1 Define the request: distinguish substantive tasks from social/control turns.
- C2 Establish basis: scope, permissions, existing implementation and sources.
- C3 Select applicable routes: performers/work, source trust and change risks.
- C4 Implement authorized changes; a script describes operations, not an acting system.
- C5 Run tests; separate completed checks from pass/fail/unknown outcomes.
- C6 Deliver with versions, validation limits, residual risk and continuation.

Complex support documents explain these stages; they are not five additional
mandatory passes. For a material source-condition mapping, use the worked
[source-fidelity example](../protocols/04-source-fidelity.md).

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
