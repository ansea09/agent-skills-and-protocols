# doc-to-md

Public-core Codex skill for converting trusted local documents and data files
to Markdown with Microsoft MarkItDown, plus optional PDF audit and OCR
preprocessing workflows. Reusable workflow profiles live in this public core;
personal defaults and machine-specific choices belong in private local policy
files.

## Install

Supported default paths: Codex on macOS arm64 for core, book, and OCR;
Codex on Intel macOS for core and book on Python 3.12. WSL is a candidate.
Claude Code on macOS is experimental unless runtime paths are configured.
Native Windows PowerShell/CMD is unsupported.

Python minor versions are profile-specific. `macos-arm64-py313` does not imply
support for `macos-arm64-py312` or `macos-arm64-py314`. Unlisted Python
profiles are candidate/unverified until the support matrix and
`references/python-profiles.md` say otherwise.

Core runtime and wrappers:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh"
```

Optional workflows:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --book
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --ocr
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --all
```

Hash-locked public release install for macOS arm64 / Python 3.13:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --hash-locked
```

One-command happy path for supported macOS arm64 with core, book, OCR, and JSON
doctors:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --all --hash-locked && mdown-doctor --json && mdown-book --doctor --json && mdown-ocrpdf --doctor --json
```

Hash-locked public release install for Intel macOS / Python 3.12:

```bash
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --hash-locked
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --book --hash-locked
```

Intel macOS does not currently publish an OCR hash-locked profile. Use normal
OCR installs only after local doctor checks, or add a reviewed Intel OCR
profile first.

Read `references/support-matrix.md`, `references/python-profiles.md`,
`references/scenario-boundaries.md`, and `references/threat-model.md` before
installing outside the maintained Codex/macOS path, accepting untrusted files,
or promising public support for a scenario.

## Claude Code

Claude Code skill source may live under `~/.claude/skills` or `.claude/skills`.
The runtime wrappers still default to `${CODEX_HOME:-$HOME/.codex}` and
`~/.local/bin`, so configure these paths explicitly or use the `.codex`
compatibility runtime:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export DOC_TO_MD_BIN_DIR="${DOC_TO_MD_BIN_DIR:-$HOME/.local/bin}"
export DOC_TO_MD_TOOLS_DIR="${DOC_TO_MD_TOOLS_DIR:-$CODEX_HOME/tools}"
bash "$HOME/.claude/skills/doc-to-md/scripts/install.sh"
```

## Usage

Use `-o/--output` for supported file writes:

```bash
mdown source.pdf -o source.md
```

Do not use shell redirection for overwrite-safe file writes:

```bash
# Not supported by this skill as a protected write path:
mdown source.pdf > source.md
```

## Workflow Profiles

Use the `Standard Local Document Profile` for ordinary trusted local files where
text extraction is expected to be enough.

Use the `Textbook Audit + OCR Profile` for textbook-like PDFs, scanned PDFs,
formula-heavy PDFs, diagram-heavy PDFs, link-heavy PDFs, or any PDF where silent
quality loss would be costly. That profile starts with an audit bundle when
quality is uncertain, uses OCR only as an explicit derived step, and preserves
failed outputs, OCR PDFs, audit bundles, extracted assets, and comparison
artifacts unless the user asks to clean them.

Read `references/workflow-profiles.md` for routing details and
`references/scenario-boundaries.md` for scenarios that work well, require
caveats, or are unsupported.

## Optional PDF Audit Bundle

```bash
mdown-book textbook.pdf -o textbook-audit-bundle
```

This creates `content.md`, `audit.md`, `assets/`, `manifest.json`, and
`conversion-report.md`. It does not perform inline image placement or
high-fidelity PDF reconstruction.

For external transfer, export a sanitized copy of report files:

```bash
mdown-book --export-sanitized textbook-audit-bundle -o textbook-audit-bundle-public
```

## Optional OCR Preprocessor

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-audit-bundle
```

Run `mdown-ocrpdf --doctor` before relying on OCR.

For external transfer, generate or export a sanitized OCR report:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf --sanitize-report
mdown-ocrpdf --export-sanitized-report scanned-ocr.pdf.ocr-report.json --report scanned-ocr.public-report.json
```

## User-Facing Diagnostics

When conversion state affects trust or next action, use the diagnostic shape
from `references/diagnostics.md`:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Routine successful conversions do not need this diagnostic block. Report the
output path, command shape, and focused verification result.

## Lock Refresh

Online drift is a maintainer signal when the installed runtime still matches
local pins. It is not an immediate failure for ordinary conversions.

The weekly MarkItDown upstream monitor is read-only for runtime pins and writes
only a local maintenance status file by default:

```bash
mdown-markitdown-monitor --json
```

For read-only source or CI checks, suppress status/state writes:

```bash
mdown-markitdown-monitor --json --no-write
```

`no-action` is log-only. Actionable signals are `pending`, `blocked`,
`ready-for-lane`, and `magika-unblocked`. User approval is recorded before the
installed promotion runs. For `ready-for-lane` and `magika-unblocked`, the
automation may prepare a branch and run the source gate when the repository
worktree is clean:

```bash
mdown-prepare-markitdown-upgrade --json
```

Schedulers should use script-owned output instead of interpreting JSON:

```bash
mdown-prepare-markitdown-upgrade --automation-output
```

Installed-copy promotion is still manual and approval-based:

```bash
mdown-markitdown-monitor --record-decision approved
scripts/validate-doc-to-md-release.sh --promotion
```

If the user declines, record that decision so the monitor does not repeat the
same warning until upstream changes again:

```bash
mdown-markitdown-monitor --record-decision declined
```

Read `references/maintenance-monitor.md` for the signal definitions,
notification policy, and approval boundary.

The PDF/OCR dependency monitor is separate from MarkItDown auto-prepare. It
reports drift such as a newer OCRmyPDF release without changing pins:

```bash
mdown-dependency-monitor --json --no-write
```

Preview targeted maintenance changes:

```bash
mdown-refresh-locks --core-pdf --core-filetype --ocr
```

Apply them only in a maintained source checkout, then rebuild and rerun doctors:

```bash
mdown-refresh-locks --core-pdf --core-filetype --ocr --apply
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --rebuild --all
mdown-doctor --online
mdown-doctor --json
mdown-book --doctor --json
mdown-ocrpdf --doctor --json
mdown-ocrpdf --doctor --online
```

Use an explicit MarkItDown upgrade lane when the converter itself changes:

```bash
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply
```

Before publishing a MarkItDown upgrade, run the synthetic regression corpus:

```bash
python3 scripts/regression_corpus.py
python3 scripts/audit_bundle_regression.py
```

Read `references/lock-refresh.md` and `references/markitdown-upgrade.md` before
publishing refreshed pins or a converter upgrade.

## Publication Notes

Read `references/publishing.md` and `THIRD_PARTY_NOTICES.md` before publishing
or redistributing this skill. The default trust boundary is trusted local files
only, not hosted ingestion of untrusted documents.

Read `references/release-notes.md` before publishing or installing a new
version. Release notes describe source changes and required user or maintainer
actions; they do not treat local venvs, cache, generated outputs, or installed
wrapper symlinks as release payloads.

For hosted/shared environments, `doc-to-md` guardrails are not a sandbox. Read
`references/threat-model.md` and add a separate sandboxed ingestion
architecture before accepting untrusted documents.

Do not publish private policy files, local fixtures, personal OCR defaults, or
machine-specific paths with this core.

For local policy migration, read `references/local-policy-migration.md`.

For public release, run the repository release gate:

```bash
scripts/validate-doc-to-md-release.sh
```

For publication evidence, require online dependency SCA in the same gate:

```bash
DOC_TO_MD_SCA_MODE=required scripts/validate-doc-to-md-release.sh
```

The source gate uses staged requirements and staged wrappers. Set
`DOC_TO_MD_CI_RUNTIME` to a reusable CI cache root when you do not want the gate
to create temporary venvs:

```bash
DOC_TO_MD_CI_RUNTIME="$PWD/.doc-to-md-ci-runtime" scripts/validate-doc-to-md-release.sh --source
```

For local promotion from an installed operational copy, run:

```bash
scripts/validate-doc-to-md-release.sh --promotion
```
