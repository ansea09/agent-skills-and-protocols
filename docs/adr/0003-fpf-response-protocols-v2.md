# ADR 0003: Proportional FPF Protocols And Source Fidelity

Status: Accepted for implementation; publication and evaluation evidence are separate.
Date: 2026-09-10.
Extends: [ADR 0001](0001-fpf-work-guide-architecture.md), protocol instruction layer.

## Context

The former simple/complex checklists repeated broad mandatory pattern lists
and reporting requirements. Updated FPF bodies require more precise selection,
source-local meanings, fit/use checks and separation of performed work from
its description. A pilot also exposed ambiguous transfer of a condition from
one source definition to another. We need a useful control without turning
every answer into a formal audit or claiming that more instructions ensure
correctness.

## Decision

- Keep one six-stage method with simple-medium and complex depth profiles.
  Material risk/uncertainty, not source count alone, controls escalation.
- Use `protocols/03-pattern-use.md` for shared rules and 17 conditional routes.
  Read relevant pattern bodies; obtain actual prerequisite results. Do not
  recursively load whole clusters or use pattern IDs as evidence of execution.
- Separate execution status from check outcome. Keep useful partial results
  while identifying exactly which dependent work is blocked.
- Use compact engineering basis by default, detailed trace when requested or
  needed for receiving use. Material caveats belong beside the output claim.
- Apply source-fidelity checks to material paraphrase, synthesis and condition
  mapping. Check implications in both directions, preserve version/scope,
  negation/modality and unknowns. An explicit source implication remains valid.
- Retain SC-01 as open-monitoring. Minimal observations may be appended only to
  a configured authorized non-public destination. No scheduler, cross-chat
  access, automated semantic detector or all-clear claim is introduced.
- Canonical skill, plugin mirror and Claude-native routing require protocol
  revision 2.0. Publish them with the protocol files as a compatible batch.
  Detect an older/incomplete protocol source rather than silently mixing it.
- Allow a user-authorized read-only local protocol source through optional
  agent-read JSON settings, independent of the updater's cache. Record local
  revision and modified content separately from gate/cache provenance. The
  default remains the trusted GitHub cache; TTL, refresh scripts and hooks do
  not change. Revert to the cache only after verifying compatible publication.

## Alternatives And Limits

Always running all patterns would add cost and irrelevant formalism. A word
blacklist would reject legitimate entailment and miss paraphrased errors. A
global claim database, background model evaluator or automatic public issue
writer is disproportionate to this observed problem and not authorized.
Silently editing the protocol cache would destroy provenance and be overwritten
by refresh. Duplicating protocols inside every skill would introduce another
source of truth. Local selection is explicit and temporary when used for release
testing; its configured directory must remain available until switched away.

Settings are interpreted by the agent, not enforced by the updater. Parsing,
safe path resolution, source selection and logging therefore require actual
runtime checks; documentation alone is not proof of compliance. An old cache
can pass refresh validation but still fail the agent's protocol-version check.
This coupling requires atomic publication and explicit activation verification.

## Evaluation Boundary

The accepted pilot had 17 primary answers, five repeated candidate answers and
five baseline answers. T13 needed revision in both candidate runs; the other
assessed answers passed. This is not evidence of superiority, an error-rate
estimate or a diagnosis that an FPF pattern caused the problem.

Required checks: protocol artifacts/links, existing refresh fixtures,
source/plugin equivalence, installed-vs-selected-staged drift, Claude packaging,
and actual SC-01 responses reviewed against each source condition. Regression
variants include reversed order, explicit entailment, unknown-versus-negative
and different versions. Preserve raw failures and subsequent corrections.
Local passes do not close the issue; reevaluate after material changes.

## FPF Basis

Adoption source: FPF upstream `a87d0ef4f3712507edd6e5a59f4de5bf7a55905a`,
mirror `c41807d40d72677a360db5a9601acaa0b53163e6`, current cached copy.
E.11/PUA/PUR govern application fit and useful results; A.1/A.7/A.11 and
A.15 distinguish artifacts and work; A.6.P/F.0.1/A.10/E.17.EFP support faithful
source conditions. E.22/E.23/E.13/A.11.OP govern bounded evaluation without
proxy substitution. C.28 limits causal improvement claims; C.27 limits
generalization over time. F.0.2 was Draft at adoption and is conditional, not
a mandatory route whenever two documents are read. C.7 has no usable body in
that source; C.16 with A.17/A.18/A.19 supplies distributed functions, not a
claim of complete semantic equivalence.
