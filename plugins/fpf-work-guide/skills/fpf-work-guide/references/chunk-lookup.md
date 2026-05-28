# FPF Chunk Lookup

Use this reference when `FPF_CHUNKS_MODE` allows chunk reads.

## Mode Semantics

- `FPF_CHUNKS_STATUS=ready` and `FPF_CHUNKS_MODE=chunk-first`: use chunks as the primary FPF source.
- `FPF_CHUNKS_STATUS=degraded` and `FPF_CHUNKS_MODE=chunk-first`: required chunk entrypoints exist, but optional metadata is missing. Use the index and direct paths.
- `FPF_CHUNKS_STATUS=stale` and `FPF_CHUNKS_MODE=full-spec-first`: use `FPF_SPEC_PATH` first. Chunks exist, but their declared source commit does not match `FPF_SPEC_COMMIT`.
- `FPF_CHUNKS_MODE=full-spec-fallback`: do not rely on chunk layout. Use targeted `rg` and `sed` reads against `FPF_SPEC_PATH`.
- `FPF_CHUNKS_MODE=blocked`: do not claim FPF-backed reasoning until the user provides a valid source or allows a fetch.

## Layout Contract

Treat the root-level `fpf-chunks-layout.env` file as the optional layout contract manifest. If it exists, it is the source of truth for the chunk layout version and canonical entrypoints. If it does not exist, use the legacy layout contract:

- `fpf_chunks/000-index.md`
- `fpf_chunks/by_pattern`
- `fpf_chunks/by_section`
- `fpf_chunks/non_patterns`

The layout manifest format is shell-independent key/value text. Do not source it.

Required keys:

```text
FPF_CHUNKS_LAYOUT_VERSION=1
FPF_CHUNKS_ROOT=fpf_chunks
FPF_CHUNKS_INDEX=000-index.md
FPF_CHUNKS_METADATA=metadata.jsonl
FPF_CHUNKS_BY_PATTERN=by_pattern
FPF_CHUNKS_BY_SECTION=by_section
FPF_CHUNKS_NON_PATTERNS=non_patterns
```

Manifest paths must be non-empty relative paths, must not start with `/`, must not contain `..`, and must resolve under `FPF_CHUNKS_PATH`.

## Source Commit Check

Chunk lookup is primary only when both the chunk source commit and `FPF_SPEC_COMMIT` can be determined and they match.

The refresh scripts determine `FPF_CHUNKS_SOURCE_COMMIT` from:

1. `Commit SHA: \`...\`` in `FPF_CHUNKS_INDEX_PATH`;
2. `"commit_sha": "..."` in `FPF_CHUNKS_METADATA_PATH`.

If either commit is missing or unknown, use full-spec fallback. If both commits are known and differ, use full-spec-first mode and disclose stale chunks when relevant.

## Pattern Lookup

When selecting relevant patterns yourself:

1. Read `FPF_CHUNKS_INDEX_PATH` first.
2. Select the minimal relevant pattern IDs or cluster IDs for the task.
3. Read only the matching chunk files.
4. If the index is missing and `FPF_CHUNKS_MODE=full-spec-fallback`, search `FPF_SPEC_PATH` directly.

When a specific pattern ID is known:

1. Prefer `FPF_CHUNKS_BY_PATTERN_DIR/<pattern-id>.md`.
2. If absent, search `FPF_CHUNKS_INDEX_PATH`.
3. Use `FPF_CHUNKS_METADATA_PATH` only as a fallback hint or diagnostic aid.
4. Only follow lookup paths that are relative, do not start with `/`, do not contain `..`, and resolve under `FPF_CHUNKS_PATH`.
5. If a matching file exists only in `FPF_CHUNKS_NON_PATTERNS_DIR`, say that the pattern title exists but the body is unavailable.
6. If chunk lookup fails, use `FPF_SPEC_PATH` fallback and disclose the fallback when the answer depends on FPF.

When a cluster or section is requested:

1. Prefer sorted files under `FPF_CHUNKS_BY_SECTION_DIR/<cluster-id>/`.
2. If that directory is absent, try `FPF_CHUNKS_BY_PATTERN_DIR/<cluster-id>.md`.
3. If both fail, use targeted full-spec fallback.

Safe full-spec fallback search pattern:

```bash
rg -n "A\\.1\\.1|A\\.1 |A\\.2|A\\.2\\.1|A\\.2\\.2|A\\.2\\.4|A\\.2\\.6|A\\.3\\.1|A\\.3\\.3|A\\.4|A\\.6\\.P|A\\.7|A\\.10|A\\.11|A\\.15|C\\.7|C\\.27|C\\.28|E\\.17" "$FPF_SPEC_PATH"
```
