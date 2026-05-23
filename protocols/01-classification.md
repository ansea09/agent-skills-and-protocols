# Task Classification

Classify every normalized task before answering or acting.

## Simple-Medium Task

Use `simple-medium` when all of these are true:

- The task has one clear objective.
- The answer can be scoped in one bounded context.
- There is no high-stakes legal, medical, financial, security, safety, employment, or public-policy consequence.
- Current external facts are not essential, or they can be verified quickly from authoritative sources.
- The task does not require multiple viewpoints to avoid a misleading answer.
- Code changes, if any, are small, local, reversible, and testable in the current workspace.
- The user does not ask for external publication, automation, agent delegation, or long-running monitoring.

## Complex Task

Use `complex` if any of these are true:

- High-stakes domain: legal, medical, financial, safety, security, infrastructure, employment, public policy, or irreversible user impact.
- Multi-source or current research is needed.
- The task has multiple stakeholders, viewpoints, systems, contexts, or conflicting goals.
- The key terms are ambiguous or overloaded and must be repaired before reasoning.
- The user asks for architecture, strategy, governance, protocol design, evaluation, or a decision framework.
- The task involves code changes across modules, data migrations, external APIs, CI, deployment, or GitHub publication.
- The task involves creating or modifying automations, agents, recurring work, or external resources.
- A wrong answer could cause significant money, time, privacy, legal, reputation, or safety harm.

## Escalation Rule

When uncertain, choose `complex` if the extra checklist cost is justified by risk, ambiguity, external evidence, or blast radius. Otherwise choose `simple-medium` and state the bounded scope.

## De-Escalation Rule

A task may be de-escalated from `complex` to `simple-medium` only when the risky or ambiguous part is explicitly out of scope and the final answer states that boundary.
