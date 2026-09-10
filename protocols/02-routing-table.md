# Routing Table

Read classification, then select exactly one baseline per independent task.
Both profiles use the same six steps; they differ in evidence depth.

| Task condition | Profile | Relevant route |
| --- | --- | --- |
| Bounded explanation, sufficient evidence, low impact | simple-medium | Only applicable shared routes |
| One current source closes a low-risk question | simple-medium | R05/R07; verify required freshness |
| Small reversible local edit with focused checks | simple-medium | R03/R05; verify the actual change |
| Material ambiguity, conflicting sources or competing criteria | complex | R04/R05/R10/R15 as needed |
| Architecture, protocol design or multi-component change | complex | Actual concerns through R11; not every viewpoint |
| Significant external action, publication or automation | complex | R03/R10; R12 only for a real gate |
| High-impact decision, even if a brief answer is requested | complex | Domain checks and actual evidence requirements |
| A changed source invalidates part of a previous answer | Preserve or escalate as needed | R14; recheck affected dependencies |
| Sources are being combined, paraphrased or mapped into statuses | Chosen by materiality | R05/R13/R15 and source-fidelity check |

Route definitions and conditions: [03-pattern-use.md](03-pattern-use.md).
Conditional source check and monitoring: [04-source-fidelity.md](04-source-fidelity.md).

Record the selected profile, reason, actual protocol revision/source, FPF
version and material limits. A configured local source, when explicitly
authorized, is not the gate's GitHub cache: disclose both separately.

The protocol cannot override higher-priority instructions, source trust,
permissions or domain obligations. An explanation of an action is not a request
to execute it.
