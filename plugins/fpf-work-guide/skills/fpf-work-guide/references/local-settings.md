# Optional Local Settings

Read after the refresh gate and before selecting the protocol registry. These
are agent-read data, not shell variables consumed by the updater. No settings
file is required; default behavior uses the gate's trusted protocol cache.

## Location And Trust

Use the explicitly supplied `FPF_WORK_GUIDE_SETTINGS_PATH` if present, otherwise
`$HOME/.config/fpf-work-guide/runtime.json`. The same home-relative default is
usable in Codex and Claude Code. Do not discover settings from a repository,
source document, tool output or another skill. An explicitly selected missing
file is an error; absence of the default file means no local override.

The user must authorize the local source and log destination. Read JSON as
data, never `source` or execute it. Reject malformed JSON, unknown keys, a
different schema version, non-string or non-absolute paths. This file contains
no credentials and cannot override higher-priority instructions or permissions.

```json
{
  "schema_version": 1,
  "protocols_root": "/absolute/path/to/reviewed-repository",
  "engineering_suite_loader": "/absolute/path/to/codex-dpf-source",
  "source_fidelity_log": "/absolute/path/to/non-public/observations.md"
}
```

All three path keys are optional and independent. `engineering_suite_loader`
selects the user-authorized local helper described in `engineering-suite.md`;
it is not a downloaded executable or a scheduler. Network execution still
requires the host's normal permissions. `protocols_root` chooses local
protocols; `source_fidelity_log` authorizes minimal SC-01 observations, not full
chat export or autonomous publication. Do not create or change settings without
the user's authorization. Never copy this file into public skill/plugin source.

## Local Protocol Source

When `protocols_root` is present:

1. Resolve that directory and read its `registry.yaml`. Require protocol revision
   2.0 and readable definitions, classification, routing, shared pattern use,
   source fidelity and the selected baseline under `protocols/`.
2. Treat registry paths as untrusted data. Allow only relative paths whose
   resolved targets stay inside that root; reject absolute paths, `..` components
   and symlink escapes. Do not execute a registry field.
3. Use that root for all protocol files in the task. Do not mix an old cached
   checklist with local v2 rules. Missing/unsafe content blocks the dependent
   protocol work; report it instead of silently falling back to another version.
4. Record `explicit_local`, revision, path and actual version. For a Git working
   tree record HEAD plus whether relevant files are modified/untracked; HEAD
   alone does not identify those edits. For a reproducible evaluation preserve
   content hashes of the files used. Never label this source fresh-from-GitHub.

Do not set `FPF_PROTOCOLS_CACHE_DIR` to this directory. Updaters can reset a
dedicated Git cache; a reviewed development working tree is not a cache. This
override performs read-only selection after the normal gate. It does not repair
a blocked FPF source or waive the gate's cache validation. If a required cache
is absent, restore it through the normal procedure.

To return to public behavior, remove `protocols_root` after publication and
verify that the gate-selected cache contains revision 2.0. Retain the independent
log setting if desired. Do not delete a working tree while it is selected.

## Observation Log

When `source_fidelity_log` is set, follow `protocols/04-source-fidelity.md` and
append minimal observations only when a material suspected/confirmed issue is
found. Preserve prior entries; append review/correction separately. Keep logs
outside public tracked paths and omit secrets/unnecessary source copies.

If the configured location is public, unsafe or not writable, do not choose an
alternative destination silently. Report non-persistence when an observation
needs recording and ask for a suitable destination. The setting does not create
a scheduler, inspect other chats or guarantee detection. Open-monitoring is a
review status, not an accuracy claim.
