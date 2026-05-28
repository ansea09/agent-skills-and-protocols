# Threat Model

This skill is for trusted local document conversion. It is not a sandboxed
document-ingestion service.

## Intended Use

- A local operator converts documents they are allowed to open on the same
  machine.
- Input files are trusted enough to be processed by local Python libraries,
  PDF parsers, Office parsers, OCR tools, and temporary-file handling.
- Generated Markdown, audit bundles, OCR PDFs, reports, and extracted assets
  stay local unless explicitly sanitized and reviewed before transfer.

## Out Of Scope

- Hosted, shared, multi-tenant, or server-side ingestion of untrusted documents.
- Untrusted URLs or remote fetches without an explicit operator decision.
- Sandboxing against malicious PDFs, ZIP bombs, parser exploits, excessive CPU,
  excessive memory, temporary-storage exhaustion, page-count explosions, or
  renderer vulnerabilities.
- Data-loss guarantees across power loss, filesystem corruption, or multiple
  writers targeting the same output.
- Secret scanning or content classification of generated Markdown, reports,
  extracted images, metadata, or OCR text.

## Existing Guardrails

- Remote URI arguments are blocked by default in the core wrapper.
- Advanced plugin/cloud/Azure/Content Understanding options are blocked by
  default.
- `-o/--output` writes through a temporary file before replacing the destination.
- Optional input/output root checks can constrain accepted paths:
  `MARKITDOWN_INPUT_ROOTS`, `MARKITDOWN_OUTPUT_ROOTS`,
  `DOC_TO_MD_INPUT_ROOTS`, and `DOC_TO_MD_OUTPUT_ROOTS`.
- The PDF audit and OCR workflows use same-output locks to reject concurrent
  writes to one bundle or OCR PDF.
- Audit/OCR reports can redact local absolute paths for external transfer.

These guardrails reduce common local mistakes. They do not isolate process
privileges, filesystem access, network access inside transitive dependencies,
CPU, memory, temporary storage, archive expansion, or parser attack surface.

## Hosted Or Untrusted Ingestion Requirement

Before using this skill in a hosted or shared setting, add a separate ingestion
architecture:

- OS/container sandboxing with least-privilege filesystem mounts;
- network egress restrictions;
- CPU, memory, wall-clock, temporary-storage, page-count, and archive-expansion
  limits;
- separate worker identity with no access to secrets or private home folders;
- malware/content policy controls appropriate for the environment;
- explicit retention and deletion policy for source files and generated outputs.

Without those controls, do not accept untrusted documents through this skill.
