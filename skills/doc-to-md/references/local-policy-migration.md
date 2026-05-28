# Local Policy Migration

Use this when moving personal `doc-to-md` local policy notes to a new personal machine or to an approved work machine.

## What To Copy

Copy only source-like policy files that contain no secrets and no private source documents.

Typical examples:

- a private repository file such as `private/local-policies/doc-to-md.md`;
- small reviewed local policy notes;
- small reviewed templates that contain no private document content.

Install the public `doc-to-md` core separately from the public repository. The local policy file is advisory configuration for the operator or agent; it is not a second skill and does not replace the public core.

## What Not To Copy

Do not copy these as part of local policy migration:

- Python venvs under `${CODEX_HOME:-$HOME/.codex}/tools`;
- wrapper symlinks or binaries from `~/.local/bin`;
- caches, logs, `.fpf-update/`, or local state directories;
- generated Markdown files, OCR PDFs, audit bundles, reports, or extracted assets;
- private source documents or textbook fixtures;
- machine-specific Tesseract, Ghostscript, or Homebrew artifacts.

These are runtime dependencies, cache/state, or generated output layers. Rebuild or regenerate them on the target machine.

## Personal Mac Migration

1. Install the public `doc-to-md` core from the public repository.
2. Copy the private local policy file into the private repository or another approved private notes location.
3. Rebuild runtimes with `scripts/install.sh`; use `--book`, `--ocr`, or `--all` only when those workflows are needed.
4. Install external OCR tools such as Tesseract on the new machine.
5. Run:

```bash
mdown-doctor
mdown-book --doctor
mdown-ocrpdf --doctor -l eng+rus
```

Run the optional doctors only for workflows installed on that machine. Use `eng+rus` only when English/Russian OCR is part of the local policy and the language packs are installed.

## Work Machine Migration

Use the same technical steps as personal migration, but treat the local policy as company-reviewed configuration:

- get approval before copying personal policy notes;
- remove private documents, local paths, and secrets;
- rebuild runtimes from approved package sources;
- confirm the PyMuPDF AGPL/commercial licensing decision before installing the optional book workflow;
- keep generated personal outputs off the work machine unless explicitly allowed.

## Validation Gate

After migration, do not assume the policy works because files copied cleanly. The operational copy is valid only after the public core doctors pass and one small conversion test succeeds on the target machine.
