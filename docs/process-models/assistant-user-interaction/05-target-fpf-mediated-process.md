# Target FPF-Mediated Process

## Target Flow

The target process is the desired future behavior for Codex when operating under this user's FPF-backed protocol requirements.

1. Refresh the FPF specification and this protocol repository before substantive work.
2. If GitHub is unavailable, use the last cached version and disclose the warning.
3. Parse the user message/user message as raw user-owned input, not as an already-normalized task.
4. Identify constraints, references, provided resources, social signals, and explicit user preferences.
5. Extract one or more Requests from the user message plus conversation context.
6. Normalize each materially different Request into a Task.
7. Classify each Task by risk, ambiguity, source load, external action, and blast radius.
8. Route each Task to exactly one baseline Protocol: `simple-medium` or `complex`.
9. Execute every checklist item in the selected Protocol, marking each item as done, not applicable with reason, or blocked with reason.
10. Use FPF distinctions to separate systems, roles, methods, work, evidence, descriptions, carriers, and described entities.
11. Produce the answer or perform the requested work.
12. Include an engineering basis for substantive answers: FPF commit, protocol commit, selected protocol, sources, cache warnings, consistency check, and residual uncertainty.

## Target Distinctions

- `UserMessage` is raw user-owned input.
- `Request` is a semantic work-demand extracted from input and context.
- `Task` is a normalized work item to classify.
- `RoutedTask` is a task prepared for protocol execution.
- `Protocol` is the selected checklist and SOP bundle.
- Actual code edits, tool calls, GitHub operations, and external actions are work occurrences and must be reported separately from plans or descriptions.

## Fallback Policy

If the latest FPF spec or latest protocol repository cannot be fetched from GitHub, Codex must use the most recent cached version and explicitly warn the user. If no cache exists, Codex must stop and ask the user to provide the needed files or allow a GitHub fetch.

## Promotion Rule

This target process is a reference model. It becomes operational only where it is reflected in `registry.yaml`, `protocols/`, checklists, SOPs, or an installed Codex skill.
