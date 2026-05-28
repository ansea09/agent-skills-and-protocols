# Scenario Boundaries

Use this reference before promising conversion quality, portability, or public
support. These are public, non-personal scenario classes. They describe expected
behavior and limits, not a guarantee that every document of that type converts
cleanly.

## Works Well

| Scenario | Why it fits | Expected result | Route |
| --- | --- | --- | --- |
| Trusted local DOCX, PPTX, XLS, XLSX, HTML, CSV, JSON, XML, text-like files, and ZIP archives containing supported local files | These are in the narrow core scope and use the pinned MarkItDown runtime. | Markdown suitable for reading, search, ingestion, or follow-up analysis. | `mdown input -o output.md`, then cheap verification with `wc`, `du`, and `sed`. |
| Trusted born-digital PDFs with mostly selectable text | Text extraction is the main need and the PDF is not primarily scanned or image-only. | Markdown text extraction, with quality dependent on the original PDF structure. | `mdown input.pdf -o output.md`; use `mdown-book` when page/image/link evidence matters. |
| Textbook-like born-digital PDFs where audit evidence matters more than layout reproduction | The book workflow is an audit bundle, not a layout reconstruction engine. | `content.md`, `audit.md`, `assets/`, `manifest.json`, and `conversion-report.md`. | `mdown-book source.pdf -o source-audit-bundle`. |
| Trusted scanned PDFs when OCR is explicitly needed and language data is installed | OCR is handled as a separate local preprocessing step. | A derived searchable OCR PDF plus a normal audit bundle after rerunning the book workflow. | `mdown-ocrpdf scanned.pdf -o scanned-ocr.pdf`, then `mdown-book scanned-ocr.pdf -o scanned-audit-bundle`. |
| Codex on macOS arm64 with rebuilt local runtimes | This is the maintained execution profile. | Supported install, doctors, and smoke selftests. | `scripts/install.sh`, optionally with `--hash-locked` for the maintained `macos-arm64-py313` profile. |
| Codex on Intel macOS with Python 3.12 for core and book workflows | This path has a separate Intel/macOS hash profile for Python 3.12. | Supported core and book install, doctors, and smoke selftests for the published `macos-intel-py312` profile. | `PYTHON=python3.12 DOC_TO_MD_HASH_PROFILE=macos-intel-py312 scripts/install.sh --hash-locked`, optionally with `--book`. |

## Works With Explicit Caveats

| Scenario | Caveat | Required expectation |
| --- | --- | --- |
| Large trusted local documents | Timeout and input-size limits are guardrails only. They do not cap memory, temporary storage, page count, or ZIP expansion. | Raise limits only for trusted sources and expect manual verification. |
| Mixed-language OCR | Tesseract language packs are external system data and are not rebuilt from the Python lockfile. | Choose a source-specific language string and run `mdown-ocrpdf --doctor` first. |
| Formula-heavy, table-heavy, or diagram-heavy textbooks | The audit bundle can expose quality risk, but it does not reconstruct formulas, tables, captions, vector diagrams, or image placement with high fidelity. | Treat output as a reviewable extraction bundle, not a publication-quality textbook conversion. |
| PDFs where links or image placement must appear inline in running Markdown | The current workflow records link and image evidence separately. | Use `manifest.json` and `audit.md`; do not promise inline placement. |
| OCR on Codex Intel macOS | The current public Intel hash profile covers core and book only. OCRmyPDF v17 currently requires `pikepdf>=10`, and no compatible macOS Intel wheel was found in the checked Python 3.12 wheel set. | Do not claim `--ocr --hash-locked` support until a reviewed Intel OCR profile exists. |
| Unlisted Python minor versions | Normal pinned install may succeed, but hash-locked reproducibility and regression evidence are profile-specific. | Treat profiles such as `macos-arm64-py312`, `macos-arm64-py314`, or `macos-intel-py313` as candidate/unverified until `references/python-profiles.md` lists them as supported. |
| WSL on Windows | Candidate path only. macOS venvs, wrappers, OCR binaries, and caches must not be reused. | Rebuild everything inside WSL and publish a WSL hash profile before claiming hash-locked support. |
| Claude Code on macOS | Experimental unless skill location and runtime paths are configured explicitly. | Set `CODEX_HOME`, `DOC_TO_MD_BIN_DIR`, and `DOC_TO_MD_TOOLS_DIR`, or use the `.codex` compatibility runtime. |
| Remote URL conversion | Blocked by default because MarkItDown may perform I/O with process privileges. | Use `--allow-remote` only for an explicit trusted remote conversion. |
| Advanced plugin, cloud, Azure, YouTube, audio, or LLM-backed image paths | Excluded from the public core runtime. | Install and enable these deliberately outside the default core; do not imply they work by default. |

## Not Supported Or Do Not Promise

| Scenario | Boundary |
| --- | --- |
| Native Windows PowerShell/CMD | Unsupported until separate Windows launchers, path handling, and install paths exist. |
| Hosted, shared, or server-side ingestion of untrusted documents | Wrapper root checks are not a sandbox. Use OS or container sandboxing before accepting untrusted input. |
| High-fidelity PDF layout reconstruction | The current design extracts text and audit evidence; it does not reproduce visual layout. |
| Automatic inline placement of extracted images, links, captions, formulas, or diagrams | The book workflow stores evidence separately in `audit.md`, `assets/`, and `manifest.json`. |
| Image-to-text or image description without a configured LLM/image workflow | The core wrapper has no LLM client configured, and image-only output may be empty. |
| Audio transcription, YouTube transcription, Azure conversion, or MarkItDown plugins by default | These are intentionally outside the core dependency set. |
| Copying venvs, caches, generated outputs, OCR PDFs, or machine-specific binaries between machines | Rebuild runtimes on the target machine and migrate only source skill files and approved local policy metadata. |
| Untrusted ZIP/PDF processing, decompression bombs, renderer exploits, or multi-tenant processing | Not solved by this skill. Use a separate sandboxed ingestion architecture. |

## Selection Rule

If a document fits both a "works well" row and a caveat or unsupported row, use
the more conservative row. For quality-sensitive PDFs, prefer audit-first. Run
OCR only when the user explicitly asks for OCR or audit evidence shows that OCR
is needed. Before external transfer, sanitize generated audit bundles or OCR
reports and still review document content, extracted assets, links, and metadata
manually.
