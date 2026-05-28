# OCR Paths

Use this reference only when the user explicitly asks for OCR, scanned PDF
conversion, image text extraction, or higher-quality textbook conversion.

For uncertain textbook-like PDFs, use `references/workflow-profiles.md` first
and prefer audit-first unless the user already knows the source is scanned or
explicitly asks for OCR.

Re-check current versions and project status before installing any OCR path.
Do not install OCR dependencies into the core MarkItDown runtime.

## Candidate Routing

| Candidate | Best fit | Default? | Main cost |
| --- | --- | --- | --- |
| `markitdown-ocr` | MarkItDown-aligned LLM Vision OCR for embedded images and scanned pages | No | Young beta plugin, API cost, cloud/privacy |
| `OCRmyPDF` | Local preprocessing that adds a searchable OCR text layer to scanned PDFs | No | Requires Tesseract; uses pypdfium2 or Ghostscript for rasterization |
| `Docling` | Structured document parsing with Markdown/JSON export and OCR options | No | Bigger stack, overlaps the core converter |
| `Marker` | Book/paper-oriented PDF to Markdown with OCR/LLM options | No | GPL code and model-license constraints |
| `MinerU` | Heavy high-accuracy document parsing for complex PDFs and formulas | No | Large, fast-moving stack and custom license |
| `PaddleOCR` | Local multilingual OCR/document parsing engine | No | Heavy ML runtime and model management |

## Practical Recommendation

Start with `OCRmyPDF` for local scanned PDFs when privacy matters and the goal
is better extractable text before running `mdown-book`.

Default command shape:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-audit-bundle
```

`mdown-ocrpdf` defaults to `--skip-text`, `--deskew`, `--rotate-pages`,
`--output-type pdf`, language `eng`, `--timeout 3600`, and `--max-input-mb 1024`.
It uses a same-output lock and a temporary OCR PDF before replacing the final
output. Use `-l eng+rus` only for English/Russian OCR when the source language
is declared, detected, or plausible and the required Tesseract language data is
installed.

Run:

```bash
mdown-ocrpdf --doctor
mdown-ocrpdf --doctor --online
```

Use `--online` only when network access is allowed and dependency drift matters
for maintenance or publication decisions. Online drift is a maintainer signal
when the local OCR runtime still matches `requirements-ocr.lock.txt`.

OCR reports include local source, output, temporary paths, and command evidence
by default. For external transfer, generate a sanitized report:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf --sanitize-report
```

Or sanitize an existing OCR report:

```bash
mdown-ocrpdf --export-sanitized-report scanned-ocr.pdf.ocr-report.json --report scanned-ocr.public-report.json
```

For rebuilds, install from `requirements-ocr.lock.txt`. Use
`requirements-ocr.txt` only as the short top-level declaration when deliberately
refreshing the OCR runtime.

For deliberate lock refreshes, use `references/lock-refresh.md`. The maintained
OCR refresh keeps the top-level OCRmyPDF line within the v17 family
(`ocrmypdf>=17,<18`) and regenerates the transitive lock from a temporary venv.

The OCR preprocessor follows OCRmyPDF v17 requirements. For default PDF output,
the hard external OCR dependency is `tesseract >= 4.1.1`; PDF rasterization
needs Python `pypdfium2` or `Ghostscript >= 9.54`; `fpdf2`, `uharfbuzz`, and
`pikepdf` come from the Python OCR venv when OCRmyPDF is installed. `qpdf` CLI
is not a hard requirement in v17 because OCRmyPDF uses `pikepdf`. Ghostscript or
`verapdf` matters for PDF/A output. On macOS, OCRmyPDF's project documentation
recommends Homebrew's `brew install ocrmypdf` because it includes recommended
system dependencies.

Evaluate `markitdown-ocr` when inline OCR inside MarkItDown is more important
than local-only execution, and the user accepts API cost and OCR uncertainty.

Evaluate `Marker`, `MinerU`, `Docling`, or `PaddleOCR` only in a separate
experiment runtime when the source PDF has complex layout, formulas, or tables
that the core workflow cannot recover.

Never treat OCR output as source truth. Keep page anchors, low-text warnings,
and a conversion report.
