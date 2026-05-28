# Third Party Notices

This skill is a wrapper and workflow layer around third-party tools. Review the
upstream licenses before redistributing the skill or bundling dependencies.

## Core Runtime

- Microsoft MarkItDown: MIT license, Python package `markitdown`.
- The core runtime intentionally installs only the local document/data
  conversion dependencies declared in `requirements-core.txt`.
- Azure, YouTube, audio transcription, OCR plugins, and LLM-backed image
  description dependencies are excluded from the default core runtime.

## PDF Audit Bundle Runtime

- PyMuPDF: dual licensed under GNU AGPL 3.0 or Artifex commercial license.
- Keep PyMuPDF optional unless the distribution model is compatible with AGPL
  obligations or a commercial license is in place.
- The audit bundle is source-tethered metadata extraction, not high-fidelity PDF
  reconstruction.

## OCR Runtime

- OCRmyPDF: Python package used as an optional local OCR preprocessor.
- Tesseract OCR: external binary dependency required by OCRmyPDF.
- Ghostscript and/or other PDF tooling may be needed for specific OCRmyPDF
  output modes such as some PDF/A conversions.
- The OCR Python dependency graph may include packages with copyleft or
  review-required license metadata, including LGPL-family packages such as
  `fpdf2`, `img2pdf`, or image/PDF support libraries. Run
  `mdown-dependency-audit` and review the generated license inventory before
  redistributing an OCR runtime bundle.

## Redistribution Notes

- Do not imply Microsoft, Artifex, OCRmyPDF, or Tesseract sponsorship.
- Keep upstream license files, attribution, and version information available
  when redistributing dependency bundles.
- This file is a practical notice, not legal advice.
