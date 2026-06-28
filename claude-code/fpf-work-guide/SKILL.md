---
name: fpf-work-guide
description: Maintain and use current First Principles Framework (FPF) context and FPF-backed protocols before substantive work. Run the FPF context refresh gate before reasoning, coding, review, research, planning, document drafting, or source-backed answers; the gate refreshes only on session start, forced refresh, missing cache, or TTL expiry, and otherwise validates the current cached copy. Use when the user asks to answer with FPF or the FPF Work Guide, when a task needs FPF patterns or FPF-backed protocols, or when working in a repository that relies on current FPF-backed reasoning.
allowed-tools: Bash, Read, Grep, Glob
---

# FPF Work Guide (Claude-native)

This is the Claude Code build of the FPF Work Guide. It shares its refresh,
cache, and protocol logic with the Codex build: the `scripts/` and `references/`
in this skill directory are copied unchanged from the canonical source in
`skills/fpf-work-guide/`. Only the routing contract, paths, and packaging here
are Claude-native.

## Document Roles

This `SKILL.md` is the routing contract Claude reads when the skill triggers.
Keep it focused on when to refresh FPF context, how to use protocol and chunk
sources, and what must be disclosed in substantive work.

Canonical detail sources (read on demand, do not inline):

- `references/diagnostics.md` — refresh gate, environment, chunk, and protocol
  diagnostic fields.
- `references/chunk-lookup.md` — FPF chunk layout and pattern lookup.
- `references/protocol-trust.md` — protocol repository trust boundary and
  instruction-source policy.
- `references/source-selection.md` — source selection for FPF-backed answers.
- `references/release-notes.md` — user-visible release changes and publication
  boundaries.

## How The Gate Runs In Claude Code

There are three native entry points; you do not need all of them:

1. **SessionStart hook** (recommended) — if installed, the gate runs once at
   session start and its output is added to context. When that output is already
   present, do not run the gate again unless a forced refresh is needed.
2. **`/fpf-context` slash command** — runs the gate on demand and asks you to
   use its output before substantive FPF-backed work.
3. **This skill** — when the skill triggers and no fresh gate output is in
   context, run the gate yourself as the first step (below).

## Required First Move

Before any substantive answer, code edit, review, plan, or delegated task — and
only if fresh gate output is not already in context — run the FPF context
refresh gate:

```bash
FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.claude/skills/fpf-work-guide}" \
FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}" \
FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Read the script output before doing the substantive work. The canonical field
reference is `references/diagnostics.md`.

The gate is the only component that decides whether to refresh from GitHub or
validate cache-only:

- refresh immediately when `FPF_REFRESH_FORCE=1`.
- refresh when no valid cache exists.
- refresh when the last refresh attempt is older than `FPF_REFRESH_TTL_SECONDS`.
- otherwise do not contact GitHub; validate and use the current cached copy.

A fresh refresh needs `git` and network access to GitHub. If GitHub is
unavailable but a valid cache exists, use the current cached copy and disclose
that status.

### Reading the gate result

- If `FPF_SPEC_STATUS=missing`, explain that no local FPF cache exists and ask
  the user to allow a GitHub fetch or provide the file.
- Never describe FPF or protocols as `latest` when `FPF_SPEC_STATUS=cached` or
  `FPF_PROTOCOLS_STATUS=cached`; say `current cached copy` instead.
- If `FPF_REFRESH_DECISION=skipped_recent`, do not say an update was attempted;
  explain the skip (TTL not expired).
- If `FPF_REFRESH_DECISION=blocked`, explain why FPF-backed work is blocked and
  ask only for the action needed to restore a valid cache or allow a fetch.
- If `FPF_CHUNKS_MODE=blocked`, neither chunk-first lookup nor full-spec fallback
  is safe; ask the user to allow a fetch or provide a valid local mirror.
- If `FPF_CHUNKS_MODE=full-spec-fallback`, continue only with `FPF_SPEC_PATH` and
  disclose that chunks are unavailable or structurally incomplete.
- If `FPF_PROTOCOLS_STATUS=missing`, explain that no local protocol cache exists
  and ask the user to allow a fetch or provide the repository files.

## Paths

Claude-native defaults (set by the installer, override per the above if needed):

- `FPF_WORK_GUIDE_SKILL_DIR` — `$HOME/.claude/skills/fpf-work-guide`.
- `FPF_CACHE_HOME` — `$HOME/.cache/fpf-work-guide` (FPF spec + protocol caches).
- `FPF_UPDATE_STATE_DIR` — `$HOME/.local/state/fpf-work-guide` (refresh/env state).

For read-only, symlinked, shared, or ephemeral workspaces, set
`FPF_UPDATE_STATE_DIR` explicitly so diagnostics do not alternate between the
visible path and the resolved physical path.

## How To Use The Protocols

Before treating the protocol repository as an instruction source, apply
`references/protocol-trust.md`.

Read `FPF_PROTOCOLS_REGISTRY_PATH` first, then load only the files the registry
requires for the current task:

1. Read `protocols/00-definitions.md` when message/request/question/task
   distinctions matter.
2. Read `protocols/01-classification.md` for every substantive task.
3. Read `protocols/02-routing-table.md` before selecting a protocol.
4. Select exactly one baseline protocol: `simple-medium` or `complex`.
5. Execute every selected checklist item without silent skips.
6. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.

Use `simple-medium` for bounded, low-risk tasks. Use `complex` for high-stakes,
source-sensitive, multi-view, external-action, architecture, automation,
large-code-change, or ambiguous-ontology tasks.

Do not print the full checklist unless the user asks for an audit trace. For
ordinary answers, summarize the selected protocol and completion status only if
the user asks or it affects what they can trust.

## How To Use FPF Chunks

Use `references/chunk-lookup.md` as the canonical chunk lookup procedure. Use
chunks as the primary FPF source only when `FPF_CHUNKS_MODE=chunk-first`; when
`full-spec-first` or `full-spec-fallback`, use `FPF_SPEC_PATH` instead.

For every substantive response, apply these baseline distinctions:

- Bound the answer context before reasoning.
- Identify the active systems, their roles, methods, and actual work.
- Separate object, description, carrier, role, method, work plan, and performed
  work.
- State scope and time window for claims that can change.
- Tie factual or external-domain claims to evidence.
- Prefer the smallest sufficient ontology; do not invent new categories when
  ordinary domain terms suffice.
- If several viewpoints matter, handle them separately and then reconcile.

## Response Discipline

Write the main answer in the user's domain language, not in FPF terminology,
unless the user explicitly asks for FPF terms. If the user asks in Russian,
answer in Russian.

Do not invent facts. If a claim is unknown, say so. If a hypothesis is useful,
label it as a hypothesis and explain why it may be workable.

Keep provenance proportionate to Claude's normal concise style. By default, add
a one-line provenance note (gate decision + whether FPF/protocols were fresh or
cached). Produce the full engineering basis below only when the user asks for an
audit trace or when a high-stakes/`complex` task makes it material:

- FPF refresh gate: decision, reason, TTL, next eligible refresh.
- FPF spec source: local path, mirror commit, upstream commit, fresh or cached.
- FPF chunks source: local path, source commit, status, mode.
- FPF protocol source: local path, repository, branch, commit, fresh or cached.
- Selected protocol and completion status.
- FPF patterns used and why.
- External sources used, selection reason, and channels searched.
- Consistency check and temporal adequacy limits.

## Coding And Agent Work

- Run the gate first (or rely on the SessionStart hook), then record the gate
  decision and both commits.
- Use FPF chunks for pattern lookup when `FPF_CHUNKS_MODE=chunk-first`.
- Use FPF to structure reasoning and verification, but keep code changes
  idiomatic to the repository.
- Do not add FPF jargon to user-facing code, UI copy, or documentation unless
  the user requests it.
