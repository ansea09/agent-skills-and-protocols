---
name: doc-to-md
description: Public core for converting trusted local documents and data files to Markdown using the installed Microsoft MarkItDown wrapper, with reusable workflow profiles for standard local documents and textbook-like PDF audit/OCR. Use when Codex is asked to convert, extract, ingest, normalize, or preview content from local PDF, Word, Excel, PowerPoint, EPUB, HTML, CSV, JSON, XML, ZIP, or similar files as Markdown; when the user mentions MarkItDown; when converting textbook-like PDFs with images or links; when OCR may be needed; or when a clean Markdown intermediate is useful before analysis.
compatibility:
  primary_runtime: "Codex on macOS arm64"
  supported_runtimes:
    - "Codex on Intel macOS"
  candidate_runtimes:
    - "WSL on Windows"
  experimental_runtimes:
    - "Claude Code on macOS when DOC_TO_MD_SKILL_DIR, DOC_TO_MD_BIN_DIR, and DOC_TO_MD_TOOLS_DIR are configured by install.sh or environment"
  unsupported_runtimes:
    - "native Windows PowerShell/CMD"
  required_commands:
    - "bash"
    - "python3"
    - "perl"
    - "standard Unix utilities"
  optional_commands:
    - "tesseract for OCR"
    - "Ghostscript or pypdfium2-backed OCRmyPDF rasterization path"
  runtime_requirement: "Run scripts/install.sh to build local runtimes; optional book/OCR runtimes are explicit."
  python_profile_policy: "Hash-locked support is exact by OS, architecture, and Python minor version; unlisted Python minors are candidate until validated."
  hash_profiles:
    - "macos-arm64-py313: core, book, OCR"
    - "macos-intel-py312: core, book"
  trust_boundary: "Trusted local files by default; hosted untrusted ingestion requires extra sandboxing."
  canonical_reference: "references/support-matrix.md"
---

# Doc To Md

## Document Roles

This `SKILL.md` is the executable routing contract for the agent. Keep it short
enough to run common conversions without extra reading. Detailed workflow rules
belong in reference files and should be treated as the canonical sources.

Canonical detail sources:

- `references/workflow-profiles.md` - route selection for standard documents,
  textbook audit bundles, and OCR escalation.
- `references/diagnostics.md` - diagnostic triggers, wording, and examples.
- `references/scenario-boundaries.md` - scenario classes that work well, require
  caveats, or are unsupported.
- `references/audit-bundle.md` - audit bundle output contract and quality
  interpretation.
- `references/ocr-paths.md` - OCRmyPDF/Tesseract path, doctor checks, and OCR
  limits.
- `references/support-matrix.md` - supported runtimes, portability, and platform
  boundaries.
- `references/python-profiles.md` - Python minor-version profile policy,
  support levels, and profile promotion procedure.
- `references/lock-refresh.md` - maintainer-only dependency drift and lock
  refresh workflow.
- `references/maintenance-monitor.md` - weekly MarkItDown upstream maintenance
  signal, status file, thread notification, and approval boundary.
- `references/markitdown-upgrade.md` - intentional MarkItDown converter upgrade
  lane and review checks.
- `references/release-notes.md` - user-visible release changes, upgrade notes,
  and promotion boundaries.
- `references/threat-model.md` - trusted-local threat model and hosted-ingestion
  boundary.
- `references/publishing.md` - public release, licensing, and transfer checks.
- `schemas/*.schema.json` - machine-readable doctor output contracts for
  release gates and plugin validation.

When changing a workflow, update the canonical reference first and keep this file
as a compact routing summary. Do not duplicate long checklists here.

## Operating Contract

This skill is the portable public core. Keep only publishable commands, wrappers, requirement files, guardrails, output contracts, and reusable workflow profiles here. Do not add local file paths, private sample documents, personal aliases, machine-specific assumptions, or experimental workflows to this public core.

Personal local preferences belong outside this skill, for example in a private repository policy file. The public core must not depend on private-only files, paths, fixtures, or commands.

Current support contract: Codex on macOS arm64 is supported for core, book, and OCR workflows with the `macos-arm64-py313` hash profile. Codex on Intel macOS is supported for core and book workflows with Python 3.12 and the `macos-intel-py312` hash profile; OCR hash-locked support is not published for Intel macOS. Python minor versions are not interchangeable for `--hash-locked`: unlisted profiles such as `macos-arm64-py312`, `macos-arm64-py314`, or `macos-intel-py313` are candidate/unverified until validated and listed in `references/python-profiles.md`. WSL is a candidate; Claude Code on macOS is experimental unless the installed wrappers know the skill source path and runtime paths through `DOC_TO_MD_SKILL_DIR`, `DOC_TO_MD_BIN_DIR`, and `DOC_TO_MD_TOOLS_DIR`; native Windows PowerShell/CMD is unsupported. Read `references/support-matrix.md` before installing outside these maintained Codex/macOS paths.

Use the local wrapper `markitdown-local`, which runs the pinned core MarkItDown venv at `${DOC_TO_MD_TOOLS_DIR:-${CODEX_HOME:-$HOME/.codex}/tools}/markitdown-core-venv`. The short command `mdown` is a symlink to the same wrapper. Prefer local-file conversion with `-o/--output` so the wrapper can protect the previous output from normal process failures, then perform focused verification.

Core scope is intentionally narrow: local PDF, DOCX, PPTX, XLS, XLSX, simple EPUB, HTML, CSV, JSON, XML, text-like files, and ZIP extraction. Audio, YouTube, Azure, OCR plugins, and LLM-backed image description are advanced modes and are not part of the default runtime.

For textbook-like local PDFs where page traceability, embedded raster images, link records, and quality warnings matter, use the separate PDF audit bundle wrapper `mdown-book`. It runs from `${DOC_TO_MD_TOOLS_DIR:-${CODEX_HOME:-$HOME/.codex}/tools}/doc-to-md-book-venv`, calls the pinned core wrapper first, and keeps PyMuPDF out of the core runtime. This is not inline placement or high-fidelity PDF reconstruction.

For scanned PDFs, use the optional OCR preprocessor `mdown-ocrpdf` first. It runs from `${DOC_TO_MD_TOOLS_DIR:-${CODEX_HOME:-$HOME/.codex}/tools}/doc-to-md-ocr-venv`, keeps OCRmyPDF out of the core runtime, and writes a searchable OCR PDF before the audit bundle step.

## Route Selection

Choose the route before running commands. If the case is ambiguous, read
`references/workflow-profiles.md` and `references/scenario-boundaries.md`.

| Situation | Default action | Canonical detail |
| --- | --- | --- |
| Trusted local DOCX, PPTX, XLS/XLSX, simple EPUB, HTML, CSV, JSON, XML, text-like file, ZIP, or born-digital PDF | `mdown input-file -o output-file.md` | `references/workflow-profiles.md` |
| Textbook-like PDF, image-heavy PDF, link-sensitive PDF, formula/table-heavy PDF, or uncertain PDF quality | `mdown-book source.pdf -o source-audit-bundle` | `references/audit-bundle.md` |
| Scanned or low-text PDF after audit evidence, or explicit trusted OCR request | `mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf`, then rerun `mdown-book` | `references/ocr-paths.md` |
| Audit/OCR evidence prepared for external transfer | Export sanitized reports or bundles before sharing | `references/publishing.md` |

## Workflow

1. Identify the source file and intended output. If the user gives no output path, write next to the input with a `.md` extension or into a task-specific output folder such as `markitdown-output/`.
2. Confirm the file exists and note its type and size with `file`, `du -h`, or a similarly cheap check.
3. Run with `-o` or `--output`:

```bash
mdown input-file -o output-file.md
```

Use the installed wrapper path if PATH is unavailable:

```bash
"${HOME}/.local/bin/markitdown-local" input-file -o output-file.md
```

4. Verify the output with `wc -l`, `du -h`, and `sed -n '1,80p' output-file.md`. Treat an empty or tiny output as a conversion failure unless the input genuinely has no extractable content.
5. For questionable results, run `mdown-doctor --output output-file.md`.
6. Report the output path, the command shape used, and any warnings or limitations that affect trust in the result.

The supported output path is `-o/--output`. The core wrapper writes through a temporary file only when it controls the output path through `-o/--output`; this protects the previous output from normal process failures but is not a crash/power-loss or multi-writer guarantee. Shell redirection such as `mdown input > output.md` is not a supported write path for this skill because the shell opens and truncates the destination before the wrapper runs. Stdout mode is only for inspection or explicit piping where truncation risk is acceptable. The default core guardrails are `MARKITDOWN_TIMEOUT_SECONDS=600` and `MARKITDOWN_MAX_INPUT_MB=512`; these are timeout and input-size limits only, not memory, temporary-storage, page-count, or ZIP-expansion limits. Raise or disable them only for trusted large conversions.

The core selftest covers HTML, PDF, DOCX, XLS, XLSX, PPTX, EPUB, CSV, JSON, XML, ZIP, protected `-o` failure behavior, and stdout warnings. It is a smoke test for the runtime profile, not a quality benchmark for every possible document.

## PDF Audit Bundle

Use this for trusted local textbook-like PDFs. It creates a source-tethered bundle instead of promising high-fidelity PDF layout reproduction.

```bash
mdown-book source.pdf -o source-audit-bundle
```

Expected top-level outputs are `content.md`, `audit.md`, `assets/`,
`manifest.json`, and `conversion-report.md`. The generated audit is a separate
file, not inline image/link placement in the textbook flow. Run
`mdown-book --doctor` before relying on this workflow. Read
`references/audit-bundle.md` for the canonical output contract and quality
interpretation.

`mdown-book` uses a same-output lock to reject parallel writes to one bundle. The default book guardrails are `--timeout 600` for the MarkItDown phase and `--max-input-mb 1024`; these are timeout and input-size limits only. Raise or disable them only for trusted large PDFs.

Audit reports include local source paths and command evidence by default. Before transferring an audit bundle outside the local trusted environment, export a sanitized copy:

```bash
mdown-book --export-sanitized source-audit-bundle -o source-audit-bundle-public
```

For a new bundle that should redact local paths immediately, pass `--sanitize-report`.

If OCR is requested for scanned pages, image-only text, formulas, or embedded images, first read `references/ocr-paths.md` and keep OCR in an explicit advanced runtime.

## OCR Preprocessor

Use this only for trusted local scanned PDFs or low-text PDFs after `mdown-book` reports OCR is needed.

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-audit-bundle
```

Use `-l eng+rus` or another Tesseract language string only when it matches the document and the language packs are installed. `mdown-ocrpdf` writes through a temporary staging path and uses a same-output lock. Run `mdown-ocrpdf --doctor` before relying on OCR.

OCR JSON reports include local paths and command evidence by default. Use `--sanitize-report` when generating a report for external transfer, or sanitize an existing report:

```bash
mdown-ocrpdf --export-sanitized-report scanned-ocr.pdf.ocr-report.json --report scanned-ocr.public-report.json
```

Read `references/ocr-paths.md` before changing OCR defaults, language choices,
or dependency requirements.

## Guardrails

- The wrapper blocks URI arguments by default. Use `--allow-remote` only after the user explicitly requests a trusted remote conversion.
- The wrapper blocks plugin/cloud options by default: `--use-plugins`, Document Intelligence, Content Understanding, and related endpoint flags. Use `--allow-advanced` only after the user explicitly requests that mode and the needed dependencies/credentials are intentionally installed.
- Do not pass untrusted user-controlled paths or URLs directly to MarkItDown in hosted/server-like contexts. MarkItDown reads resources with the current process privileges.
- For hosted or shared environments, set `MARKITDOWN_INPUT_ROOTS`, `MARKITDOWN_OUTPUT_ROOTS`, `DOC_TO_MD_INPUT_ROOTS`, and `DOC_TO_MD_OUTPUT_ROOTS` to colon-separated allowed directories before accepting user-selected paths. These are guardrails, not a sandbox.
- Before any hosted, shared, or untrusted ingestion use, read `references/threat-model.md` and add separate OS/container sandboxing. This skill is trusted-local by default.
- Image conversion without EXIF or a configured LLM client may produce empty Markdown. The default core wrapper has no LLM client configured.
- The PDF audit bundle does not run OCR by default and does not perform inline image/link placement. Low-text pages, scanned pages, formula-heavy pages, and image-only diagrams require explicit OCR or manual review.
- The OCR preprocessor follows OCRmyPDF v17 requirements: `tesseract >= 4.1.1` is required; PDF rasterization needs Python `pypdfium2` or `Ghostscript >= 9.54`; `qpdf` CLI is not a hard requirement because OCRmyPDF uses `pikepdf`. Run `mdown-ocrpdf --doctor` for the exact local gap.
- `mdown-doctor`, `mdown-book --doctor`, and `mdown-ocrpdf --doctor` check installed versions against their pinned requirements. The OCR lockfile pins Python packages; external Tesseract is checked by doctor but is not rebuilt from that lockfile.
- Audio, YouTube transcription, Azure conversion, and OCR plugins are excluded from the default core venv. Do not assume they work until deliberately installed and checked.
- Keep generated Markdown separate from source files unless the user asks to overwrite or place files elsewhere.
- Sanitize audit bundles and OCR reports before transferring generated evidence outside the local trusted environment.

## User-Facing Diagnostics

Show a diagnostic when the conversion state changes what the user can trust, decide, or do next. Do not show a diagnostic for routine successful conversion; summarize ordinary output paths and checks in the final report.

Use this shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Canonical diagnostic triggers and examples live in `references/diagnostics.md`.
Common trigger classes are runtime availability, doctor failure, input boundary,
guardrail block, output trust problem, audit/OCR uncertainty, write-safety
issue, platform/publication boundary, and external-transfer boundary.

## Useful Checks

```bash
mdown --version
mdown-doctor
mdown-doctor --json
mdown-doctor --output output-file.md
mdown-book --doctor
mdown-book --doctor --json
mdown-ocrpdf --doctor
mdown-ocrpdf --doctor --json
mdown-ocrpdf --doctor --online
mdown-refresh-locks --core-pdf --core-filetype --ocr
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION'
mdown-markitdown-monitor --json
mdown-markitdown-monitor --json --no-write
mdown-prepare-markitdown-upgrade --json
mdown-dependency-monitor --json
mdown-dependency-audit --help
mdown-markitdown-monitor --record-decision approved
mdown-markitdown-monitor --record-decision declined
python3 scripts/regression_corpus.py
python3 scripts/audit_bundle_regression.py
markitdown-local --version
markitdown-local --help
mdown source.pdf -o source.md
mdown-book source.pdf -o source-audit-bundle
mdown-book --export-sanitized source-audit-bundle -o source-audit-bundle-public
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-ocrpdf --export-sanitized-report scanned-ocr.pdf.ocr-report.json --report scanned-ocr.public-report.json
wc -l source.md
sed -n '1,80p' source.md
```

## Installation And Rebuild

For a fresh Codex/macOS installation, run the installer from the skill directory.
The default installs only the core runtime and wrappers:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh"
```

Install optional workflows explicitly:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --book
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --ocr
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --all
```

For Claude Code, install the skill source into `~/.claude/skills/doc-to-md` or
`.claude/skills/doc-to-md`, then run the installer from that source directory.
The installer writes command shims that pin `DOC_TO_MD_SKILL_DIR` to that
source path. Configure `DOC_TO_MD_TOOLS_DIR` when the default `.codex/tools`
compatibility location is not desired:

```bash
export DOC_TO_MD_SKILL_DIR="$HOME/.claude/skills/doc-to-md"
export DOC_TO_MD_BIN_DIR="${DOC_TO_MD_BIN_DIR:-$HOME/.local/bin}"
export DOC_TO_MD_TOOLS_DIR="${DOC_TO_MD_TOOLS_DIR:-$HOME/.codex/tools}"
bash "$DOC_TO_MD_SKILL_DIR/scripts/install.sh"
```

For public release on maintained hash profiles, use hash-locked installs.
macOS arm64 / Python 3.13 supports core, book, and OCR:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --hash-locked
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --book --hash-locked
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --ocr --hash-locked
```

Supported macOS arm64 happy path with all maintained workflows and JSON
doctors:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --all --hash-locked && mdown-doctor --json && mdown-book --doctor --json && mdown-ocrpdf --doctor --json
```

Intel macOS / Python 3.12 supports core and book:

```bash
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --hash-locked
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --book --hash-locked
```

Do not use `--ocr --hash-locked` on Intel macOS unless a reviewed
`requirements-ocr.macos-intel-*.hashes.txt` profile has been published.
Native Windows PowerShell/CMD is unsupported. WSL is a candidate path. Hash
files are platform-specific, and another platform needs its own reviewed
`requirements-*.hashes.txt` profile. Unlisted Python minor versions are not
supported hash-locked profiles. Read `README.md`,
`references/support-matrix.md`, `references/lock-refresh.md`,
`references/python-profiles.md`,
`references/scenario-boundaries.md`, `references/local-policy-migration.md`,
`references/threat-model.md`, `references/markitdown-upgrade.md`,
`references/publishing.md`, and `THIRD_PARTY_NOTICES.md` before migration,
lock refresh, converter upgrade, or redistribution.
