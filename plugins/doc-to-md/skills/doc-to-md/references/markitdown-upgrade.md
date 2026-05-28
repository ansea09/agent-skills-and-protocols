# MarkItDown Upgrade Lane

Use this reference for intentional MarkItDown converter upgrades. Do not fold
converter upgrades into routine PDF/file-type/OCR lock refreshes.

## Current Candidate Shape

The maintained public runtime is pinned by `requirements-core.txt`. A new
MarkItDown release must be handled as a dedicated reviewed change rather than a
routine drift refresh.

Do not adopt `magika 1.x` as an isolated refresh. Only accept `magika >=1`
when upstream MarkItDown package metadata allows it and the resolver selects a
compatible dependency graph.

The local monitor reports the current upstream maintenance signal:

```bash
mdown-markitdown-monitor --json
```

`no-action` is log-only. For `ready-for-lane` or `magika-unblocked`, automation
may prepare a branch and run the source gate when the repo worktree is clean:

```bash
mdown-prepare-markitdown-upgrade --json
```

Heartbeat/scheduler automation should call the script-owned output mode instead
of interpreting JSON in the automation prompt:

```bash
mdown-prepare-markitdown-upgrade --automation-output
```

For `pending` or `blocked`, do not upgrade until the blocker is understood.
Installed-copy promotion always requires explicit user approval after the branch
and gate results have been reviewed.

## Upgrade Branch Shape

Prepare a dedicated reviewed change for the converter upgrade. Keep the scope to
the converter dependency graph and expected output changes. Auto-prepare may do
this branch setup, but it must not promote the installed operational copy.

Suggested branch name format:

```text
codex/doc-to-md-markitdown-VERSION
```

Preview the resolver result:

```bash
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION'
```

Apply only on that dedicated change:

```bash
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply
```

If the resolver keeps `magika` on `0.6.x`, that is expected while MarkItDown
still declares a `0.6`-line constraint. If it tries to install `magika 1.x`
while MarkItDown still declares a `0.6`-line constraint, stop and do not force
the pins manually.

## Required Review

After applying the upgrade candidate:

```bash
bash scripts/install.sh --rebuild
mdown-doctor --json
python3 scripts/regression_corpus.py
python3 scripts/audit_bundle_regression.py
```

Review snapshot diffs for HTML, PDF, DOCX, XLS, XLSX, PPTX, CSV, JSON, XML, and
ZIP. For PDF-sensitive changes, also run at least one non-private real
born-digital PDF and inspect the generated Markdown manually.

Accepted output changes must update snapshots in the same reviewed change:

```bash
python3 scripts/regression_corpus.py --update
```

## Non-Goals

- Do not add Azure, YouTube, audio, plugins, LLM image description, or OCR
  plugins to the default core runtime as part of a MarkItDown upgrade.
- Do not add a high-fidelity textbook parser to core.
- If higher-quality textbook parsing is needed, create a separate experimental
  workflow with its own runtime, support matrix, threat model delta, and release
  gate.
- Do not claim a new platform hash profile unless that platform was rebuilt and
  tested separately.
