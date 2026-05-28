# User-Facing Diagnostics

Use this reference when a `doc-to-md` run produces a state that affects user
trust, next action, or publication decisions.

## Diagnostic Shape

Use this four-part shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Keep the message concrete. Name the file, command family, missing dependency,
doctor result, or output artifact when known. Do not speculate beyond the
observed evidence.

## When To Show A Diagnostic

Show a diagnostic when any of these occur:

- Runtime unavailable: `mdown`, `markitdown-local`, `mdown-book`, `mdown-ocrpdf`,
  the corresponding venv, or an expected wrapper is missing.
- Doctor failure: pinned packages, optional workflow packages, Tesseract,
  Tesseract language data, PDF rasterization support, native architecture, or
  external OCR tooling is missing or mismatched.
- Input boundary failure: the file does not exist, is outside allowed roots, is
  too large for current guardrails, is not a local trusted file, or does not fit
  the selected profile.
- Guardrail block: remote URI, plugin/cloud option, advanced MarkItDown mode, or
  unsafe output path was blocked.
- Output trust problem: output is empty, tiny, malformed, unexpectedly sparse,
  or clearly missing important text, images, links, tables, formulas, or pages.
- Audit warning: `mdown-book` reports low-text pages, likely scanned pages,
  absent expected images, link recovery limits, formula/table suspicion, or
  other `conversion-report.md` warnings.
- OCR boundary: OCR was needed but not run, OCR ran and produced a derived PDF,
  OCR language data is missing, or OCR quality remains uncertain.
- Write safety issue: shell redirection was used for a file write, output
  staging failed, a same-output lock blocked a write, or timeout/input-size
  limits affected the result.
- Publication boundary: PyMuPDF, OCRmyPDF, hash-lock profile, platform support,
  or private local policy affects whether the skill can be redistributed or
  installed as claimed.
- Dependency drift boundary: `mdown-doctor --online` or
  `mdown-ocrpdf --doctor --online` reports drift in PDF extraction, file-type
  detection, OCR, hash-lock, or runtime tooling zones.
- External-transfer boundary: an audit bundle, manifest, conversion report, or
  OCR JSON report may expose local absolute paths or command evidence.

Do not show a diagnostic for a normal successful conversion. In that case, give
the output path, command shape, and focused verification result.

## Example Diagnostics

### Missing Core Runtime

```text
What happened: `mdown` is not available in PATH, and the expected core wrapper was not found.
What it means: The public skill source is installed, but the local MarkItDown runtime has not been built on this machine.
What you can do: Run `bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh"` and then `mdown-doctor`.
Consequences: I cannot make a trustworthy conversion until the runtime exists and the doctor passes.
```

### Empty Or Tiny Output

```text
What happened: The Markdown output was created, but it is empty or unexpectedly small.
What it means: The source may be scanned, image-heavy, encrypted, unsupported, or outside the quality boundary of the selected profile.
What you can do: Run `mdown-doctor --output output.md`; for PDFs, run `mdown-book` and inspect `conversion-report.md`.
Consequences: Treat the Markdown as incomplete until audit or OCR confirms what text is recoverable.
```

### OCR Language Missing

```text
What happened: OCR was requested with `eng+rus`, but the Russian Tesseract language data is not installed.
What it means: OCR cannot reliably process Russian text with the requested language configuration.
What you can do: Install the missing Tesseract language data, rerun `mdown-ocrpdf --doctor -l eng+rus`, then rerun OCR.
Consequences: Any OCR output produced without the right language data may omit or corrupt Russian text.
```

### Audit Reports Low-Text Pages

```text
What happened: The PDF audit bundle reports low-text pages.
What it means: Some pages may be scanned images, diagrams, formulas, or otherwise not recoverable through normal text extraction.
What you can do: Inspect `audit.md` and `conversion-report.md`; if the pages should contain text, run `mdown-ocrpdf` into a separate OCR PDF and rerun `mdown-book`.
Consequences: `content.md` should be treated as partial until the low-text pages are resolved or accepted.
```

### Shell Redirection Used For File Output

```text
What happened: The command wrote with shell redirection instead of `-o/--output`.
What it means: The shell may truncate the destination before the wrapper can protect the previous output.
What you can do: Rerun with `mdown input-file -o output-file.md`.
Consequences: The previous output may already be lost or incomplete; future protected writes require `-o/--output`.
```

### Report Prepared For External Transfer

```text
What happened: The audit bundle or OCR report contains local paths and command evidence.
What it means: The conversion evidence is useful for local debugging but may disclose machine-local information if shared as-is.
What you can do: Run `mdown-book --export-sanitized bundle -o bundle-public` or `mdown-ocrpdf --export-sanitized-report report.json --report report-public.json`.
Consequences: Sanitization redacts local absolute paths in reports, but you still need to review document content, assets, links, and metadata before publication.
```

### Online Dependency Drift

```text
What happened: The online doctor found dependency drift in PDF extraction, file-type detection, or OCR dependency zones.
What it means: The installed runtime still matches the local pins, so current conversions remain reproducible; the drift is a maintainer signal. Some drift may be intentionally blocked by upstream constraints, such as maintained MarkItDown candidates requiring magika~=0.6.1 or a parent package constraining a transitive dependency.
What you can do: For ordinary use, keep using the pinned runtime. For public maintenance, run `mdown-refresh-locks --core-pdf --core-filetype --ocr --apply`, rebuild runtimes, and rerun doctors plus sample conversions. If the converter itself changed, use `mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply`.
Consequences: A lock refresh can change Markdown output, OCR quality, and audit evidence, so it needs review before publication.
```

## Reporting After Diagnostics

After a diagnostic, still report the concrete artifacts that exist:

- source path;
- command family used;
- output Markdown path, OCR PDF path, or audit bundle path;
- doctor command or verification command run;
- warnings that remain unresolved;
- whether generated artifacts were preserved for review.
