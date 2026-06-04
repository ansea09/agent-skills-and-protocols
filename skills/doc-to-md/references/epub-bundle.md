# EPUB LLM Textbook Bundle

Use `mdown-epub` for trusted local EPUB textbooks when LLM analysis needs more
than simple reading-order Markdown. The workflow creates a runtime-neutral
bundle for Codex, Claude Code, and other local agent environments.

Simple EPUB conversion remains in the standard core route:

```bash
mdown book.epub -o book.md
```

Use the bundle route when images, footnotes, internal links, tables, MathML,
SVG, or chapter navigation matter:

```bash
mdown-epub book.epub -o book-epub-bundle
```

## Output Contract

Expected top-level outputs:

- `LLM_README.md` - agent-neutral reading instructions and the primary entrypoint.
- `content.md` - continuous reading-order text for initial LLM analysis.
- `llm-index.md` - compact route map for chapters and assets.
- `toc.md` - EPUB navigation and chapter-file map.
- `chapters/` - per-chapter Markdown files.
- `assets/` - extracted cover, images, SVG, MathML, and inline visual artifacts.
- `assets-index.md` - agent-readable catalogue of extracted assets and when to inspect them.
- `audit.md` - warnings, unsupported structures, and safety notes.
- `manifest.json` - machine-readable provenance, counts, chapters, assets, and warnings.
- `links.json` - machine-readable internal and external link records.
- `conversion-report.md` - human-readable conversion summary.

The primary LLM route is:

1. Read `LLM_README.md`.
2. Read `content.md`.
3. Use `toc.md` or `llm-index.md` to open focused files under `chapters/`.
4. Use `assets-index.md` and `audit.md` before answering questions that depend
   on diagrams, figures, images, formula images, MathML, SVG, media, table
   layout, or visual examples.

## What The Workflow Improves

Compared with simple EPUB conversion, `mdown-epub` improves:

- chapter discoverability;
- asset discoverability;
- internal-link traceability;
- footnote visibility;
- warnings for structures that are easy to lose silently;
- portability across local LLM runtimes because all bundle links are relative.

It does not automatically understand images, SVG, MathML, audio, video, or
complex visual layout. Those artifacts are surfaced for inspection.

## EPUB Structure Handling

The converter:

- reads `META-INF/container.xml`;
- finds and parses the OPF package document;
- extracts metadata;
- builds reading order from OPF `spine`;
- reads EPUB 3 `nav.xhtml` when present;
- reads EPUB 2 `toc.ncx` when present;
- converts spine XHTML files into chapter Markdown;
- rewrites local internal links toward chapter files;
- preserves external links without fetching them.

## XHTML Conversion Rules

The converter aims for LLM-readable Markdown, not publication-quality EPUB
rendering.

- Headings, paragraphs, lists, blockquotes, code, and simple tables are converted
  to Markdown through the core HTML conversion stack.
- Footnotes/endnotes detected through EPUB/ARIA/class/id markers are converted
  to Markdown footnotes when possible.
- Complex tables with nested tables, `rowspan`, or `colspan` are preserved as raw
  HTML fallback and reported in `audit.md`.
- Scripts and styles are removed.
- Remote assets are not fetched.

## Asset Rules

The converter extracts local assets referenced by chapters and the cover image
when declared.

For each asset, `assets-index.md` records:

- local bundle path;
- original EPUB item path;
- chapter context;
- nearby heading when available;
- alt/caption text when available;
- when an LLM or human should inspect the asset.

SVG and MathML are extracted and recorded, but not semantically converted.
Audio/video/embed/object/iframe content is recorded as unsupported and is not
executed or fetched.

## Safety Controls

`mdown-epub` is trusted-local by default and is not a sandbox.

Implemented guardrails:

- rejects URI source arguments;
- rejects ZIP paths with absolute paths, drive-qualified paths, or `..`;
- rejects ZIP symlink entries;
- rejects encrypted EPUB members;
- rejects EPUBs with `META-INF/encryption.xml`;
- enforces input archive size, file count, and total unpacked size limits;
- does not fetch remote assets;
- does not execute JavaScript;
- writes through a staging directory and same-output lock;
- `--force` replaces only known generated bundle artifacts.

Default limits:

```text
DOC_TO_MD_EPUB_MAX_INPUT_MB=512
DOC_TO_MD_EPUB_MAX_FILES=4096
DOC_TO_MD_EPUB_MAX_UNPACKED_MB=2048
```

Raise limits only for trusted local EPUBs.

## Portability Contract

The output bundle is runtime-neutral. It must not depend on:

- Codex-only `plugin://` links;
- Claude-only paths;
- absolute local paths;
- shell-specific navigation;
- hidden runtime state;
- automatic asset scanning by the agent.

Agents should start from `LLM_README.md`, then use relative paths inside the
bundle.

## Diagnostics

Run:

```bash
mdown-epub --doctor
mdown-epub --doctor --json
```

The doctor uses the core runtime and checks the EPUB dependencies from the core
requirements profile. It does not install packages.

## Quality Boundary

Use this workflow when the goal is LLM analysis of textbook content, not
publication reconstruction. For higher fidelity than this bundle can provide,
create a separate experimental workflow with its own runtime, regression corpus,
and release gate instead of expanding the public core.
