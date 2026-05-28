# ADR 0002: Doc To Md Architecture

Status: Accepted

Date: 2026-05-26 20:21:35 +0300

Last updated: 2026-05-27

## Context

`doc-to-md` is a public skill for converting trusted local documents and data
files to Markdown. It wraps Microsoft MarkItDown with local runtime guardrails,
then adds reusable workflow profiles, optional PDF audit bundles, and optional
OCR preprocessing workflows for textbook-like PDFs.

The skill must satisfy five different needs:

- Personal operation: day-to-day document conversion on the author's current
  MacBook should be quick, local, and predictable.
- Public distribution: another user should be able to install the public core
  without receiving private defaults, local paths, caches, generated outputs, or
  machine-specific runtime state.
- Plugin distribution: public sharing should use a source-only plugin artifact
  that can be validated and installed without bundling local runtimes, private
  local policy, or private overlays.
- Personal local policy: the author can keep local OCR language preferences and
  workflow habits without changing the public skill contract or creating a
  second required skill.
- Publication safety: the skill should be honest about supported platforms,
  dependency reproducibility, security boundaries, licensing, and output quality.

The architecture must keep the public skill, private local policy, installed
runtime, external tools, generated outputs, and migration artifacts separate.

## Decision

### 1. Keep `doc-to-md` as the public core

The public `doc-to-md` skill contains only publishable instructions, wrappers,
requirement files, guardrails, references, reusable workflow profiles, and
workflows.

It must not contain:

- private sample documents;
- personal paths;
- private OCR language defaults or universalized personal language choices;
- local aliases;
- local cache/state;
- generated Markdown, OCR PDFs, audit bundles, or extracted assets.

Reusable workflow profiles belong in the public core when they describe a
general method that another user can evaluate and reuse. The current public
profiles are:

- `Standard Local Document Profile` for ordinary trusted local files.
- `Textbook Audit + OCR Profile` for textbook-like PDFs, scanned PDFs,
  formula-heavy PDFs, diagram-heavy PDFs, link-heavy PDFs, or other PDFs where
  silent quality loss would be costly.

Personal defaults belong in a private local policy file such as
`private/local-policies/doc-to-md.md`. The dependency direction is one-way:
private local policy may refer to the public core; the public core must not
require private-only files, commands, fixtures, paths, or user-specific
defaults. A private local policy file is advisory configuration for the operator
or agent; it is not a second skill and does not replace the public core.

### 2. Treat artifact layers as distinct

`doc-to-md` uses the repository artifact model:

- public staged copy: `skills/doc-to-md/`
- plugin distribution artifact: `plugins/doc-to-md/`
- installed operational copy: `${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/`,
  `$HOME/.agents/skills/doc-to-md/`, `$REPO_ROOT/.agents/skills/doc-to-md/`, or
  another agent-specific skill location
- private local policy file: `private/local-policies/doc-to-md.md` or another
  approved private notes location
- runtime dependency layer: MarkItDown venvs, optional book/OCR venvs, wrappers,
  Tesseract, and related external CLIs
- generated output layer: Markdown files, OCR PDFs, audit bundles, reports,
  assets, and temp directories
- cache/state layer: local diagnostic state, package caches, logs, and run
  evidence

These layers must not be collapsed into one "skill" object. Installed venvs,
wrapper symlinks, cache, generated output, and local state are not public skill
source.

The plugin artifact is also not runtime state. It is a packaging layer around
the public skill source.

### 3. Use a narrow pinned MarkItDown core runtime

The default runtime is a pinned local MarkItDown core profile, not
`markitdown[all]`.

Default scope:

- PDF
- DOCX
- PPTX
- XLS
- XLSX
- HTML
- CSV
- JSON
- XML
- text-like files
- ZIP extraction

Excluded from the default runtime:

- audio transcription;
- YouTube transcription;
- Azure Document Intelligence;
- Content Understanding;
- OCR plugins;
- LLM-backed image description;
- arbitrary MarkItDown plugins.

Those advanced paths may be added intentionally later, but they are not part of
the default public core.

### 4. Use `markitdown-local` and `mdown` as the supported conversion surface

The public command shape is:

```bash
mdown input-file -o output-file.md
```

`mdown` is a symlink to `markitdown-local`. The wrapper runs the pinned core
MarkItDown binary from `${CODEX_HOME:-$HOME/.codex}/tools/markitdown-core-venv`.

The wrapper blocks remote URI arguments, plugin/cloud flags, and advanced
MarkItDown modes by default. Users may opt into remote or advanced modes only
with explicit flags and deliberate dependency/credential setup.

### 5. Make `-o/--output` the only protected file-write path

Shell redirection is not a supported protected write path:

```bash
mdown input.pdf > output.md
```

The shell opens and truncates `output.md` before the wrapper runs, so the wrapper
cannot protect an existing file.

The supported path is `-o/--output`, where the wrapper writes through a temporary
file and replaces the destination only after MarkItDown succeeds. This protects
the previous output from normal process failures. It is not a crash, power-loss,
or multi-writer durability guarantee.

Stdout remains allowed for inspection and explicit piping, but it is not the
recommended skill workflow for writing files.

### 6. Keep the textbook path as an audit bundle, not inline reconstruction

`mdown-book` creates a PDF audit bundle for trusted textbook-like PDFs:

- `content.md`
- `audit.md`
- `assets/`
- `manifest.json`
- `conversion-report.md`

This workflow is source-tethered metadata and content extraction. It does not
promise:

- inline image placement in the clean Markdown;
- inline link placement in running text;
- high-fidelity PDF layout reconstruction;
- formula-aware parsing;
- OCR by default.

`content.md` is the clean MarkItDown output. `audit.md` is inspection support.
The separation is deliberate: clean content stays readable, while image/link/page
traceability stays available for quality review.

### 7. Keep PyMuPDF optional and outside the core runtime

The audit bundle uses PyMuPDF and therefore runs in a separate optional book
venv. This keeps the normal core runtime smaller and avoids imposing PyMuPDF's
AGPL/commercial licensing decision on users who only need basic conversion.

The public skill must disclose that PyMuPDF is dual licensed under AGPL or a
commercial license, and users must review license compatibility before public or
company redistribution.

### 8. Use OCRmyPDF as an optional local preprocessor

OCR is not part of the default core runtime.

For scanned PDFs or low-text PDFs, the chosen route is:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-audit-bundle
```

OCRmyPDF writes a searchable OCR PDF first. The audit bundle then runs on that
derived PDF.

This preserves a clear boundary:

- source PDF remains the original input;
- OCR PDF is a derived artifact;
- audit bundle records conversion evidence and warnings.

The OCR workflow defaults to `eng`. The public workflow profile may document
`eng+rus` as an English/Russian OCR choice when the source language is declared,
detected, or plausible and the language packs are installed. The public core
must not treat `eng+rus`, or any other language string, as a universal default.
Private local policy may prefer `eng+rus` for the author's own English/Russian
materials.

### 9. Check real OCRmyPDF v17 requirements in the doctor

`mdown-ocrpdf --doctor` verifies the runtime actually needed by OCRmyPDF v17:

- Python version;
- OCRmyPDF version;
- `fpdf2`;
- `uharfbuzz`;
- `pikepdf`;
- `pypdfium2` or Ghostscript for PDF rasterization;
- Tesseract `>= 4.1.1`;
- requested Tesseract language data;
- native arm64 Tesseract binary on macOS arm64;
- optional PDF/A-related tooling when requested.

`qpdf` CLI is not treated as a hard requirement because OCRmyPDF v17 uses
`pikepdf` for qpdf integration.

Rosetta-only Tesseract on Apple Silicon is a failure condition. The goal is to
avoid a latent dependency on Rosetta as macOS support changes.

### 10. Use guardrails, not a sandbox

The wrappers provide safety guardrails:

- remote URI blocking by default;
- plugin/cloud option blocking by default;
- input and output root checks through environment variables;
- input-size limits;
- process timeouts;
- output staging;
- output locks for book and OCR workflows.

These are not a security sandbox. They do not fully restrict CPU, memory,
temporary storage, renderer vulnerabilities, ZIP expansion, or all behavior of
dependencies.

The skill contract is trusted local files by default. Hosted ingestion of
untrusted documents requires additional OS/container sandboxing and is outside
the public core contract.

### 11. Use exact pins for local installs and platform hash locks for release

Default requirement files use exact version pins. This supports predictable
local rebuilds while keeping normal installs usable across compatible
environments.

For stricter public release, the skill publishes platform-specific
`--require-hashes` files. The current generated profiles are:

```text
macos-arm64-py313: core, book, OCR
macos-intel-py312: core, book
```

The installer supports:

```bash
bash scripts/install.sh --hash-locked
```

Hash files are platform-specific. A macOS arm64 Python 3.13 hash file must not
be treated as a universal lock for Intel macOS, Linux, WSL, or native Windows.
Intel macOS uses a separate Python 3.12 profile because the default core
dependency graph includes an `onnxruntime` version that does not publish a
compatible Intel macOS wheel for Python 3.13. Other platforms need their own
hash profiles before `--hash-locked` can be claimed for them.

Python minor versions are also support boundaries. A passing `py313` profile is
not evidence for `py312` or `py314`. New Python minor versions start as
candidate/unverified until their own resolver check, hash generation, doctors,
selftests, regression corpus, and sample conversions pass. The operational
profile register lives in `skills/doc-to-md/references/python-profiles.md`.

### 12. Keep external binaries outside Python lockfiles

Python requirements and hash files cover Python packages only.

External tools such as Tesseract, Ghostscript, Homebrew artifacts, and OS-level
CLIs are runtime dependencies. They are checked by doctors, documented in
support guidance, and rebuilt or installed per machine. They are not copied as
part of the public skill, plugin artifact, or private local policy.

### 13. Make platform support explicit

Current support contract:

- Codex on macOS arm64: supported for core, book, and OCR.
- Codex on Intel macOS: supported for core and book on Python 3.12 with the
  `macos-intel-py312` profile.
- Claude Code on macOS: experimental unless `CODEX_HOME`,
  `DOC_TO_MD_BIN_DIR`, and `DOC_TO_MD_TOOLS_DIR` are configured.
- WSL on Windows: candidate.
- Native Windows PowerShell/CMD: unsupported.

OCR is not currently claimed for the Intel macOS hash-locked profile. The
current OCR route is based on OCRmyPDF v17, which requires `pikepdf>=10`; the
checked PyPI wheel set did not provide a compatible macOS Intel wheel for the
maintained Python 3.12 profile. Publishing Intel OCR support therefore requires
a separate reviewed dependency decision and doctor/selftest evidence.

The implementation uses Bash, POSIX paths, `install`, symlinks, `mktemp`, Perl,
`~/.local/bin`, and venv `bin/` paths. Native Windows support requires separate
PowerShell launchers, Windows path-root handling, and a Windows runtime install
contract before it can be honestly claimed.

`SKILL.md` frontmatter carries a short machine-readable compatibility summary
for routing and validation. `references/support-matrix.md` remains the canonical
compatibility contract. When platform support changes, update both together and
keep the frontmatter as a summary rather than a duplicate matrix.
`references/python-profiles.md` is the canonical profile-level register for
Python minor-version support and promotion procedure.

### 14. Treat Claude Code as a separate install target

Claude Code skill source may live under Claude skill locations such as
`~/.claude/skills` or `.claude/skills`.

The current runtime wrappers still default to `${CODEX_HOME:-$HOME/.codex}` and
`~/.local/bin`. Therefore Claude Code use is experimental unless the runtime
paths are configured explicitly or the runtime is installed in the `.codex`
compatibility location.

The skill source location and the runtime dependency location are distinct.

### 15. Migrate private local policy as source, not as runtime state

When moving personal `doc-to-md` defaults to a new personal machine or approved
work machine, copy only source-like policy files:

- a private repository file such as `private/local-policies/doc-to-md.md`;
- small reviewed local policy notes with no secrets.

Do not copy:

- venvs;
- wrapper symlinks or binaries;
- caches;
- logs;
- generated Markdown;
- OCR PDFs;
- audit bundles;
- extracted assets;
- private source documents;
- machine-specific Tesseract, Ghostscript, or Homebrew artifacts.

After migration, install the public core separately, rebuild runtimes on the
target machine, install external OCR tools there, and rerun doctors. Do not
create a second local skill unless there is a separate reviewed reason to turn
local policy into a real private skill.

### 16. Use doctors and selftests as the validation boundary

Runtime validation is not implicit.

The public core uses:

- `mdown-doctor`;
- `mdown-book --doctor`;
- `mdown-ocrpdf --doctor`;
- `scripts/selftest_doc_to_md.py`.

The core selftest covers:

- HTML;
- PDF;
- DOCX;
- XLS;
- XLSX;
- PPTX;
- CSV;
- JSON;
- XML;
- ZIP;
- protected `-o` failure behavior;
- stdout warning behavior.

This is a smoke test for the runtime profile, not a quality benchmark for every
possible document.

### 16a. Treat dependency drift as a maintenance signal

MarkItDown upgrades, PDF extraction stack refreshes, and OCR dependency graph
refreshes are maintenance lanes, not automatic installed-runtime mutations.

`mdown-markitdown-monitor` checks MarkItDown release metadata and the upstream
`magika` constraint. `mdown-dependency-monitor` checks PDF/OCR dependency drift
such as OCRmyPDF, PyMuPDF, `pdfminer.six`, `pdfplumber`, `pypdfium2`, and
`pikepdf`.

Both monitors may write local status/state files, but they must support
read-only source validation through `--no-write`. The automation boundary is
script-first: schedulers may run the scripts and relay script-owned output, but
they must not classify upstream metadata or promote installed runtimes.

### 17. Preserve generated outputs outside the skill

Generated Markdown, OCR PDFs, audit bundles, conversion reports, extracted
assets, and temp directories are user outputs. They are not skill source and
must not be committed unless deliberately reviewed as public examples or
fixtures.

`--force` in generated workflows is scoped to generated artifacts and should not
silently remove unrelated user files.

Generated audit and OCR reports include local path and command evidence by
default because that evidence is useful for local debugging and reproducibility.
Before transferring generated evidence outside the local trusted environment,
use sanitized report/export modes and still review document content, extracted
assets, links, and metadata manually.

### 18. Distribute public sharing through a source-only plugin

The public distribution shape for `doc-to-md` is a Codex plugin:

- staged skill source: `skills/doc-to-md/`
- plugin artifact: `plugins/doc-to-md/`
- bundled skill copy: `plugins/doc-to-md/skills/doc-to-md/`
- plugin manifest: `plugins/doc-to-md/.codex-plugin/plugin.json`
- local marketplace entry: `.agents/plugins/marketplace.json`

The plugin distributes source, not a ready-to-run conversion environment.

The plugin may include:

- `SKILL.md`;
- `agents/` metadata;
- `scripts/`;
- `references/`;
- pinned and hash-locked requirement files;
- license and third-party notices.

The plugin must not include:

- Python venvs;
- wrapper symlinks or installed commands from `~/.local/bin`;
- Tesseract, Ghostscript, Homebrew packages, or machine-specific binaries;
- private local policy files or private overlays;
- private documents or fixtures;
- generated Markdown, OCR PDFs, audit bundles, reports, extracted assets,
  caches, logs, or temp directories.

After plugin installation, users still run the bundled `scripts/install.sh` to
create local runtime dependencies. Optional book and OCR workflows remain
explicit install choices.

### 19. Keep staged skill and plugin copy synchronized

`plugins/doc-to-md/skills/doc-to-md/` must remain an exact copy of
`skills/doc-to-md/`.

The repository validation gate checks this with `scripts/validate-plugins.sh`.
If the bundled plugin skill drifts from the staged public skill, validation
fails and instructs the maintainer to resync the plugin copy.

`scripts/validate-skills.sh` and `scripts/validate-plugins.sh` are publication
checks for source artifacts. They do not prove that a user's local runtime
dependencies are installed correctly; runtime doctors and selftests remain the
operational validation boundary.

The release gate also runs a dependency license/runtime audit. For public
publication evidence, maintainers run it with `DOC_TO_MD_SCA_MODE=required` so
online package vulnerability metadata must be available and clean.

### 20. Use user-facing diagnostics only when trust or action changes

The skill should not show heavy diagnostics for routine successful conversions.
It should show a user-facing diagnostic when the conversion state affects what
the user can trust, decide, or do next.

The public diagnostic shape is:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Diagnostics are required for runtime absence, doctor failures, guardrail
blocks, suspicious or empty output, audit warnings, OCR boundaries, write-safety
issues, unsupported platform or runtime paths, and publication or licensing
boundaries. Detailed wording lives in `skills/doc-to-md/references/diagnostics.md`.

## Consequences

### Positive consequences

- The public skill is reviewable without exposing private defaults or local
  files.
- Reusable textbook/audit/OCR behavior is available to public users through
  workflow profiles instead of being hidden in local policy.
- The day-to-day command remains simple: `mdown input -o output.md`.
- Normal installs avoid the large and fragile `markitdown[all]` dependency set.
- Optional PDF and OCR paths are available without inflating the core runtime.
- Output writes are safer than shell redirection for normal process failures.
- The textbook path is honest about quality boundaries and audit traceability.
- OCR dependencies are checked against real local capabilities, including
  Tesseract language data and native architecture.
- User-facing diagnostics make conversion failures and trust boundaries
  actionable without making routine successful runs noisy.
- Public release can use hash-locked profiles without pretending one hash file
  covers every platform.
- Plugin distribution gives other users a clean source artifact without
  bundling private local policy, private overlays, or local runtime state.
- Plugin validation detects staged/plugin drift before publication.
- Migration guidance avoids copying stale venvs, caches, outputs, and
  machine-specific binaries.
- Windows support is not overclaimed.

### Costs and tradeoffs

- The implementation remains macOS/POSIX-first.
- Native Windows requires a separate implementation before support can be
  claimed.
- Claude Code use needs explicit runtime path configuration.
- Hash-locked installs are only available for published platform profiles.
- Intel macOS support currently requires Python 3.12 for the supported
  hash-locked core/book path.
- New Python minor versions require explicit promotion before support can be
  claimed, even when normal `pip install` succeeds locally.
- External tools such as Tesseract remain outside Python lockfiles.
- The audit bundle helps inspect images and links but does not reconstruct a
  high-fidelity textbook layout.
- The plugin artifact must be kept in sync with the staged public skill copy.
- Personal local policy must be reviewed separately when it changes, because it
  is intentionally outside the public skill and plugin artifacts.
- The diagnostic contract must stay aligned with wrapper behavior, doctors, and
  audit report semantics.
- Plugin installation is not enough by itself; users must still build local
  runtimes and run doctors.
- Formula-heavy, table-heavy, vector-diagram-heavy, or scanned materials may
  still need manual review or a different document-parsing engine.
- Guardrails reduce accidental misuse but do not create a sandbox for untrusted
  hosted ingestion.

## Alternatives Considered

### Install `markitdown[all]` by default

Rejected. It pulls large Azure, YouTube, audio, OCR/plugin, and optional
dependencies that are outside the default skill contract. This increases install
size, update drift, and failure surface for workflows the public core disables by
default.

### Put OCR, book audit, and core conversion in one runtime

Rejected. A single runtime would make simple document conversion depend on
PyMuPDF, OCRmyPDF, Tesseract-related concerns, and optional licensing decisions.
Separate runtimes keep the default path smaller and clearer.

### Make OCR-first or Marker/MinerU the default textbook workflow

Rejected for the public core. Those paths can be useful experiments for complex
documents, but they are heavier, faster-moving, and have separate quality,
licensing, model, and runtime implications. The accepted public path is
MarkItDown core plus an audit-first textbook profile when quality is uncertain,
with OCRmyPDF preprocessing as a separate derived step when the audit or user
request calls for OCR.

### Promise inline image/link placement for textbooks

Rejected. The current implementation does not reliably place images and links
inline inside clean Markdown. The honest output contract is `content.md` plus
separate `audit.md`, assets, manifest, and report.

### Support shell redirection as a normal output path

Rejected. Shell redirection can truncate an existing destination before the
wrapper starts. The supported write path is `-o/--output`.

### Bundle ready-to-run runtimes inside the public plugin

Rejected. Bundling venvs, wrapper symlinks, Tesseract, Ghostscript, Homebrew
artifacts, caches, or generated outputs would mix source distribution with
machine-specific operational state. The plugin is source-only; each target
machine builds its own runtime and proves it with doctors.

### Treat path-root checks as a sandbox

Rejected. Path checks, timeouts, input-size limits, and option blocks are useful
guardrails, but they are not sufficient for hosted ingestion of untrusted
documents.

### Publish one universal hash lockfile

Rejected. Wheel hashes are platform and Python-version specific. The current
public release hash profiles are intentionally named by platform and Python
version, for example `macos-arm64-py313` and `macos-intel-py312`.

### Treat `python3` as a supported version range

Rejected. A generic `python3` claim hides the Python ABI boundary that matters
for wheel availability and `--require-hashes`. The accepted design treats every
OS, architecture, and Python minor-version combination as a separate profile.

### Keep a separate `doc-to-md-private` skill for personal defaults

Rejected for the current architecture. A second skill is unnecessary for the
author's current local policy because the public core can carry reusable
workflow profiles, while a small private policy file can record personal
defaults without creating another skill-discovery surface. A separate private
skill remains possible later only if it adds real behavior, commands, or
private workflows that cannot be represented as advisory policy.

### Copy private local policy together with venvs and local outputs during migration

Rejected. That would mix source policy, runtime dependency state, cache/state,
generated outputs, and machine-specific binaries. Migration copies source-like
policy files only and rebuilds runtime dependencies on the target machine.
