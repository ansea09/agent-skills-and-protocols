# Support Matrix

Use this matrix before installing or publishing `doc-to-md`.

`SKILL.md` frontmatter contains a short machine-readable compatibility summary
for routing and validation. This file is the canonical compatibility contract;
when the matrix changes, update the frontmatter summary to match.

Python minor-version support is governed by
`references/python-profiles.md`. Do not infer support for `py312`, `py313`, or
`py314` from another Python minor version.

## Current Support Contract

| Environment | Status | Contract |
| --- | --- | --- |
| Codex on macOS, arm64 | Supported | Maintained for core workflows, including `mdown` and `mdown-epub`, plus book and OCR workflows. Install the public skill, run `scripts/install.sh`, add `~/.local/bin` to `PATH`, then run the doctors. Optional `--hash-locked` installs use the `macos-arm64-py313` hash profile. |
| Codex on macOS, Intel | Supported | Maintained for core workflows, including `mdown` and `mdown-epub`, plus book workflows on Python 3.12 with the `macos-intel-py312` hash profile. OCR hash-locked support is not published for Intel macOS under the current OCRmyPDF v17 dependency graph. |
| Claude Code on macOS | Experimental | Claude Code discovers skills from Claude skill locations such as `~/.claude/skills` or `.claude/skills`. Run the bundled installer from that source directory so installed command shims record `DOC_TO_MD_SKILL_DIR`; configure `DOC_TO_MD_BIN_DIR` and `DOC_TO_MD_TOOLS_DIR` when the defaults are not appropriate. The EPUB bundle output is runtime-neutral, but command installation remains experimental until a Claude Code release gate is run. |
| WSL on Windows | Candidate | Use the Linux/WSL shell environment and rebuild runtimes inside WSL. Do not reuse macOS venvs, wrappers, cache, or Tesseract binaries. EPUB bundle output is runtime-neutral, but a separate WSL hash profile is required for hash-locked public release. |
| Native Windows PowerShell/CMD | Unsupported | The current implementation uses Bash, POSIX paths, `install`, symlinks, `mktemp`, Perl, `~/.local/bin`, and venv `bin/` paths. Native Windows support needs separate PowerShell launchers, Windows path-root handling, and a Windows runtime install path. |

## Required Local Tools

- Bash-compatible shell for all wrapper and install scripts.
- Python 3.13 for the maintained macOS arm64 hash profile.
- Python 3.12 for the maintained Intel macOS hash profile.
- Python 3.11 or newer for OCR when OCR is installed outside a hash-locked
  profile; this is a package/runtime floor, not a public support claim for
  every Python minor version.
- `perl` for the core wrapper timeout guard.
- `tesseract >= 4.1.1` for OCR on profiles where OCR is installed.
- Native architecture binaries on macOS arm64; Rosetta-only OCR binaries are treated as a failure.

## Hash-Locked Release Profiles

The published hash files are platform-specific. Do not treat a macOS arm64 hash
file as a universal lock for Intel macOS, Linux, WSL, or Windows.

Current generated profiles:

```text
macos-arm64-py313: core, book, OCR
macos-intel-py312: core, book
```

The `core` component includes the standard `mdown` path and the separate
`mdown-epub` EPUB LLM-analysis bundle command. EPUB bundle support is not a
separate hash-profile component.

Profile support levels:

| Profile | Level | Components | Public claim |
| --- | --- | --- | --- |
| `macos-arm64-py313` | Supported hash-locked profile | core, book, OCR | Supported with `--hash-locked`; core includes `mdown-epub`. |
| `macos-intel-py312` | Supported hash-locked profile | core, book | Supported with `--hash-locked` except OCR; core includes `mdown-epub`. |
| `macos-arm64-py312` | Candidate / unverified | none claimed | Use normal pinned install only as a candidate path until hashes and checks exist. |
| `macos-arm64-py314` | Candidate / unverified | none claimed | Do not claim until compiled wheels and checks are reviewed. |
| `macos-intel-py313` | Candidate / unverified | none claimed | Known blocker in the checked core graph: `onnxruntime==1.26.0` lacks a compatible Intel macOS wheel. |
| `macos-intel-py314` | Candidate / unverified | none claimed | Do not claim until the dependency graph is reviewed for that ABI. |
| `linux-x86_64-py312` / `linux-x86_64-py313` | Candidate / unverified | none claimed | WSL/Linux needs separate profile generation and validation. |

Use the arm64 profile from an arm64 Python 3.13 runtime:

```bash
bash scripts/install.sh --hash-locked
bash scripts/install.sh --book --hash-locked
bash scripts/install.sh --ocr --hash-locked
```

One-command supported macOS arm64 happy path for core workflows, book, OCR, and JSON
doctors:

```bash
bash scripts/install.sh --all --hash-locked && mdown-doctor --json && mdown-epub --doctor --json && mdown-book --doctor --json && mdown-ocrpdf --doctor --json
```

Use the Intel profile from an Intel Python 3.12 runtime:

```bash
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash scripts/install.sh --hash-locked
PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 bash scripts/install.sh --book --hash-locked
```

Do not run `--ocr --hash-locked` on Intel macOS unless a reviewed
`requirements-ocr.macos-intel-*.hashes.txt` file is published. The current OCR
top-level requirement resolves to OCRmyPDF v17, which requires `pikepdf>=10`;
a compatible macOS Intel wheel for that dependency was not available in the
checked PyPI wheel set for the maintained Python 3.12 profile.

Set another profile only after publishing matching files:

```bash
DOC_TO_MD_HASH_PROFILE=linux-x86_64-py313 bash scripts/install.sh --hash-locked
```
