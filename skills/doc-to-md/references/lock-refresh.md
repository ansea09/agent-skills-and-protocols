# Lock Refresh

Use this reference for maintenance releases when online doctor checks show
dependency drift in high-impact conversion zones. This is a maintainer workflow,
not a day-to-day conversion workflow.

## Refresh Zones

The refresh command intentionally targets the zones most likely to affect
conversion quality or runtime churn:

| Zone | Packages | Why it matters |
| --- | --- | --- |
| Core PDF extraction stack | `pdfminer.six`, `pdfplumber`, `pypdfium2`, `pillow` | Can change extracted text, page parsing, image handling, and PDF edge cases. |
| Core file-type detection stack | `onnxruntime`, `numpy`, `protobuf`, `flatbuffers`; constrained notice for `magika` | Can change file detection and add large ML/runtime transitive changes. |
| OCR dependency graph | `ocrmypdf>=17,<18` plus transitive pins | Can change OCR quality, rasterization, text-layer generation, and OCR reports. |

## Commands

Preview changes without writing files:

```bash
mdown-refresh-locks --core-pdf --core-filetype --ocr
```

Apply the targeted refresh and regenerate the maintained hash profile:

```bash
mdown-refresh-locks --core-pdf --core-filetype --ocr --apply
```

If Microsoft publishes a MarkItDown version whose package metadata supports
`magika>=1`, refresh MarkItDown through an explicit upgrade lane rather than by
upgrading `magika` alone:

```bash
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply
```

This lane lets pip resolve the MarkItDown-compatible dependency graph, runs
`pip check`, then runs the core smoke selftest before writing pins.

Prepare MarkItDown converter upgrades through `references/markitdown-upgrade.md`;
do not promote `magika 1.x` independently.

If the explicit lane fails `pip check`, do not force the pins manually. That
means the candidate converter and dependency graph are not internally
consistent for this runtime profile.

From a repository checkout, run the script directly so the staged public copy is
updated instead of only the installed operational copy:

```bash
python3 skills/doc-to-md/scripts/refresh-locks.py --core-pdf --core-filetype --ocr --apply
```

The default refresh hash profile is `macos-arm64-py313`. Set
`DOC_TO_MD_HASH_PROFILE` or pass `--hash-profile` only when the matching
platform hash file is intentionally maintained.

Maintained hash profiles:

```text
macos-arm64-py313: core, book, OCR
macos-intel-py312: core, book
```

Do not reuse these hash files for another Python minor version. A profile such
as `macos-arm64-py314` or `macos-intel-py313` needs its own resolver check,
hash generation, doctors, selftests, and regression review. See
`references/python-profiles.md` before adding a new profile.

Generate hashes from current reviewed pins without refreshing versions:

```bash
python3 skills/doc-to-md/scripts/refresh-locks.py --hash-only --hash-profile macos-arm64-py313 --apply
python3 skills/doc-to-md/scripts/refresh-locks.py --hash-only --hash-profile macos-intel-py312 --apply --core-pdf --book-hash
```

The Intel profile is intentionally limited to core and book. Do not generate or
publish `requirements-ocr.macos-intel-*.hashes.txt` until the OCR dependency
graph resolves to wheels that are compatible with the selected Intel Python
profile and passes `mdown-ocrpdf --doctor`.

`magika` is intentionally not auto-refreshed while maintained MarkItDown
metadata keeps it on the `0.6` line. If online doctor reports
`magika 0.6.3 -> 1.x`, treat that as an upstream compatibility signal: keep the
pinned `0.6.x` package until MarkItDown changes its dependency constraint or a
separate MarkItDown upgrade branch proves compatibility.

Other package drift can also be constrained by parent packages. For example,
PDF extractor drift should still pass the resolver and `pip check`; if the
refresh command reports no pin change or fails compatibility checks, keep the
current pins and treat the online drift as informational.

Do not add `--core-markitdown` to routine `--all` maintenance. Updating the
converter itself can change Markdown output across every supported format, so it
needs an explicit version choice and a broader review.

The weekly upstream monitor is allowed to write only the local maintenance
status/state files. It must not edit pins, hashes, docs, wrappers, or installed
runtimes:

```bash
mdown-markitdown-monitor --json
```

`no-action` is log-only. Actionable signals are surfaced to the user through the
status file and thread notification. If the user declines, record the decision
with `mdown-markitdown-monitor --record-decision declined`; the same warning is
not repeated until upstream changes again.

Before publishing a MarkItDown upgrade, compare the synthetic regression corpus
against expected Markdown snapshots:

```bash
python3 scripts/regression_corpus.py
python3 scripts/audit_bundle_regression.py
```

If the new MarkItDown output is intentionally accepted, update snapshots in the
same reviewed change:

```bash
python3 scripts/regression_corpus.py --update
```

## Required Checks After Apply

After refreshing pins, rebuild and verify the runtimes before publishing:

```bash
bash scripts/install.sh --rebuild --all
mdown-doctor --online
mdown-doctor --json
mdown-book --doctor
mdown-ocrpdf --doctor --online
python3 scripts/selftest_doc_to_md.py
python3 scripts/regression_corpus.py
```

Also run at least one real sample conversion for the workflow affected by the
refresh:

- a born-digital PDF or PDF-heavy document for PDF extraction stack changes;
- a mixed set of common file types for file-type detection changes;
- a scanned PDF for OCR dependency graph changes.

## Human Action Boundary

For ordinary users:

- online drift is not an immediate failure when doctors still report installed
  packages matching local pins;
- keep using the pinned runtime unless conversion quality is bad or the skill
  maintainer publishes a reviewed refresh;
- report the drift output and a sample document if conversion quality changes.

For skill maintainers:

- review the dependency diff and license boundary before publishing;
- compare generated Markdown and audit/OCR reports before and after refresh;
- when `--core-markitdown` is used, compare DOCX, PPTX, XLS/XLSX, HTML, PDF,
  EPUB, CSV/JSON/XML/ZIP smoke outputs using `scripts/regression_corpus.py`, plus at
  least one real PDF;
- regenerate platform hash files only for platforms actually tested;
- do not claim Windows/native or other unsupported hash profiles just because
  the local macOS profile refreshed successfully.

## Consequence

Refreshing locks improves release hygiene and reduces stale dependency drift,
but it can change Markdown output. Treat a lock refresh as a behavior-affecting
maintenance change, not as a harmless formatting update.
