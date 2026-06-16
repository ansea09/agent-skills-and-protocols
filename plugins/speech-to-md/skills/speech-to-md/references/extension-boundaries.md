# Extension Boundaries

This reference defines when `speech-to-md` may grow inside the current core
runtime and when it needs a separate workflow or runtime lane.

## Current Boundary

The core bundle contract is stable:

- `content.md` is the clean transcript for ordinary reading.
- `segments.md` and `segments.json` are timestamp evidence.
- `manifest.json` records source, engine, model, command, runtime fingerprint,
  preprocessing, and warnings.
- `audit.md` records unsupported features and trust limits.

The CLI now has an explicit ASR engine adapter boundary. A local engine may be
added to the registry when it can produce the same bundle contract without
changing the trust model.

## Who Benefits

This update is mainly for users and maintainers who expect the skill to grow
beyond one local `whisper.cpp` path:

- personal users who want dependable Markdown bundles from lectures,
  interviews, meetings, podcasts, or voice notes;
- maintainers deciding whether a new ASR engine belongs in local core or in a
  separate workflow;
- reviewers checking whether the skill honestly reports unsupported features;
- LLM agents that need to know when to read only `content.md` and when to
  inspect `segments.json`, `manifest.json`, and `audit.md`;
- teams that may later need privacy-reviewed cloud transcription without
  weakening the trusted-local default.

## When This Boundary Matters

For short trusted recordings and existing transcript imports, users should not
notice a workflow change. The same commands still produce the same bundle
shape.

The boundary matters when a request crosses one of these lines:

- the user wants to compare local ASR engines;
- the recording is long enough that chunking and stitch evidence matter;
- speaker labels are needed for meeting/interview analysis;
- exact quotes or timestamps may be used as evidence;
- a cloud provider is proposed for quality, speed, language coverage, or
  diarization;
- a public plugin release must prove what is supported and what is not.

The boundary does not improve recognition accuracy by itself. It improves the
architecture around recognition so quality, privacy, and evidence features can
be added deliberately.

## Refactoring Thresholds

| Change | Allowed in core? | Required boundary before implementation |
| --- | --- | --- |
| Second local ASR engine | Yes, if local and trusted-file only. | Add a new engine adapter with its own doctor checks, runtime fingerprint, parser, regression fixture, and manifest metadata. |
| Diarization | Not as a hidden flag on the current path. | Add an explicit speaker-evidence contract, probably `speakers.json`, audit wording, confidence/nullability rules, and regression fixtures. |
| Long-recording chunking | Yes, if deterministic and local. | Add a chunk manifest with source offsets, overlap policy, stitch policy, per-chunk errors, and final transcript ordering evidence. |
| Cloud transcription | No, not in local core. | Add a separate workflow/runtime lane with credential doctor, privacy/cost warning, no default remote upload, and separate release gate. |
| Speaker identity | No. | Requires explicit user-provided identity evidence and a separate privacy/reliability review. Diarization is not identity. |
| Meeting minutes | No. | Keep as downstream summarization over an existing bundle, not part of transcription. |

## Engine Adapter Contract

Each ASR adapter must:

- accept only trusted local input unless it is in a separate cloud workflow;
- return clean content, segment records, engine metadata, warnings, and optional
  VTT path through the common engine result boundary;
- record runtime fingerprints sufficient to reproduce the run at a practical
  level;
- keep temporary preprocessing artifacts out of the final bundle unless the
  user explicitly requests retained intermediate files;
- fail loudly when required binaries, models, credentials, or output files are
  missing;
- add focused regression coverage before being advertised in `SKILL.md`.

## Diarization Contract

Diarization must not be represented as ordinary text decoration only. Before
claiming diarization support, the workflow must add machine-readable evidence:

- speaker labels with nullable confidence or explicit `unknown` values;
- time ranges aligned to transcript segments or a documented alignment method;
- audit notes that speaker labels are clustering labels, not real identities;
- a clear distinction between diarization, speaker attribution, and speaker
  identity.

## Chunking Contract

Long-recording support must preserve ordering and loss evidence. A chunked run
must record:

- source duration or best available duration probe;
- chunk size, overlap, and split method;
- input checksum and per-chunk checksums when chunks are materialized;
- per-chunk ASR command/status;
- stitch policy and any dropped, duplicated, or uncertain boundary text.

Chunking is a reliability feature only when the audit makes failures visible.

## Cloud Workflow Contract

Cloud transcription changes the trust model. It must not be added as a default
engine choice in the local core. A cloud workflow needs:

- explicit user approval before any upload;
- credential and endpoint doctor checks;
- cost, privacy, retention, and jurisdiction warnings;
- source redaction or data-classification guidance when relevant;
- a separate release gate and docs section;
- manifest metadata that records provider, model, request mode, and response
  identifiers without leaking secrets.

## Practical Rule

If a change only swaps local ASR mechanics while preserving trusted local input
and the existing bundle contract, implement it as an engine adapter. If it
changes evidence semantics, privacy boundaries, or transcript structure, create
an explicit workflow boundary before adding user-facing support.
