# PDF Audit Bundle

Use this reference when converting textbook-like PDFs where images, PDF links,
page traceability, and conversion warnings matter.

This reference supports the public `Textbook Audit + OCR Profile`. When quality
risk is uncertain, the profile is audit-first: create the audit bundle, inspect
low-text and extraction warnings, and run OCR only as a separate derived step
when the evidence calls for it.

## Output Bundle

`mdown-book source.pdf -o output-dir` writes:

- `content.md` - clean MarkItDown Markdown.
- `audit.md` - generated PDF page, image, link, and warning audit index.
- `assets/` - extracted embedded raster images from the PDF.
- `manifest.json` - machine-readable page, image, link, and warning metadata.
- `conversion-report.md` - human-readable quality report and follow-up checks.

The generated audit is a separate Markdown file. It does not perform inline image
placement, inline link placement, or high-fidelity PDF layout reconstruction.
`mdown-book` uses a same-output lock to reject parallel writes to one bundle, but
the bundle publication is still a bounded process-failure safeguard rather than
a crash/power-loss durability guarantee.

## External Transfer

`manifest.json` and `conversion-report.md` include local source paths and command
evidence by default. Before transferring an audit bundle outside the local
trusted environment, export a sanitized copy:

```bash
mdown-book --export-sanitized output-dir -o output-dir-public
```

For a new bundle that should redact local absolute paths immediately:

```bash
mdown-book source.pdf -o output-dir --sanitize-report
```

Sanitization redacts local absolute paths in report files. It does not remove
document content from `content.md`, `audit.md`, extracted assets, PDF metadata,
links, or user-visible document text; review those separately before publication.

## Quality Boundary

This workflow does not perform OCR by default. It is a source-tethered audit
bundle, not a high-fidelity re-publication of the original PDF layout.

Treat these as warnings that OCR or manual review is needed:

- many pages have very low extractable text;
- extracted images are mostly absent but the PDF visually contains diagrams;
- vector diagrams dominate the PDF;
- links are present in `manifest.json` but not recoverable into running text;
- formulas, tables, or captions look suspicious in the Markdown.

## OCR Path Candidates

Keep OCR as an explicit advanced route. Do not install OCR or LLM dependencies
into the core runtime.

- `markitdown-ocr`: simplest MarkItDown-aligned LLM Vision path; beta/young.
- `OCRmyPDF`: stable local preprocessing path for scanned PDFs; uses Tesseract
  and produces a searchable PDF before normal conversion.
- `Docling`, `Marker`, `MinerU`, `PaddleOCR`: heavier document-parsing engines.
    Evaluate in separate experimental workflows before adopting any default.

Do not add a high-fidelity textbook parser to the core runtime. If quality needs
exceed the audit bundle, create a separate experimental workflow with its own
runtime, support matrix, license review, doctors, regression samples, and
promotion/release gate.

## OCRmyPDF Preprocessor

For scanned textbooks where OCR is already known to be needed, run OCR into a
separate derived PDF, then run the audit bundle workflow:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-audit-bundle
```

Use `mdown-ocrpdf --doctor` before relying on OCR. OCR output is still a derived
view of the source, so keep `audit.md`, `conversion-report.md`, page anchors,
and manual spot checks.
