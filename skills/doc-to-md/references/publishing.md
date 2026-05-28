# Publishing Checklist

Use this checklist before publishing `doc-to-md` outside a personal Codex
installation.

## Required

- Remove machine-specific paths from examples and generated docs.
- Keep `doc-to-md` as the public core: publishable workflows, wrapper
  semantics, reusable workflow profiles, requirement files, guardrails, tests,
  and license notices only.
- Keep local configuration, private fixtures, personal OCR defaults, private
  local policy files, and machine-specific workflow notes out of the public
  release artifact.
- Preserve the dependency direction: private local policies may refer to the
  public core, but the public core and plugin artifact must not require
  private-only files, paths, fixtures, or commands.
- Keep `eng+rus` or any other language string as a source-specific OCR choice,
  not a universal public default.
- Install through `scripts/install.sh`; do not assume local venvs already exist.
- Keep `mdown input -o output.md` as the supported write path.
- Treat shell redirection (`mdown input > output.md`) as unsupported for file
  writes because it is not atomic and can truncate an existing destination.
- Publish and review the support matrix. Current contract: Codex/macOS arm64 is
  supported for core, book, and OCR; Codex/Intel macOS is supported for core
  and book on Python 3.12; Claude Code/macOS is experimental unless installer
  shims record `DOC_TO_MD_SKILL_DIR` and runtime paths are configured, WSL is a
  candidate, and native Windows PowerShell/CMD is unsupported.
- Publish and review `references/python-profiles.md`. Do not claim a Python
  minor version as supported because a different minor version passed. New
  Python minors start as candidate/unverified until their own profile evidence
  exists.
- State the trust boundary: trusted local files only by default; no hosted,
  server-side, or untrusted ingestion without additional sandboxing.
- Include `references/threat-model.md` in public review. Wrapper guardrails are
  not a sandbox and do not make hosted ingestion safe by themselves.
- Keep remote URI, plugin, Azure, YouTube, audio, and LLM-backed paths disabled
  unless a user explicitly installs and enables them.
- Include `THIRD_PARTY_NOTICES.md` and review license compatibility before
  distributing modified copies.
- Run `mdown-doctor`, `mdown-book --doctor` when book support is installed, and
  `mdown-ocrpdf --doctor` when OCR support is installed.
- For release evidence and CI, validate `mdown-doctor --json`,
  `mdown-book --doctor --json`, and `mdown-ocrpdf --doctor --json` against the
  JSON Schemas in `schemas/`. Core and book doctors must return a zero exit code
  with status `ok` or `warn`; OCR may report `fail` in source CI when external
  OCR system dependencies are intentionally absent, but the JSON contract must
  still validate.
- Before publishing, run the repository release gate:

```bash
scripts/validate-doc-to-md-release.sh
```

This source gate checks staged/plugin drift, semantic compatibility between
`SKILL.md` frontmatter and `references/support-matrix.md`, staged-wrapper
runtime behavior, synthetic regression snapshots, audit-bundle evidence, and
machine-readable doctor schemas. It uses staged requirements and staged
wrappers; set `DOC_TO_MD_CI_RUNTIME` to a reusable CI cache root if temporary
venvs are not desired.

- For release maintenance, run online drift checks and follow
  `references/lock-refresh.md` for PDF extraction, file-type detection, and OCR
  graph refreshes.
- For publication SCA, run the release gate with online dependency audit
  required:

```bash
DOC_TO_MD_SCA_MODE=required scripts/validate-doc-to-md-release.sh
```

The default release gate runs an offline license/runtime inventory and reports
that online vulnerability metadata was skipped. `DOC_TO_MD_SCA_MODE=required`
fetches package vulnerability metadata and fails closed when the advisory check
cannot be completed. Use `DOC_TO_MD_SCA_MODE=skip` only for local development,
not for public release evidence.
- Review the dependency maintenance signal before lock refreshes:

```bash
mdown-dependency-monitor --json --no-write
```

This signal is intentionally separate from MarkItDown auto-prepare. It can show
OCR/PDF drift such as a newer OCRmyPDF release without changing pins or
promoting an installed runtime.
- Run `scripts/selftest_doc_to_md.py` with the core runtime Python.
- Confirm the selftest covers the claimed core smoke formats: HTML, PDF, DOCX,
  XLS, XLSX, PPTX, CSV, JSON, XML, and ZIP.
- Before accepting a MarkItDown upgrade, run
  `scripts/regression_corpus.py` and review snapshot diffs. Accepted output
  changes must update snapshots in the same reviewed release change.
- For audit bundle behavior, run `scripts/audit_bundle_regression.py`; it uses a
  generated PDF fixture with text, an embedded image, and a URI link.
- Keep `references/diagnostics.md` aligned with wrapper behavior, doctor
  checks, audit warnings, OCR boundaries, and publication boundaries.
- Before transferring generated audit bundles or OCR reports outside the local
  trusted environment, use the sanitized export/report modes and still review
  document content, extracted assets, links, and metadata manually.
- Document local policy migration separately. Do not publish private policy
  files, copied venvs, wrapper symlinks, caches, generated outputs, OCR PDFs,
  audit bundles, or machine-specific binaries as public skill source.

## Reproducibility Boundary

The default requirement files use exact version pins. They do not include
`pip --require-hashes` hashes because they are intended for normal local
installs across compatible environments.

For stricter public redistribution, use platform-specific hash-locked
requirements or a lockfile produced by the package manager used by the project
(`uv.lock`, `pip-tools` hashes, or an equivalent mechanism). This skill
currently publishes `macos-arm64-py313` hash files for core, book, and OCR, and
`macos-intel-py312` hash files for core and book. Use
`scripts/install.sh --hash-locked` only when a matching profile exists.

Support claims are profile-specific. A normal pinned install on an unlisted
Python minor version may be useful for local testing, but it remains candidate
or unverified until `references/python-profiles.md` and
`references/support-matrix.md` list the profile with completed validation.

## Hosted Or Shared Environments

The wrappers provide path-root checks via:

- `MARKITDOWN_INPUT_ROOTS`
- `MARKITDOWN_OUTPUT_ROOTS`
- `DOC_TO_MD_INPUT_ROOTS`
- `DOC_TO_MD_OUTPUT_ROOTS`

These are guardrails only. They are not a sandbox and do not restrict CPU,
memory, temporary storage, ZIP expansion, renderer vulnerabilities, or all
network behavior in dependencies. Use OS/container sandboxing for untrusted
documents.
