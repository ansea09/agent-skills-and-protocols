# ADR 0004: FPF Skill Format Validation

Status: accepted locally, 2026-09-10; not a publication record.

## Context

The previous FPF skill used a nested `compatibility` object. Agent Skills
defines this optional field as a string of at most 500 characters. Separately,
the inspected bundled generic validator rejects the field altogether. These
are two distinct defects/limitations, not a reason to delete useful metadata.

## Decision

Use a short compatibility string and retain platform detail in README.
Validate canonical, plugin and Claude-template skills with the official
`skills-ref` reference implementation pinned to a commit, in an isolated
development environment. Pin its runtime dependencies and verify installed
versions/provenance before use. Require the format lane for FPF releases;
keep ordinary repository structural checks lightweight. Do not change system
skill tooling or add Python dependencies to the refresh runtime.

## Consequences And Limits

Negative fixtures cover nested compatibility, excessive length and unknown
frontmatter fields; a valid string is a positive control. Existing protocol,
plugin, runtime and behavioral checks remain separate. Reference tooling is
explicitly a demonstration library: a pass does not establish exhaustive
conformance, security, Windows runtime support or source-fidelity improvement.
Build backends/platform artifacts are not fully locked. No validator version
can be guaranteed current for the next 6-12 months; update pins deliberately
when specification changes warrant it and rerun the fixtures.

## Sources And Verification

- [Agent Skills specification](https://agentskills.io/specification): field contract.
- [Pinned skills-ref source](https://github.com/agentskills/agentskills/tree/69ef37e9424c0a7ea9dd2293b559e43ec8176379/skills-ref): implementation and demonstration-library limit.
- [Validation instructions](../validation.md): required commands and evidence boundaries.

Personal checkout selection and documentation baseline approval are local
maintenance infrastructure, not part of the public skill runtime contract.
