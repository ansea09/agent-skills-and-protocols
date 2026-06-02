# FPF Work Guide Diagnostics

Use this reference after running the refresh gate.

## Core Gate Fields

- `FPF_REFRESH_DECISION`: `attempted`, `skipped_recent`, or `blocked`.
- `FPF_REFRESH_REASON`: why the gate attempted, skipped, or blocked.
- `FPF_REFRESH_TTL_SECONDS`: refresh TTL, normally `21600`.
- `FPF_REFRESH_LOCK_STALE_SECONDS`: stale lock recovery threshold, normally `900`.
- `FPF_REFRESH_LAST_ATTEMPT_AT`: last refresh attempt timestamp, or `none`.
- `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`: file that supplied the previous refresh attempt timestamp, or `none`.
- `FPF_REFRESH_NEXT_ELIGIBLE_AT`: next TTL refresh timestamp, or `none`.
- `FPF_REFRESH_STATE_PATH`: refresh state file that controlled the decision.
- `FPF_REFRESH_AUTO_STATE_PATH`: optional secondary refresh-state file, emitted only when `FPF_REFRESH_AUTO_STATE_FILE` was explicitly set.
- `FPF_REFRESH_DETAIL`: extra gate diagnostic when present.

## Environment Fields

Environment fields are emitted only when the environment check or probe needs to report something.

- `FPF_ENV_CHECK_STATUS`: `ok`, `degraded`, or `blocked`.
- `FPF_ENV_CHECK_REASON`: machine-readable environment reason.
- `FPF_ENV_CHECK_STATE_STATUS`: `missing`, `changed`, `same`, or `recorded`.
- `FPF_ENV_CHECK_STATE_PATH`: environment state file path.
- `FPF_ENV_CHECK_SKILL_DIR`: resolved local skill directory.
- `FPF_ENV_CHECK_CACHE_HOME`: cache root used by default.
- `FPF_ENV_CHECK_SPEC_CACHE_DIR`: resolved FPF specification cache directory.
- `FPF_ENV_CHECK_PROTOCOLS_CACHE_DIR`: resolved protocol cache directory.
- `FPF_ENV_CHECK_STATE_DIR`: resolved environment state directory.
- `FPF_ENV_CHECK_PATH_POLICY_MODE`: `codex-defaults`, `portable-explicit`, or `mixed`.
- `FPF_ENV_CHECK_OS_NAME`, `FPF_ENV_CHECK_OS_ARCH`: detected platform values.
- `FPF_ENV_CHECK_SHELL_KIND`: `bash` or `powershell` when emitted.
- `FPF_ENV_CHECK_GIT_STATUS`: `available` or `missing`.
- `FPF_ENV_CHECK_CACHE_STATUS`: `ready`, `partial`, or `missing`.
- `FPF_ENV_CHECK_SUMMARY`, `FPF_ENV_CHECK_ACTION`, `FPF_ENV_CHECK_CONSEQUENCE`: user-facing environment diagnostic.

Portable doctor fields use the `FPF_PORTABLE_CHECK_*` prefix.

## FPF Specification Fields

- `FPF_SPEC_PATH`: local path to `FPF-Spec.md`.
- `FPF_SPEC_REPO_COMMIT`: mirror repository commit used for the answer, or `unknown`.
- `FPF_SPEC_SOURCE_COMMIT`: upstream FPF commit that produced `FPF-Spec.md`, or `unknown`.
- `FPF_SPEC_SOURCE_COMMIT_SOURCE`: how the source commit was determined: `env`, `metadata`, `inferred-from-aligned-mirror-paths`, or `unknown`.
- `FPF_SPEC_COMMIT`: backward-compatible alias for `FPF_SPEC_REPO_COMMIT`.
- `FPF_SPEC_STATUS`: `fresh`, `cached`, or `missing`.
- `FPF_SPEC_WARNING`: warning to disclose when cached content is used because refresh failed.
- `FPF_SPEC_DETAIL`: blocking or diagnostic detail.

If `FPF_SPEC_STATUS=missing`, FPF-backed work is blocked until the user allows a fetch or provides a valid local mirror.

## Chunk Fields

- `FPF_CHUNKS_LAYOUT_MANIFEST_PATH`: optional chunk layout manifest path.
- `FPF_CHUNKS_LAYOUT_STATUS`: `legacy`, `ready`, or `invalid`.
- `FPF_CHUNKS_LAYOUT_SOURCE`: `legacy-defaults` or `manifest`.
- `FPF_CHUNKS_LAYOUT_VERSION`: declared layout version, or `legacy-1`.
- `FPF_CHUNKS_PATH`: canonical chunks root.
- `FPF_CHUNKS_INDEX_PATH`: canonical chunk index.
- `FPF_CHUNKS_METADATA_PATH`: optional chunk lookup metadata.
- `FPF_CHUNKS_BY_PATTERN_DIR`: pattern chunk directory.
- `FPF_CHUNKS_BY_SECTION_DIR`: section or cluster chunk directory.
- `FPF_CHUNKS_NON_PATTERNS_DIR`: chunks without pattern bodies.
- `FPF_CHUNKS_SOURCE_COMMIT`: upstream FPF commit declared by chunk metadata or index, or `unknown`.
- `FPF_CHUNKS_STATUS`: `ready`, `degraded`, `stale`, or `missing`.
- `FPF_CHUNKS_MODE`: `chunk-first`, `full-spec-first`, `full-spec-fallback`, or `blocked`.
- `FPF_CHUNKS_WARNING`: warning to disclose when chunk lookup is degraded or stale.
- `FPF_CHUNKS_DETAIL`: concrete missing, degraded, or stale chunk detail.

If `FPF_CHUNKS_STATUS=stale`, use `FPF_SPEC_PATH` first. Do not treat chunks as the primary FPF source unless the user explicitly asks to inspect the stale chunk cache. Chunks are fresh only when `FPF_CHUNKS_SOURCE_COMMIT` matches `FPF_SPEC_SOURCE_COMMIT`; they do not need to match `FPF_SPEC_REPO_COMMIT`.

## Protocol Fields

- `FPF_PROTOCOLS_PATH`: local path to the current or cached protocol repository.
- `FPF_PROTOCOLS_REGISTRY_PATH`: local path to `registry.yaml`.
- `FPF_PROTOCOLS_REPO_URL`: configured protocol repository URL.
- `FPF_PROTOCOLS_BRANCH`: configured protocol repository branch.
- `FPF_PROTOCOLS_REMOTE_URL`: `origin` remote URL reported by the local cache repository, or `none`.
- `FPF_PROTOCOLS_CACHE_TRUST_STATUS`: cache trust evidence: `marker-matches`, `remote-matches`, `remote-matches-marker-mismatch`, `marker-mismatch`, `explicit-allow`, `no-git-cache`, or `unverified`.
- `FPF_PROTOCOLS_COMMIT`: protocol repository commit used for the answer, or `unknown`.
- `FPF_PROTOCOLS_STATUS`: `fresh`, `cached`, or `missing`.
- `FPF_PROTOCOLS_WARNING`: warning to disclose when cached protocols are used because refresh failed.
- `FPF_PROTOCOLS_DETAIL`: blocking or diagnostic detail when present.

If `FPF_PROTOCOLS_STATUS=missing`, protocol selection is blocked until the user allows a fetch or provides the repository files.

If `FPF_PROTOCOLS_CACHE_TRUST_STATUS=marker-mismatch`, `unverified`, or `remote-matches-marker-mismatch`, disclose the trust status when protocol instructions affect the answer or planned action. `remote-matches-marker-mismatch` allows cache operations because the remote matches, but it still means the marker contents should be repaired on the next successful refresh.

## User-Facing Diagnostics

Show a diagnostic only when it affects what the user can trust or decide.

Use this shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Diagnostic triggers:

- refresh was attempted, GitHub was unavailable, and cache was used;
- no valid local cache exists;
- refresh state is unavailable;
- environment is blocked or degraded in a way that affects freshness or trust;
- chunks are missing, structurally incomplete, stale, or unsafe;
- full-spec fallback or full-spec-first mode is used;
- protocols are missing;
- protocol cache provenance is ambiguous or marker contents do not match the configured repository;
- unsafe paths or metadata conflicts affected lookup.

Routine TTL skips belong in the engineering basis, not as prominent warnings.

`FPF_REFRESH_REASON=sandbox-network-disabled` means Codex is running with
`CODEX_SANDBOX_NETWORK_DISABLED=1`. The gate intentionally used cache-only
validation instead of attempting a GitHub refresh from inside the sandbox. This
is not a GitHub outage. A launcher, hook, or other external refresher may still
refresh the cache outside the sandbox.

This state suppresses repeated in-sandbox refresh attempts, but a later
network-enabled gate run can still refresh instead of treating the sandbox
record as successful TTL freshness evidence.

If `FPF_REFRESH_DECISION=skipped_recent` appears with this reason, do not explain
the skip as an ordinary TTL skip. The user-facing cause is still the Codex
sandbox network boundary.
