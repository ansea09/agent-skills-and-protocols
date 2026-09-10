# doc-to-md MarkItDown 0.1.7 Promotion Record

Status: passed locally on 2026-09-10.

## Change Identity

- Component: `doc-to-md` public core and installed operational copy
- Pull request: [#29](https://github.com/ansea09/agent-skills-and-protocols/pull/29)
- Source commit: `35465be` (`Prepare MarkItDown 0.1.7 upgrade`)
- Merge commit: `2957764`
- Runtime change: MarkItDown `0.1.6` to `0.1.7`
- Maintained profile: `macos-arm64-py313`, with a macOS 14 or newer floor
- Upstream Magika constraint: `magika~=0.6.1`; installed pin remains `0.6.3`

## Promotion Procedure

The candidate passed the source gate before merge. After merge, local `main`
was fast-forwarded to `origin/main`, the installed skill was synchronized from
the merged staged copy, and the core, book, and OCR runtimes were rebuilt from
the published hash-locked requirements.

Commands, normalized to portable environment variables:

```bash
scripts/validate-doc-to-md-release.sh --source
bash "${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/scripts/install.sh" --rebuild --all --hash-locked
DOC_TO_MD_CI_RUNTIME="${CODEX_HOME:-$HOME/.codex}/tools" scripts/validate-doc-to-md-release.sh --promotion
mdown-markitdown-monitor --json
```

## Evidence Observed

- Staged, plugin, and installed skill copies matched.
- Compatibility frontmatter matched `references/support-matrix.md`.
- The standard regression corpus passed for HTML, PDF, DOCX, XLS, XLSX,
  PPTX, EPUB, CSV, JSON, XML, and ZIP.
- EPUB LLM bundle and PDF audit-bundle regressions passed.
- Core, book, EPUB, and OCR doctor outputs passed their JSON Schemas.
- Installed core doctor reported MarkItDown `0.1.7`, Magika `0.6.3`, and a
  complete match with 38 pinned core packages.
- Installed book doctor passed with PyMuPDF `1.27.2.3`.
- Installed EPUB doctor passed.
- Installed OCR doctor passed with OCRmyPDF `17.4.2`, native arm64 Tesseract
  `5.5.2`, Ghostscript `10.07.1`, and the published OCR lock.
- The final upstream monitor signal was `no-action`: the local MarkItDown pin
  matched the latest upstream release at verification time.

## Evidence Boundary

This is evidence for one successful local promotion on the maintained
`macos-arm64-py313` profile. It is not certification for Intel macOS, Claude
Code, WSL, native Windows, other Python minors, or other machines.

Core and OCR doctors reported `warn` only because their optional online
outdated-package checks were not part of the promotion gate. The separate
upstream monitor did run online and confirmed MarkItDown `0.1.7` as current.
No `DOC_TO_MD_SCA_MODE=required` result is claimed by this record. Synthetic
regression fixtures provide compatibility evidence but do not prove conversion
quality for every real document.

Temporary CI runtimes and test outputs are not release artifacts. The durable
evidence is this record, the merged source, the PR history, exact requirement
pins, hash files, schemas, and regression fixtures.
