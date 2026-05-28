# Maintenance Monitors

Use this reference for the weekly upstream check around Microsoft MarkItDown.
The monitors are maintenance signals, not unattended upgrade systems.

## MarkItDown Scope

The MarkItDown monitor checks:

- latest MarkItDown release metadata from PyPI and, when available, GitHub;
- package metadata `requires_dist`;
- the upstream constraint on `magika`;
- local `requirements-core.txt`;
- whether `references/markitdown-upgrade.md` contains stale current-candidate
  wording.

The monitor must not edit runtime pins, hash files, wrappers, skill docs,
installed runtimes, or generated regression snapshots. The only intended writes
are local maintenance status/state files.

Default local files:

```text
${CODEX_HOME:-$HOME/.codex}/state/doc-to-md/markitdown-upstream-status.md
${CODEX_HOME:-$HOME/.codex}/state/doc-to-md/markitdown-upstream-state.json
```

Override them with `DOC_TO_MD_MAINTENANCE_STATUS`,
`DOC_TO_MD_MAINTENANCE_STATE`, or `DOC_TO_MD_STATE_DIR`.

For read-only CI, source validation, or plugin validation, use `--no-write`.
The monitor still emits JSON and records write failures in the payload instead
of making `--json` unusable in a read-only environment.

## PDF/OCR Dependency Scope

The dependency monitor checks newer upstream releases for the PDF extraction
and OCR dependency areas that are intentionally not auto-upgraded:

- core PDF extraction packages such as `pdfminer.six`, `pdfplumber`, and
  `pypdfium2`;
- the optional book package `PyMuPDF`;
- the optional OCR graph led by `OCRmyPDF`, plus key OCR PDF packages such as
  `pikepdf` and `pypdfium2`.

It does not edit pins or hash files. A newer OCR/PDF package is a maintenance
signal to review `references/lock-refresh.md`, run the explicit lock refresh
lane, and compare doctors/regression evidence.

Default local files:

```text
${CODEX_HOME:-$HOME/.codex}/state/doc-to-md/dependency-maintenance-status.md
${CODEX_HOME:-$HOME/.codex}/state/doc-to-md/dependency-maintenance-state.json
```

Override them with `DOC_TO_MD_DEPENDENCY_STATUS`,
`DOC_TO_MD_DEPENDENCY_STATE`, or `DOC_TO_MD_STATE_DIR`.

## Signals

| Signal | Meaning | User notification |
| --- | --- | --- |
| `no-action` | Local MarkItDown pin matches upstream and the upgrade reference is not stale. | No thread notification; log/status file only. |
| `pending` | Maintenance action is needed, but the lane is not yet cleanly startable or upstream evidence is incomplete. | Notify. |
| `blocked` | Upstream release or metadata violates the current policy. | Notify and do not upgrade. |
| `ready-for-lane` | A newer MarkItDown release can enter the explicit reviewed upgrade lane. | Auto-prepare a branch when the repo worktree is clean; notify with branch/gate status. |
| `magika-unblocked` | Upstream MarkItDown metadata allows `magika >=1`. | Auto-prepare a dedicated MarkItDown branch when the repo worktree is clean; notify with branch/gate status. |

The monitor should avoid repeated noise. If the same actionable upstream
fingerprint was already notified, log it without a new thread notification. If
the user declined the same fingerprint, do not repeat the support-risk warning
until upstream changes again.

## Commands

Check and write the default status/state files:

```bash
mdown-markitdown-monitor --json
```

Record approval before starting the explicit upgrade lane:

```bash
mdown-markitdown-monitor --record-decision approved
```

Prepare an upgrade branch without installed promotion:

```bash
mdown-prepare-markitdown-upgrade --json
```

Check PDF/OCR dependency drift without changing files:

```bash
mdown-dependency-monitor --json --no-write
```

Run the dependency license/SCA audit used by the release gate:

```bash
mdown-dependency-audit \
  --requirements core="${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/requirements-core.txt" \
  --requirements book="${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/requirements-book.txt" \
  --requirements ocr="${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md/requirements-ocr.lock.txt" \
  --python core="${CODEX_HOME:-$HOME/.codex}/tools/markitdown-core-venv/bin/python" \
  --python book="${CODEX_HOME:-$HOME/.codex}/tools/doc-to-md-book-venv/bin/python" \
  --python ocr="${CODEX_HOME:-$HOME/.codex}/tools/doc-to-md-ocr-venv/bin/python" \
  --json
```

For a scheduler or heartbeat automation, use the script-owned notification
output. It prints nothing for `no-action` and prints a complete user-facing
message for actionable states:

```bash
mdown-prepare-markitdown-upgrade --automation-output
```

Record a decline or deferral:

```bash
mdown-markitdown-monitor --record-decision declined
```

Clear the stored decision for the current local state:

```bash
mdown-markitdown-monitor --record-decision clear
```

## Auto-Prepare Boundary

For `ready-for-lane` and `magika-unblocked`, automation may prepare a repository
upgrade branch and run the source release gate. It must not touch the installed
operational copy, rebuild installed runtimes, copy files to `${CODEX_HOME}`, or
promote wrappers.

Auto-prepare must require a clean repository worktree. If the repo is dirty,
write/report `blocked` with the current `git status --short` evidence instead
of mixing the upgrade with unrelated changes.

The branch shape is:

```text
codex/doc-to-md-markitdown-VERSION
```

The auto-prepare command may run:

```bash
mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply
scripts/validate-doc-to-md-release.sh --source
```

Installed-copy promotion remains a separate explicit user decision after the
branch, diff, source gate, doctors, and regression output have been reviewed.

If the user declines, show a short warning: current pinned conversions may keep
working, but support risk grows if MarkItDown updates are repeatedly skipped.
Do not repeat that warning for the same upstream fingerprint.
