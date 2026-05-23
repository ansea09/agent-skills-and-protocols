# Definitions

Use these distinctions before selecting a protocol.

## Message, Request, Question, Task

| Term | Meaning | Routing relevance |
| --- | --- | --- |
| User message | The actual message sent by the user. It can contain questions, commands, files, constraints, corrections, and emotional or social signals. | Do not route from surface wording alone. |
| Request | A work-demand extracted from the user message. One message may contain multiple requests. | Route each independent request if they differ materially. |
| Question | A request whose main expected output is an answer or explanation. | Use answer protocols unless the question also asks for code, research, publication, or external action. |
| Task | The normalized unit of work Codex will perform after reading the message, constraints, files, tools, and context. | Protocol selection is made on the task. |
| Subtask | A separable part of a task with its own risk, evidence, or work surface. | Complex tasks may split into subtasks but still use the complex protocol. |
| Protocol | The mandatory checklist and SOP selected for a task. | Exactly one baseline protocol is selected: `simple-medium` or `complex`. |

## Boundary Rule

Classify the normalized task, not only the raw user message. A short user message can define a complex task, and a long user message can still ask for a simple answer.

## Examples

- "Explain X" is usually a simple-medium question unless X is high-stakes, current, source-dependent, or ambiguous enough to require multi-view analysis.
- "Fix this PR and publish it" is a complex task because it includes code changes, verification, GitHub publication, and possible CI risk.
- "Is this medical treatment safe?" is complex even if short because the domain is high-stakes and source-sensitive.
