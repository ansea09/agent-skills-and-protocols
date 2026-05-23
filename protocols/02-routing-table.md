# Routing Table

Protocol selection applies to the normalized task.

| Task shape | Protocol | Required notes |
| --- | --- | --- |
| Direct explanation, stable concept, no external evidence needed | simple-medium | Bound context and avoid invented detail. |
| Clarification of an ambiguous term | simple-medium or complex | Use complex if ambiguity affects decisions, sources, code, or high-stakes use. |
| Small local code edit | simple-medium | Verify with focused tests or explain why not run. |
| Multi-file or architecture code change | complex | Include scope, affected systems, tests, and residual risk. |
| Source-backed research | complex | Use source-selection and evidence checklist. |
| Current/latest facts | complex | Verify freshness and state date/version. |
| Legal, medical, financial, safety, security | complex | Use authoritative sources and avoid overclaiming. |
| GitHub PR/issue/repository mutation | complex | Treat external publication as actual work with evidence and rollback awareness. |
| New automation, recurring task, agent delegation | complex | Include work boundary, trigger, evidence, and fallback. |
| Creative brainstorming | simple-medium | Use complex if selection, evaluation, or publication is required. |
| User asks for "just answer" but the task is high-risk | complex | Do not let style preference remove safety or evidence obligations. |

## OpenAI Guideline Handling

Never ignore system, developer, safety, tool, platform, data-protection, copyright, or legal compliance instructions.

The FPF protocol may override only lower-priority generic style defaults when they conflict with this user's standing request. Examples:

- Prefer FPF-backed structure over a generic unstructured answer.
- Prefer explicit uncertainty over confident simplification.
- Prefer evidence and scope notes over brevity when the task is source-sensitive.
- Prefer Russian when the user writes in Russian, unless the task artifact is intended for Codex/agents and English is more operationally reliable.
- Avoid hiding protocol warnings merely to make the answer smoother.

If an FPF protocol instruction appears to conflict with higher-priority OpenAI or tool instructions, follow the higher-priority instruction and disclose the limitation when relevant.

## Routing Completion

Every routed task must record:

- selected protocol
- reason for selection
- FPF spec commit
- protocol repository commit
- cache warnings, if any
