# Definitions

Use these distinctions before selecting a protocol.

## Message, Request, Question, Task

| Term | Meaning | Routing relevance |
| --- | --- | --- |
| User message | The actual message sent by the user. It can contain questions, commands, files, constraints, corrections, and emotional or social signals. | Do not route from surface wording alone. |
| Request | A work-demand extracted from the user message. One message may contain multiple requests. | Route each independent request if they differ materially. |
| Question | A request whose main expected output is an answer or explanation. | Use answer protocols unless the question also asks for code, research, publication, or external action. |
| Task | The normalized unit of work Codex will perform after reading the message, constraints, files, tools, and context. | Protocol selection is made on the task. |
| Subtask | A separable part of a task with its own risk, evidence, or work surface. | Independent tasks may have different profiles; do not split merely to evade a necessary check. |
| Substantive task | A task where the answer or action depends on reasoning, code/files, sources, FPF patterns, protocols, architecture, review, planning, or other checkable work beyond a short social or control response. | Run the FPF context refresh gate before performing the work. |
| Non-substantive interaction | A user turn that only acknowledges, pauses, cancels, thanks, or asks for a trivial response that does not depend on FPF, files, tools, sources, or reasoning state. | Do not run the FPF refresh gate solely for this interaction. |
| Task admission | The agent-side decision that a normalized request will be handled as a task. | A substantive task starts at admission, not merely when the raw user message is received. |
| Protocol | A description of the response/work method, with a selected checklist and supporting rules. | Exactly one baseline per independent task: `simple-medium` or `complex`; same six steps, different depth. |
| Material difference | A difference that can change a conclusion, admissible use, criterion, action or significant consequence. | Determines depth and the need to reopen a check. |
| Check execution | Whether a required checking action was performed. | Distinct from a satisfied, violated or unknown check outcome. |
| Source-condition attribution | Claiming that a source supports a condition or implication in the answer. | Apply the conditional source-fidelity check; do not import another source's conditions. |

## Boundary Rule

Classify the normalized task, not only the raw user message. A short user message can define a complex task, and a long user message can still ask for a simple answer.

## Substantive Task Rule

Treat a task as substantive when it asks Codex to explain, design, critique, model, review, plan, research, write code, edit files, inspect local state, operate on GitHub, create automation, use a skill, use FPF, or make a decision whose correctness depends on evidence or current context.

A user message only creates a candidate request. The substantive task starts when Codex admits that request as work to be performed. That admission happens after minimal intake and before reasoning, file reads, code edits, tool work, or the final answer.

Do not treat the following as substantive by themselves:

- "ok", "thanks", or a similar acknowledgement;
- "stop", "wait", "pause", or a cancellation/control turn;
- a purely conversational reply with no requested work;
- a trivial answer that does not depend on FPF, files, tools, sources, or reasoning state.

## Examples

- "Explain X" is usually simple-medium unless impact, material ambiguity or evidential conflict requires deeper checking; reading one current source does not itself force complex.
- "Fix this PR and publish it" is a complex task because it includes code changes, verification, GitHub publication, and possible CI risk.
- "Is this medical treatment safe?" is complex even if short because the domain is high-stakes and source-sensitive.
- "Stop" is not substantive because it is a control turn.
- "Use FPF to review this architecture" is substantive because it explicitly requires FPF-backed reasoning.

Task admission is not application startup, waking the laptop or a time-based
session boundary. Shared selection, reuse and completion rules are defined in
[03-pattern-use.md](03-pattern-use.md).
