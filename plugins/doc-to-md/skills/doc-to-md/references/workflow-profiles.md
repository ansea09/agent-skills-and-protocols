# Workflow Profiles

This reference explains how to choose the `doc-to-md` conversion path for common public scenarios.

Workflow profiles are public method-selection guidance. They are not private
defaults. A user's private local policy may prefer one profile for their own
materials, but the public skill should still select the profile from the source
file, user request, and quality risk.

## Standard Local Document Profile

Use this profile when the input is a trusted local file and ordinary text extraction is expected to be sufficient.

Typical inputs:

- DOCX, PPTX, XLS, XLSX;
- HTML, CSV, JSON, XML, text-like files;
- ZIP archives containing supported local files;
- born-digital PDFs without scanned-page, image-heavy, or link-traceability concerns.

Command shape:

```bash
mdown input-file -o output-file.md
```

Verification:

```bash
wc -l output-file.md
du -h output-file.md
sed -n '1,80p' output-file.md
```

Run `mdown-doctor --output output-file.md` when the output is empty, tiny, malformed, or otherwise questionable.

## Textbook Audit + OCR Profile

Use this profile when the user is converting trusted local textbook-like PDFs or any PDF where silent quality loss would be costly.

Typical triggers:

- scanned PDFs;
- low-text pages;
- formula-heavy or diagram-heavy pages;
- embedded raster images;
- important links;
- mixed language OCR;
- uncertain extraction quality;
- need to report image, link, page, and warning evidence.

When the user has not specified whether OCR is needed and quality risk is
material, prefer audit-first: create the audit bundle, inspect warnings, then
run OCR only when evidence supports it. If the user already knows the PDF is
scanned and explicitly asks for OCR, the OCR step may come first, but preserve
the derived OCR PDF and report that the output is not source truth.

Default command sequence:

```bash
mdown-book source.pdf -o source-audit-bundle
```

Inspect:

- `source-audit-bundle/content.md`;
- `source-audit-bundle/audit.md`;
- `source-audit-bundle/conversion-report.md`;
- `source-audit-bundle/manifest.json`.

If OCR is needed, write an OCR PDF separately, then rerun the audit bundle:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf
mdown-book scanned-ocr.pdf -o scanned-ocr-audit-bundle
```

For mixed-language OCR, choose a Tesseract language string that matches the detected or declared languages. For English/Russian material:

```bash
mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf -l eng+rus
```

Use `-l eng+rus` only when English/Russian content is declared, detected, or plausible and the language packs are installed. Do not treat it as a universal default for all mixed-language documents.

## Preservation Rule

Do not delete failed conversions, OCR PDFs, audit bundles, extracted assets, or comparison artifacts unless the user explicitly asks to clean them.

Preserving these outputs supports:

- quality comparison before and after OCR;
- diagnosis of low-text or image-heavy pages;
- reproducibility of the conversion path;
- user review before destructive cleanup.

## Reporting Rule

For textbook/audit/OCR conversions, report:

- output paths;
- whether OCR was used;
- low-text page warnings;
- extracted image count;
- link count;
- major warnings from `conversion-report.md`;
- any missing OCR language packs or doctor failures.
