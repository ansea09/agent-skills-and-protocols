# Release Notes

This file records user-visible `doc-to-md` changes. It is part of the public
skill documentation and should be updated before publishing a new public staged
or plugin release.

The notes describe source changes only. Installed runtimes, virtual
environments, wrapper symlinks, cache files, generated Markdown, OCR PDFs, and
audit bundles are local operational artifacts and are not release payloads.

## Unreleased

- Added script-first maintenance checks for MarkItDown upstream drift and
  PDF/OCR dependency drift. `no-action` stays quiet; actionable changes are
  reported through local status files and script-owned messages.
- Added an explicit MarkItDown upgrade lane that may prepare a reviewed source
  branch and run the source release gate, but does not promote changes into the
  installed operational skill automatically.
- Added dependency audit evidence for public release review, including
  vulnerability metadata checks when `DOC_TO_MD_SCA_MODE=required` is used.
- Added source and promotion release gates so public source/plugin validation is
  separate from installed-copy promotion validation.
- Added machine-readable doctor output contracts for core, book, and OCR
  doctors, with JSON Schema validation in the release gate.
- Added synthetic regression coverage for ordinary conversion formats and PDF
  audit-bundle evidence.
- Documented the trusted-local threat model: this skill is not a sandbox and is
  not a hosted ingestion service.
- Documented the support matrix: Codex/macOS arm64 is the primary supported
  path; Intel macOS is supported for core/book on Python 3.12; WSL is a
  candidate; Claude Code on macOS is experimental with explicit runtime paths;
  native Windows PowerShell/CMD is unsupported.
- Kept high-fidelity textbook parsing out of core. The textbook workflow remains
  an audit bundle plus optional OCR preprocessing, not inline reconstruction.

### User Action

For ordinary installed use, rebuild only when a release note or maintainer
instruction says the local runtime changed:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --rebuild --all
mdown-doctor --json
mdown-book --doctor --json
mdown-ocrpdf --doctor --json
```

For public release review, run the source gate from the repository root:

```bash
scripts/validate-doc-to-md-release.sh --source
```

For installed promotion after explicit approval, run:

```bash
scripts/validate-doc-to-md-release.sh --promotion
```

## 2026-05-27 - Release Governance Baseline

This baseline separated public skill source, plugin packaging, installed
operational copies, private local policy, runtime dependencies, cache/state, and
generated output layers.

Notable decisions:

- `doc-to-md` is one public core skill with reusable workflow profiles, not a
  required public/private skill pair.
- Personal defaults belong outside the public skill, for example in a private
  local policy file.
- Runtime dependencies are pinned and rebuilt locally; venvs are not public
  skill source.
- Protected file output uses `-o/--output`; shell redirection is not a supported
  protected write path.
- The PDF textbook route is named and treated as an audit bundle until inline
  placement or higher-fidelity parsing is deliberately added as a separate
  experimental workflow.
- OCRmyPDF remains an optional local preprocessor with its own runtime and
  doctor checks.
- MarkItDown upgrades are explicit, reviewed, and regression-gated; dependency
  drift is a maintenance signal, not an automatic runtime change.
