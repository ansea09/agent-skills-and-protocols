# Viewpoint Bundle

## Purpose

This bundle keeps the assistant-user interaction process readable from several viewpoints without collapsing their objects or responsibilities.

## Viewpoints

| Viewpoint | Focus | Primary questions | Key objects |
| --- | --- | --- | --- |
| OpenAI authority viewpoint | Instruction hierarchy and authority | Which instructions outrank which? Which content is trusted as instruction? | root, system, developer, user, guideline, message ownership, authority |
| OpenAI interface viewpoint | API and product input structure | How are messages, content, files, tools, and state represented? | input, message, content, tool call, tool output, conversation state |
| Codex runtime viewpoint | Agentic coding environment | What can Codex do in a workspace, and what side effects require care? | workspace, files, shell, tools, approvals, GitHub, browser |
| Developer/application viewpoint | Product or application behavior | What rules, tool schemas, and business logic are supplied by the developer layer? | developer instructions, tool definitions, prompts, application state |
| User viewpoint | User goal and interaction experience | What does the user ask for, provide, correct, or constrain? | user message, attachments, references, preferences, requested output |
| Protocol maintainer viewpoint | FPF-backed routing and execution | How does Codex extract requests, normalize tasks, route protocols, and audit evidence? | Request, Task, RoutedTask, Protocol, checklist, SOP |
| Evidence viewpoint | Source support and temporal adequacy | Which claims are source-backed? Which sources may go stale? | Model Spec, API docs, FPF spec, protocol commit, evidence register |

## Reconciliation Rule

Do not merge viewpoint-specific terms into one global meaning. Map them through explicit relations. For example:

- OpenAI `message.role` maps to protocol-local `message ownership/source`, not to an enacted role by a system.
- OpenAI `input` maps to model-facing input structure, not directly to protocol-local `Request`.
- A user-visible chat maps imperfectly to model-visible conversation state.
- Tool output is evidence or data for later reasoning, not a developer or user instruction by default.
