#!/usr/bin/env bash
set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_dir="$repo_root/skills/fpf-work-guide"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/fpf-work-guide-validate.XXXXXX")"

trap 'rm -rf "$tmp_root"' EXIT

aligned_sha="1111111111111111111111111111111111111111"
stale_spec_sha="2222222222222222222222222222222222222222"
stale_chunks_sha="3333333333333333333333333333333333333333"
unknown_chunks_sha="4444444444444444444444444444444444444444"
protocols_sha="5555555555555555555555555555555555555555"
expected_spec_url="https://github.com/ansea09/fpf-spec-mirror.git"
expected_protocols_url="https://github.com/ansea09/codex-skills-and-protocols.git"
wrong_url="https://example.invalid/not-the-cache.git"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

field_value() {
  key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); found = 1 } END { exit(found ? 0 : 1) }'
}

assert_field() {
  output="$1"
  key="$2"
  expected="$3"
  actual="$(printf '%s\n' "$output" | field_value "$key" 2>/dev/null || true)"
  if [ "$actual" != "$expected" ]; then
    fail "$key expected '$expected' but got '${actual:-<missing>}'"
  fi
}

assert_field_present() {
  output="$1"
  key="$2"
  actual="$(printf '%s\n' "$output" | field_value "$key" 2>/dev/null || true)"
  if [ -z "$actual" ]; then
    fail "$key expected to be present"
  fi
}

assert_contains() {
  output="$1"
  expected="$2"
  if ! printf '%s\n' "$output" | grep -Fq "$expected"; then
    fail "expected output to contain '$expected'"
  fi
}

make_fake_git() {
  fake_bin="$tmp_root/fake-bin-$1"
  fake_sha="$2"
  remote_url="$3"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/git" <<EOF
#!/usr/bin/env sh
case " \$* " in
  *" --version "*|" --version ")
    printf '%s\n' "git version 2.50.1"
    exit 0
    ;;
  *" remote get-url origin "*)
    printf '%s\n' "$remote_url"
    exit 0
    ;;
  *" rev-parse --verify HEAD "*|*" rev-parse HEAD "*)
    printf '%s\n' "$fake_sha"
    exit 0
    ;;
  *" fetch "*|*" checkout "*|*" reset --hard "*)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_bin/git"
  cat > "$fake_bin/git.cmd" <<EOF
@echo off
set ARGS=%*
echo %ARGS% | findstr /C:"--version" >nul && echo git version 2.50.1 && exit /b 0
echo %ARGS% | findstr /C:"remote get-url origin" >nul && echo $remote_url && exit /b 0
echo %ARGS% | findstr /C:"rev-parse --verify HEAD" >nul && echo $fake_sha && exit /b 0
echo %ARGS% | findstr /C:"rev-parse HEAD" >nul && echo $fake_sha && exit /b 0
echo %ARGS% | findstr /C:"fetch" >nul && exit /b 0
echo %ARGS% | findstr /C:"checkout" >nul && exit /b 0
echo %ARGS% | findstr /C:"reset --hard" >nul && exit /b 0
exit /b 1
EOF
  printf '%s' "$fake_bin"
}

make_spec_cache() {
  cache_dir="$tmp_root/$1"
  chunks_sha="$2"
  spec_source_sha="${3:-$chunks_sha}"

  mkdir -p \
    "$cache_dir/.git" \
    "$cache_dir/fpf_chunks/by_pattern" \
    "$cache_dir/fpf_chunks/by_section" \
    "$cache_dir/fpf_chunks/non_patterns"

  printf '# FPF Spec fixture\n' > "$cache_dir/FPF-Spec.md"
  if [ "$spec_source_sha" != "none" ]; then
    cat > "$cache_dir/fpf-source.env" <<EOF
FPF_SPEC_SOURCE_COMMIT=$spec_source_sha
EOF
  fi
  cat > "$cache_dir/fpf_chunks/000-index.md" <<EOF
# FPF pattern-aware chunks index

Source: \`FPF-Spec.md\`

Commit SHA: \`$chunks_sha\`

## Patterns

- [A.1 - Fixture](by_pattern/A.1.md)
EOF
  cat > "$cache_dir/fpf_chunks/metadata.jsonl" <<EOF
{"pattern_id":"A.1","output_path":"by_pattern/A.1.md","commit_sha":"$chunks_sha"}
EOF
  cat > "$cache_dir/fpf_chunks/by_pattern/A.1.md" <<EOF
---
pattern_id: "A.1"
commit_sha: "$chunks_sha"
---

# A.1 fixture
EOF

  printf '%s' "$cache_dir"
}

make_protocols_cache() {
  cache_dir="$tmp_root/$1"

  mkdir -p "$cache_dir/.git" "$cache_dir/protocols"
  cat > "$cache_dir/registry.yaml" <<EOF
schema_version: 1
protocols:
  simple-medium: protocols/simple-medium.md
EOF
  printf '# Simple fixture\n' > "$cache_dir/protocols/simple-medium.md"
  printf '%s' "$cache_dir"
}

write_cache_marker() {
  cache_dir="$1"
  kind="$2"
  repo="$3"
  branch="$4"

  cat > "$cache_dir/.fpf-cache-repo" <<EOF
kind=$kind
repo=$repo
branch=$branch
EOF
}

run_bash_spec() {
  cache_dir="$1"
  fake_bin="$2"
  mode="${3:-cache-only}"
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$cache_dir" \
    FPF_REFRESH_MODE="$mode" \
    bash "$skill_dir/scripts/update_fpf_spec.sh"
}

run_bash_protocols() {
  cache_dir="$1"
  fake_bin="$2"
  mode="${3:-cache-only}"
  PATH="$fake_bin:$PATH" \
    FPF_PROTOCOLS_CACHE_DIR="$cache_dir" \
    FPF_REFRESH_MODE="$mode" \
    bash "$skill_dir/scripts/update_fpf_protocols.sh"
}

run_bash_context() {
  spec_cache="$1"
  protocols_cache="$2"
  state_dir="$3"
  env_state_dir="$4"
  fake_bin="$5"
  shift 5
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$spec_cache" \
    FPF_PROTOCOLS_CACHE_DIR="$protocols_cache" \
    FPF_REFRESH_STATE_DIR="$state_dir" \
    FPF_ENV_STATE_DIR="$env_state_dir" \
    "$@" \
    bash "$skill_dir/scripts/update_fpf_context.sh"
}

run_bash_doctor() {
  spec_cache="$1"
  protocols_cache="$2"
  env_state_file="$3"
  fake_bin="$4"
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$spec_cache" \
    FPF_PROTOCOLS_CACHE_DIR="$protocols_cache" \
    FPF_ENV_STATE_FILE="$env_state_file" \
    bash "$skill_dir/scripts/check_fpf_environment.sh" --portable-install --write-state
}

run_pwsh_spec() {
  cache_dir="$1"
  fake_bin="$2"
  mode="${3:-cache-only}"
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$cache_dir" \
    FPF_REFRESH_MODE="$mode" \
    pwsh -NoProfile -File "$skill_dir/scripts/update_fpf_spec.ps1"
}

run_pwsh_protocols() {
  cache_dir="$1"
  fake_bin="$2"
  mode="${3:-cache-only}"
  PATH="$fake_bin:$PATH" \
    FPF_PROTOCOLS_CACHE_DIR="$cache_dir" \
    FPF_REFRESH_MODE="$mode" \
    pwsh -NoProfile -File "$skill_dir/scripts/update_fpf_protocols.ps1"
}

run_pwsh_context() {
  spec_cache="$1"
  protocols_cache="$2"
  state_dir="$3"
  env_state_dir="$4"
  fake_bin="$5"
  shift 5
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$spec_cache" \
    FPF_PROTOCOLS_CACHE_DIR="$protocols_cache" \
    FPF_REFRESH_STATE_DIR="$state_dir" \
    FPF_ENV_STATE_DIR="$env_state_dir" \
    "$@" \
    pwsh -NoProfile -File "$skill_dir/scripts/update_fpf_context.ps1"
}

run_pwsh_doctor() {
  spec_cache="$1"
  protocols_cache="$2"
  env_state_file="$3"
  fake_bin="$4"
  PATH="$fake_bin:$PATH" \
    FPF_SPEC_CACHE_DIR="$spec_cache" \
    FPF_PROTOCOLS_CACHE_DIR="$protocols_cache" \
    FPF_ENV_STATE_FILE="$env_state_file" \
    pwsh -NoProfile -File "$skill_dir/scripts/check_fpf_environment.ps1" --portable-install --write-state
}

assert_aligned_output() {
  output="$1"
  assert_field "$output" FPF_SPEC_COMMIT "$aligned_sha"
  assert_field "$output" FPF_SPEC_REPO_COMMIT "$aligned_sha"
  assert_field "$output" FPF_SPEC_SOURCE_COMMIT "$aligned_sha"
  assert_field "$output" FPF_CHUNKS_SOURCE_COMMIT "$aligned_sha"
  assert_field "$output" FPF_CHUNKS_STATUS ready
  assert_field "$output" FPF_CHUNKS_MODE chunk-first
}

assert_stale_output() {
  output="$1"
  assert_field "$output" FPF_SPEC_COMMIT "$stale_spec_sha"
  assert_field "$output" FPF_SPEC_REPO_COMMIT "$stale_spec_sha"
  assert_field "$output" FPF_SPEC_SOURCE_COMMIT "$stale_spec_sha"
  assert_field "$output" FPF_CHUNKS_SOURCE_COMMIT "$stale_chunks_sha"
  assert_field "$output" FPF_CHUNKS_STATUS stale
  assert_field "$output" FPF_CHUNKS_MODE full-spec-first
}

assert_unknown_spec_output() {
  output="$1"
  assert_field "$output" FPF_SPEC_COMMIT unknown
  assert_field "$output" FPF_SPEC_REPO_COMMIT unknown
  assert_field "$output" FPF_SPEC_SOURCE_COMMIT unknown
  assert_field "$output" FPF_CHUNKS_SOURCE_COMMIT "$unknown_chunks_sha"
  assert_field "$output" FPF_CHUNKS_STATUS degraded
  assert_field "$output" FPF_CHUNKS_MODE full-spec-fallback
}

assert_context_attempted_output() {
  output="$1"
  assert_field "$output" FPF_REFRESH_DECISION attempted
  assert_field "$output" FPF_REFRESH_REASON missing-state
  assert_field "$output" FPF_REFRESH_LAST_ATTEMPT_STATE_PATH none
  assert_field "$output" FPF_SPEC_STATUS fresh
  assert_field "$output" FPF_PROTOCOLS_STATUS fresh
}

assert_context_skipped_output() {
  output="$1"
  expected_state="$2"
  assert_field "$output" FPF_REFRESH_DECISION skipped_recent
  assert_field "$output" FPF_REFRESH_REASON recent-cache
  assert_field "$output" FPF_REFRESH_LAST_ATTEMPT_STATE_PATH "$expected_state"
  assert_field "$output" FPF_SPEC_STATUS cached
  assert_field "$output" FPF_PROTOCOLS_STATUS cached
}

assert_state_unavailable_output() {
  output="$1"
  assert_field "$output" FPF_REFRESH_DECISION skipped_recent
  assert_field "$output" FPF_REFRESH_REASON state-dir-unavailable
  assert_field "$output" FPF_SPEC_STATUS cached
  assert_field "$output" FPF_PROTOCOLS_STATUS cached
}

assert_active_lock_output() {
  output="$1"
  assert_field "$output" FPF_REFRESH_DECISION skipped_recent
  assert_field "$output" FPF_REFRESH_REASON active-refresh
  assert_field "$output" FPF_SPEC_STATUS cached
  assert_field "$output" FPF_PROTOCOLS_STATUS cached
}

assert_doctor_output() {
  output="$1"
  assert_field "$output" FPF_ENV_CHECK_STATUS ok
  assert_field "$output" FPF_PORTABLE_CHECK_STATUS ok
  assert_field "$output" FPF_ENV_CHECK_PATH_POLICY_MODE portable-explicit
}

assert_protocols_provenance_output() {
  output="$1"
  expected_commit="$2"
  expected_remote="$3"
  expected_trust="$4"

  assert_field "$output" FPF_PROTOCOLS_REPO_URL "$expected_protocols_url"
  assert_field "$output" FPF_PROTOCOLS_BRANCH main
  assert_field "$output" FPF_PROTOCOLS_REMOTE_URL "$expected_remote"
  assert_field "$output" FPF_PROTOCOLS_CACHE_TRUST_STATUS "$expected_trust"
  assert_field "$output" FPF_PROTOCOLS_COMMIT "$expected_commit"
}

assert_reset_guard_output() {
  output="$1"
  status_key="$2"
  warning_key="$3"
  assert_field "$output" "$status_key" cached
  assert_field_present "$output" "$warning_key"
  assert_contains "$output" "no valid cache marker"
}

validate_cmd_wrappers() {
  grep -q 'update_fpf_context.ps1' "$skill_dir/scripts/update_fpf_context.cmd" \
    || fail "update_fpf_context.cmd must delegate to update_fpf_context.ps1"
  grep -q 'fpf-work-guide-doctor.ps1' "$skill_dir/scripts/fpf-work-guide-doctor.cmd" \
    || fail "fpf-work-guide-doctor.cmd must delegate to fpf-work-guide-doctor.ps1"
}

run_bash_lifecycle_tests() {
  spec_cache="$(make_spec_cache bash-context "$aligned_sha")"
  protocols_cache="$(make_protocols_cache bash-context-protocols)"
  fake_git="$(make_fake_git bash-context "$aligned_sha" "$expected_spec_url")"
  state_dir="$tmp_root/bash-state"
  env_state_dir="$tmp_root/bash-env-state"

  context_output="$(run_bash_context "$spec_cache" "$protocols_cache" "$state_dir" "$env_state_dir" "$fake_git" env FPF_PROTOCOLS_REPO_URL="$expected_spec_url")"
  assert_context_attempted_output "$context_output"

  context_skip_output="$(run_bash_context "$spec_cache" "$protocols_cache" "$state_dir" "$env_state_dir" "$fake_git" env FPF_PROTOCOLS_REPO_URL="$expected_spec_url")"
  assert_context_skipped_output "$context_skip_output" "$state_dir/latest.env"

  blocked_state_path="$tmp_root/bash-state-file"
  printf 'not a directory\n' > "$blocked_state_path"
  unavailable_output="$(run_bash_context "$spec_cache" "$protocols_cache" "$blocked_state_path" "$env_state_dir" "$fake_git" env)"
  assert_state_unavailable_output "$unavailable_output"

  lock_state_dir="$tmp_root/bash-lock-state"
  mkdir -p "$lock_state_dir/update.lock"
  cat > "$lock_state_dir/latest.env" <<EOF
LAST_REFRESH_ATTEMPT_EPOCH=$(date +%s)
LAST_REFRESH_ATTEMPT_AT=fixture
LAST_REFRESH_DECISION=attempted
LAST_REFRESH_REASON=fixture
FPF_REFRESH_TTL_SECONDS=21600
FPF_REFRESH_NEXT_ELIGIBLE_EPOCH=$(($(date +%s) + 21600))
FPF_REFRESH_NEXT_ELIGIBLE_AT=fixture
FPF_SPEC_STATUS=cached
FPF_SPEC_COMMIT=$aligned_sha
FPF_PROTOCOLS_STATUS=cached
FPF_PROTOCOLS_COMMIT=$protocols_sha
EOF
  active_lock_output="$(run_bash_context "$spec_cache" "$protocols_cache" "$lock_state_dir" "$env_state_dir" "$fake_git" env FPF_REFRESH_FORCE=1)"
  assert_active_lock_output "$active_lock_output"

  doctor_output="$(run_bash_doctor "$spec_cache" "$protocols_cache" "$tmp_root/bash-doctor/environment.env" "$fake_git")"
  assert_doctor_output "$doctor_output"
}

run_reset_guard_tests() {
  guard_spec_cache="$(make_spec_cache guard-spec "$aligned_sha")"
  guard_protocols_cache="$(make_protocols_cache guard-protocols)"
  wrong_git="$(make_fake_git reset-guard "$aligned_sha" "$wrong_url")"

  guard_spec_output="$(run_bash_spec "$guard_spec_cache" "$wrong_git" refresh)"
  assert_reset_guard_output "$guard_spec_output" FPF_SPEC_STATUS FPF_SPEC_WARNING

  guard_protocols_output="$(run_bash_protocols "$guard_protocols_cache" "$wrong_git" refresh)"
  assert_reset_guard_output "$guard_protocols_output" FPF_PROTOCOLS_STATUS FPF_PROTOCOLS_WARNING

  if command -v pwsh >/dev/null 2>&1; then
    guard_spec_pwsh_output="$(run_pwsh_spec "$guard_spec_cache" "$wrong_git" refresh)"
    assert_reset_guard_output "$guard_spec_pwsh_output" FPF_SPEC_STATUS FPF_SPEC_WARNING

    guard_protocols_pwsh_output="$(run_pwsh_protocols "$guard_protocols_cache" "$wrong_git" refresh)"
    assert_reset_guard_output "$guard_protocols_pwsh_output" FPF_PROTOCOLS_STATUS FPF_PROTOCOLS_WARNING
  fi
}

run_marker_validation_tests() {
  marker_spec_cache="$(make_spec_cache marker-spec "$aligned_sha")"
  marker_protocols_cache="$(make_protocols_cache marker-protocols)"
  wrong_git="$(make_fake_git marker-wrong "$aligned_sha" "$wrong_url")"

  write_cache_marker "$marker_spec_cache" wrong-kind "$wrong_url" main
  write_cache_marker "$marker_protocols_cache" wrong-kind "$wrong_url" main

  marker_spec_output="$(run_bash_spec "$marker_spec_cache" "$wrong_git" refresh)"
  assert_reset_guard_output "$marker_spec_output" FPF_SPEC_STATUS FPF_SPEC_WARNING

  marker_protocols_output="$(run_bash_protocols "$marker_protocols_cache" "$wrong_git" refresh)"
  assert_reset_guard_output "$marker_protocols_output" FPF_PROTOCOLS_STATUS FPF_PROTOCOLS_WARNING
  assert_protocols_provenance_output "$marker_protocols_output" "$aligned_sha" "$wrong_url" marker-mismatch

  matching_spec_cache="$(make_spec_cache marker-spec-valid "$aligned_sha")"
  matching_protocols_cache="$(make_protocols_cache marker-protocols-valid)"
  write_cache_marker "$matching_spec_cache" fpf-spec-cache "$expected_spec_url" main
  write_cache_marker "$matching_protocols_cache" fpf-protocols-cache "$expected_protocols_url" main

  marker_spec_fresh_output="$(run_bash_spec "$matching_spec_cache" "$wrong_git" refresh)"
  assert_field "$marker_spec_fresh_output" FPF_SPEC_STATUS fresh

  marker_protocols_fresh_output="$(run_bash_protocols "$matching_protocols_cache" "$wrong_git" refresh)"
  assert_field "$marker_protocols_fresh_output" FPF_PROTOCOLS_STATUS fresh
  assert_protocols_provenance_output "$marker_protocols_fresh_output" "$aligned_sha" "$wrong_url" marker-matches

  if command -v pwsh >/dev/null 2>&1; then
    pwsh_marker_spec_cache="$(make_spec_cache pwsh-marker-spec "$aligned_sha")"
    pwsh_marker_protocols_cache="$(make_protocols_cache pwsh-marker-protocols)"
    write_cache_marker "$pwsh_marker_spec_cache" wrong-kind "$wrong_url" main
    write_cache_marker "$pwsh_marker_protocols_cache" wrong-kind "$wrong_url" main

    pwsh_marker_spec_output="$(run_pwsh_spec "$pwsh_marker_spec_cache" "$wrong_git" refresh)"
    assert_reset_guard_output "$pwsh_marker_spec_output" FPF_SPEC_STATUS FPF_SPEC_WARNING

    pwsh_marker_protocols_output="$(run_pwsh_protocols "$pwsh_marker_protocols_cache" "$wrong_git" refresh)"
    assert_reset_guard_output "$pwsh_marker_protocols_output" FPF_PROTOCOLS_STATUS FPF_PROTOCOLS_WARNING
    assert_protocols_provenance_output "$pwsh_marker_protocols_output" "$aligned_sha" "$wrong_url" marker-mismatch
  fi
}

run_pwsh_lifecycle_tests() {
  spec_cache="$(make_spec_cache pwsh-context "$aligned_sha")"
  protocols_cache="$(make_protocols_cache pwsh-context-protocols)"
  fake_git="$(make_fake_git pwsh-context "$aligned_sha" "$expected_spec_url")"
  state_dir="$tmp_root/pwsh-state"
  env_state_dir="$tmp_root/pwsh-env-state"

  context_output="$(run_pwsh_context "$spec_cache" "$protocols_cache" "$state_dir" "$env_state_dir" "$fake_git" env FPF_PROTOCOLS_REPO_URL="$expected_spec_url")"
  assert_context_attempted_output "$context_output"

  context_skip_output="$(run_pwsh_context "$spec_cache" "$protocols_cache" "$state_dir" "$env_state_dir" "$fake_git" env FPF_PROTOCOLS_REPO_URL="$expected_spec_url")"
  assert_context_skipped_output "$context_skip_output" "$state_dir/latest.env"

  blocked_state_path="$tmp_root/pwsh-state-file"
  printf 'not a directory\n' > "$blocked_state_path"
  unavailable_output="$(run_pwsh_context "$spec_cache" "$protocols_cache" "$blocked_state_path" "$env_state_dir" "$fake_git" env)"
  assert_state_unavailable_output "$unavailable_output"

  lock_state_dir="$tmp_root/pwsh-lock-state"
  mkdir -p "$lock_state_dir/update.lock"
  cat > "$lock_state_dir/latest.env" <<EOF
LAST_REFRESH_ATTEMPT_EPOCH=$(date +%s)
LAST_REFRESH_ATTEMPT_AT=fixture
LAST_REFRESH_DECISION=attempted
LAST_REFRESH_REASON=fixture
FPF_REFRESH_TTL_SECONDS=21600
FPF_REFRESH_NEXT_ELIGIBLE_EPOCH=$(($(date +%s) + 21600))
FPF_REFRESH_NEXT_ELIGIBLE_AT=fixture
FPF_SPEC_STATUS=cached
FPF_SPEC_COMMIT=$aligned_sha
FPF_PROTOCOLS_STATUS=cached
FPF_PROTOCOLS_COMMIT=$protocols_sha
EOF
  active_lock_output="$(run_pwsh_context "$spec_cache" "$protocols_cache" "$lock_state_dir" "$env_state_dir" "$fake_git" env FPF_REFRESH_FORCE=1)"
  assert_active_lock_output "$active_lock_output"

  doctor_output="$(run_pwsh_doctor "$spec_cache" "$protocols_cache" "$tmp_root/pwsh-doctor/environment.env" "$fake_git")"
  assert_doctor_output "$doctor_output"
}

aligned_cache="$(make_spec_cache aligned "$aligned_sha")"
aligned_git="$(make_fake_git aligned "$aligned_sha" "$expected_spec_url")"
aligned_bash_output="$(run_bash_spec "$aligned_cache" "$aligned_git")"
assert_aligned_output "$aligned_bash_output"

stale_cache="$(make_spec_cache stale "$stale_chunks_sha" "$stale_spec_sha")"
stale_git="$(make_fake_git stale "$stale_spec_sha" "$expected_spec_url")"
stale_bash_output="$(run_bash_spec "$stale_cache" "$stale_git")"
assert_stale_output "$stale_bash_output"

unknown_cache="$(make_spec_cache unknown "$unknown_chunks_sha" none)"
rm -rf "$unknown_cache/.git"
unknown_bash_output="$(FPF_SPEC_CACHE_DIR="$unknown_cache" FPF_REFRESH_MODE=cache-only bash "$skill_dir/scripts/update_fpf_spec.sh")"
assert_unknown_spec_output "$unknown_bash_output"

protocols_cache="$(make_protocols_cache protocols-cache)"
protocols_git="$(make_fake_git protocols "$protocols_sha" "$expected_protocols_url")"
protocols_output="$(run_bash_protocols "$protocols_cache" "$protocols_git")"
assert_field "$protocols_output" FPF_PROTOCOLS_STATUS cached
assert_protocols_provenance_output "$protocols_output" "$protocols_sha" "$expected_protocols_url" remote-matches

validate_cmd_wrappers
run_bash_lifecycle_tests
run_reset_guard_tests
run_marker_validation_tests

if command -v pwsh >/dev/null 2>&1; then
  aligned_pwsh_output="$(run_pwsh_spec "$aligned_cache" "$aligned_git")"
  assert_aligned_output "$aligned_pwsh_output"

  stale_pwsh_output="$(run_pwsh_spec "$stale_cache" "$stale_git")"
  assert_stale_output "$stale_pwsh_output"

  unknown_pwsh_output="$(FPF_SPEC_CACHE_DIR="$unknown_cache" FPF_REFRESH_MODE=cache-only pwsh -NoProfile -File "$skill_dir/scripts/update_fpf_spec.ps1")"
  assert_unknown_spec_output "$unknown_pwsh_output"

  protocols_pwsh_output="$(run_pwsh_protocols "$protocols_cache" "$protocols_git")"
  assert_field "$protocols_pwsh_output" FPF_PROTOCOLS_STATUS cached
  assert_protocols_provenance_output "$protocols_pwsh_output" "$protocols_sha" "$expected_protocols_url" remote-matches

  for key in FPF_SPEC_COMMIT FPF_SPEC_REPO_COMMIT FPF_SPEC_SOURCE_COMMIT FPF_CHUNKS_SOURCE_COMMIT FPF_CHUNKS_STATUS FPF_CHUNKS_MODE; do
    bash_value="$(printf '%s\n' "$stale_bash_output" | field_value "$key")"
    pwsh_value="$(printf '%s\n' "$stale_pwsh_output" | field_value "$key")"
    if [ "$bash_value" != "$pwsh_value" ]; then
      fail "Bash/PowerShell stale fixture mismatch for $key: '$bash_value' vs '$pwsh_value'"
    fi
  done

  run_pwsh_lifecycle_tests

  if command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c "$skill_dir\\scripts\\fpf-work-guide-doctor.cmd" --help >/dev/null \
      || fail "fpf-work-guide-doctor.cmd failed under cmd.exe"
  elif [ "${FPF_VALIDATE_CMD:-optional}" = "required" ]; then
    fail "cmd.exe is required by FPF_VALIDATE_CMD=required but was not found"
  fi

  printf 'OK: fpf-work-guide Bash and PowerShell lifecycle validation passed\n'
else
  if [ "${FPF_VALIDATE_POWERSHELL:-optional}" = "required" ]; then
    fail "pwsh is required by FPF_VALIDATE_POWERSHELL=required but was not found"
  fi
  printf 'OK: fpf-work-guide Bash lifecycle validation passed; PowerShell validation skipped because pwsh is unavailable\n'
fi
