#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEFAULT_CACHE_HOME="${FPF_CACHE_HOME:-$CODEX_HOME_DIR/cache}"
STATE_DIR="${FPF_REFRESH_STATE_DIR:-${FPF_UPDATE_STATE_DIR:-$PWD/.fpf-update}}"
STATE_FILE="$STATE_DIR/latest.env"
AUTO_STATE_FILE="${FPF_REFRESH_AUTO_STATE_FILE:-}"
LOCK_DIR="$STATE_DIR/update.lock"
TTL_SECONDS="${FPF_REFRESH_TTL_SECONDS:-21600}"
LOCK_STALE_SECONDS="${FPF_REFRESH_LOCK_STALE_SECONDS:-900}"
FORCE_REFRESH="${FPF_REFRESH_FORCE:-${FPF_UPDATE_FORCE:-0}}"
FORCE_REASON="${FPF_REFRESH_REASON:-forced}"
SPEC_CACHE_DIR="${FPF_SPEC_CACHE_DIR:-$DEFAULT_CACHE_HOME/fpf-spec-mirror}"
SPEC_PATH="$SPEC_CACHE_DIR/FPF-Spec.md"
PROTOCOLS_CACHE_DIR="${FPF_PROTOCOLS_CACHE_DIR:-$DEFAULT_CACHE_HOME/agent-skills-and-protocols}"
PROTOCOLS_REGISTRY_PATH="$PROTOCOLS_CACHE_DIR/registry.yaml"
ENV_STATE_DIR="${FPF_ENV_STATE_DIR:-$STATE_DIR}"
ENV_STATE_FILE="${FPF_ENV_STATE_FILE:-$ENV_STATE_DIR/environment.env}"
ENV_CHECK_SCRIPT="$SCRIPT_DIR/check_fpf_environment.sh"
ENV_CHECK_POLICY="${FPF_ENV_CHECK_POLICY:-fingerprint}"

spec_output=""
protocols_output=""
spec_code=0
protocols_code=0
environment_output=""
environment_probe_output=""
environment_code=0
environment_probe_code=0
environment_checked=0
lock_recovery_detail=""
state_error_detail=""
last_attempt_state_source=""

is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

format_epoch() {
  local epoch="$1"
  if is_uint "$epoch"; then
    date -r "$epoch" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null \
      || date -d "@$epoch" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null \
      || printf '%s' "$epoch"
  else
    printf 'none'
  fi
}

path_mtime_epoch() {
  local path="$1"
  stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || printf ''
}

read_output_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  '
}

state_dir_ready() {
  state_error_detail=""

  if [ -e "$STATE_DIR" ] && [ ! -d "$STATE_DIR" ]; then
    state_error_detail="FPF refresh state path exists but is not a directory: $STATE_DIR."
    return 1
  fi

  if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
    state_error_detail="Could not create FPF refresh state directory: $STATE_DIR."
    return 1
  fi

  if [ ! -w "$STATE_DIR" ]; then
    state_error_detail="FPF refresh state directory is not writable: $STATE_DIR."
    return 1
  fi

  return 0
}

sandbox_network_disabled() {
  [ "${CODEX_SANDBOX_NETWORK_DISABLED:-0}" = "1" ]
}

run_context_scripts() {
  local mode="$1"

  spec_output="$(FPF_REFRESH_MODE="$mode" bash "$SCRIPT_DIR/update_fpf_spec.sh")"
  spec_code=$?

  protocols_output="$(FPF_REFRESH_MODE="$mode" bash "$SCRIPT_DIR/update_fpf_protocols.sh")"
  protocols_code=$?
}

needs_environment_check() {
  if [ "${FPF_ENV_CHECK_FORCE:-${FPF_PREFLIGHT_FORCE:-0}}" = "1" ]; then
    return 0
  fi
  if [ ! -f "$ENV_STATE_FILE" ]; then
    return 0
  fi
  if [ ! -f "$SPEC_PATH" ] || [ ! -f "$PROTOCOLS_REGISTRY_PATH" ]; then
    return 0
  fi
  return 1
}

needs_environment_probe() {
  if [ "$ENV_CHECK_POLICY" = "on-demand" ] || [ "$ENV_CHECK_POLICY" = "disabled" ]; then
    return 1
  fi
  if [ "$environment_checked" -eq 1 ]; then
    return 1
  fi
  if [ ! -f "$ENV_STATE_FILE" ]; then
    return 1
  fi
  if [ ! -f "$SPEC_PATH" ] || [ ! -f "$PROTOCOLS_REGISTRY_PATH" ]; then
    return 1
  fi
  return 0
}

run_environment_check() {
  if [ ! -r "$ENV_CHECK_SCRIPT" ]; then
    environment_output="FPF_ENV_CHECK_STATUS=blocked
FPF_ENV_CHECK_REASON=missing-environment-check-script
FPF_ENV_CHECK_SUMMARY=The fpf-work-guide environment check script is missing or not readable.
FPF_ENV_CHECK_ACTION=Restore scripts/check_fpf_environment.sh in the fpf-work-guide skill.
FPF_ENV_CHECK_CONSEQUENCE=The refresh gate cannot verify whether this environment is safe to use."
    environment_code=2
    environment_checked=1
    return 2
  fi

  environment_output="$(bash "$ENV_CHECK_SCRIPT" --state-file "$ENV_STATE_FILE" --write-state)"
  environment_code=$?
  environment_checked=1
  return "$environment_code"
}

run_environment_probe() {
  if [ ! -r "$ENV_CHECK_SCRIPT" ]; then
    environment_probe_output="FPF_ENV_CHECK_STATUS=blocked
FPF_ENV_CHECK_REASON=missing-environment-check-script
FPF_ENV_CHECK_SUMMARY=The fpf-work-guide environment check script is missing or not readable.
FPF_ENV_CHECK_ACTION=Restore scripts/check_fpf_environment.sh in the fpf-work-guide skill.
FPF_ENV_CHECK_CONSEQUENCE=The refresh gate cannot verify whether this environment is safe to use."
    environment_probe_code=2
    return 2
  fi

  environment_probe_output="$(bash "$ENV_CHECK_SCRIPT" --state-file "$ENV_STATE_FILE")"
  environment_probe_code=$?
  return "$environment_probe_code"
}

handle_environment_probe() {
  local probe_status probe_state_status

  if ! run_environment_probe; then
    environment_output="$environment_probe_output"
    environment_code="$environment_probe_code"
    environment_checked=1
    return 2
  fi

  probe_status="$(printf '%s\n' "$environment_probe_output" | read_output_value FPF_ENV_CHECK_STATUS 2>/dev/null || true)"
  probe_state_status="$(printf '%s\n' "$environment_probe_output" | read_output_value FPF_ENV_CHECK_STATE_STATUS 2>/dev/null || true)"

  if [ "$probe_state_status" = "changed" ]; then
    run_environment_check
    return "$?"
  fi

  if [ "$probe_status" = "degraded" ]; then
    environment_output="$environment_probe_output"
    environment_code=0
    environment_checked=1
  fi

  return 0
}

acquire_lock() {
  local lock_epoch lock_age

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  lock_epoch="$(path_mtime_epoch "$LOCK_DIR")"
  if is_uint "$LOCK_STALE_SECONDS" \
    && [ "$LOCK_STALE_SECONDS" -gt 0 ] \
    && is_uint "$lock_epoch"; then
    lock_age=$((now_epoch - lock_epoch))
    if [ "$lock_age" -ge "$LOCK_STALE_SECONDS" ]; then
      if rmdir "$LOCK_DIR" 2>/dev/null && mkdir "$LOCK_DIR" 2>/dev/null; then
        lock_recovery_detail="Recovered stale FPF refresh lock older than ${LOCK_STALE_SECONDS}s."
        return 0
      fi
    fi
  fi

  return 1
}

write_state() {
  local attempt_epoch="$1"
  local decision="$2"
  local reason="$3"
  local next_epoch="$4"
  local tmp_file
  local spec_status spec_commit spec_repo_commit spec_source_commit protocols_status protocols_commit

  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  tmp_file="$STATE_FILE.$$"

  spec_status="$(printf '%s\n' "$spec_output" | read_output_value FPF_SPEC_STATUS 2>/dev/null || true)"
  spec_commit="$(printf '%s\n' "$spec_output" | read_output_value FPF_SPEC_COMMIT 2>/dev/null || true)"
  spec_repo_commit="$(printf '%s\n' "$spec_output" | read_output_value FPF_SPEC_REPO_COMMIT 2>/dev/null || true)"
  spec_source_commit="$(printf '%s\n' "$spec_output" | read_output_value FPF_SPEC_SOURCE_COMMIT 2>/dev/null || true)"
  protocols_status="$(printf '%s\n' "$protocols_output" | read_output_value FPF_PROTOCOLS_STATUS 2>/dev/null || true)"
  protocols_commit="$(printf '%s\n' "$protocols_output" | read_output_value FPF_PROTOCOLS_COMMIT 2>/dev/null || true)"

  {
    printf 'LAST_REFRESH_ATTEMPT_EPOCH=%s\n' "$attempt_epoch"
    printf 'LAST_REFRESH_ATTEMPT_AT=%s\n' "$(format_epoch "$attempt_epoch")"
    printf 'LAST_REFRESH_DECISION=%s\n' "$decision"
    printf 'LAST_REFRESH_REASON=%s\n' "$reason"
    printf 'FPF_REFRESH_TTL_SECONDS=%s\n' "$TTL_SECONDS"
    printf 'FPF_REFRESH_NEXT_ELIGIBLE_EPOCH=%s\n' "$next_epoch"
    printf 'FPF_REFRESH_NEXT_ELIGIBLE_AT=%s\n' "$(format_epoch "$next_epoch")"
    printf 'FPF_SPEC_STATUS=%s\n' "${spec_status:-unknown}"
    printf 'FPF_SPEC_COMMIT=%s\n' "${spec_commit:-unknown}"
    printf 'FPF_SPEC_REPO_COMMIT=%s\n' "${spec_repo_commit:-${spec_commit:-unknown}}"
    printf 'FPF_SPEC_SOURCE_COMMIT=%s\n' "${spec_source_commit:-unknown}"
    printf 'FPF_PROTOCOLS_STATUS=%s\n' "${protocols_status:-unknown}"
    printf 'FPF_PROTOCOLS_COMMIT=%s\n' "${protocols_commit:-unknown}"
  } > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
}

print_result() {
  local decision="$1"
  local reason="$2"
  local last_attempt_epoch="$3"
  local next_eligible_epoch="$4"
  local detail="${5:-}"

  printf 'FPF_REFRESH_DECISION=%s\n' "$decision"
  printf 'FPF_REFRESH_REASON=%s\n' "$reason"
  printf 'FPF_REFRESH_TTL_SECONDS=%s\n' "$TTL_SECONDS"
  printf 'FPF_REFRESH_LOCK_STALE_SECONDS=%s\n' "$LOCK_STALE_SECONDS"
  printf 'FPF_ENV_CHECK_POLICY=%s\n' "$ENV_CHECK_POLICY"
  printf 'FPF_REFRESH_LAST_ATTEMPT_AT=%s\n' "$(format_epoch "$last_attempt_epoch")"
  printf 'FPF_REFRESH_NEXT_ELIGIBLE_AT=%s\n' "$(format_epoch "$next_eligible_epoch")"
  printf 'FPF_REFRESH_STATE_PATH=%s\n' "$STATE_FILE"
  printf 'FPF_REFRESH_LAST_ATTEMPT_STATE_PATH=%s\n' "${last_attempt_state_source:-none}"
  if [ -n "$AUTO_STATE_FILE" ]; then
    printf 'FPF_REFRESH_AUTO_STATE_PATH=%s\n' "$AUTO_STATE_FILE"
  fi
  if [ -n "$environment_output" ]; then
    printf '%s\n' "$environment_output"
  fi
  if [ -n "$detail" ]; then
    printf 'FPF_REFRESH_DETAIL=%s\n' "$detail"
  fi
  printf '%s\n' "$spec_output"
  printf '%s\n' "$protocols_output"
}

if ! is_uint "$TTL_SECONDS"; then
  TTL_SECONDS=21600
fi
if ! is_uint "$LOCK_STALE_SECONDS"; then
  LOCK_STALE_SECONDS=900
fi

if ! state_dir_ready; then
  run_context_scripts "cache-only"
  if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
    print_result "skipped_recent" "state-dir-unavailable" "none" "none" "$state_error_detail Using cache-only validation without durable refresh state."
    exit 0
  fi

  print_result "blocked" "state-dir-unavailable" "none" "none" "$state_error_detail Cache-only validation failed."
  exit 2
fi

if needs_environment_check; then
  if ! run_environment_check; then
    print_result "blocked" "environment-check" "none" "none"
    exit 2
  fi
elif needs_environment_probe; then
  if ! handle_environment_probe; then
    print_result "blocked" "environment-check" "none" "none"
    exit 2
  fi
fi

now_epoch="$(date +%s)"
last_attempt_epoch=""
last_attempt_state_source=""
last_attempt_reason=""
for state_candidate in "$STATE_FILE" ${AUTO_STATE_FILE:+"$AUTO_STATE_FILE"}; do
  [ -f "$state_candidate" ] || continue
  candidate_epoch="$(awk -F= '
    $1 == "LAST_REFRESH_ATTEMPT_EPOCH" {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$state_candidate" 2>/dev/null || true)"
  candidate_reason="$(awk -F= '
    $1 == "LAST_REFRESH_REASON" {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$state_candidate" 2>/dev/null || true)"
  if is_uint "$candidate_epoch"; then
    if [ "$candidate_reason" = "sandbox-network-disabled" ] && ! sandbox_network_disabled; then
      continue
    fi
    last_attempt_epoch="$candidate_epoch"
    last_attempt_state_source="$state_candidate"
    last_attempt_reason="$candidate_reason"
    break
  fi
done

mode="cache-only"
reason="recent-cache"

if [ "$FORCE_REFRESH" = "1" ]; then
  mode="refresh"
  reason="$FORCE_REASON"
elif [ -z "$last_attempt_epoch" ]; then
  mode="refresh"
  reason="missing-state"
else
  age_seconds=$((now_epoch - last_attempt_epoch))
  if [ "$age_seconds" -ge "$TTL_SECONDS" ]; then
    mode="refresh"
    reason="ttl-expired"
  fi
fi

if [ "$mode" = "cache-only" ]; then
  next_eligible_epoch=$((last_attempt_epoch + TTL_SECONDS))
  run_context_scripts "cache-only"
  if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
    print_result "skipped_recent" "$reason" "$last_attempt_epoch" "$next_eligible_epoch"
    exit 0
  fi

  mode="refresh"
  reason="missing-cache"
fi

if [ "$mode" = "refresh" ] && sandbox_network_disabled; then
  attempt_epoch="$now_epoch"
  next_eligible_epoch=$((attempt_epoch + TTL_SECONDS))
  run_context_scripts "cache-only"

  if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
    write_state "$attempt_epoch" "skipped_recent" "sandbox-network-disabled" "$next_eligible_epoch" || true
    print_result "skipped_recent" "sandbox-network-disabled" "$attempt_epoch" "$next_eligible_epoch" "Codex sandbox network is disabled; using cache-only validation instead of GitHub refresh."
    exit 0
  fi

  write_state "$attempt_epoch" "blocked" "sandbox-network-disabled" "$next_eligible_epoch" || true
  if [ "$environment_checked" -eq 0 ]; then
    run_environment_check || true
  fi
  print_result "blocked" "sandbox-network-disabled" "$attempt_epoch" "$next_eligible_epoch" "Codex sandbox network is disabled and cache-only validation failed."
  exit 2
fi

if ! acquire_lock; then
  if ! state_dir_ready; then
    run_context_scripts "cache-only"
    if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
      print_result "skipped_recent" "state-dir-unavailable" "${last_attempt_epoch:-none}" "none" "$state_error_detail Using cache-only validation without durable refresh state."
      exit 0
    fi

    print_result "blocked" "state-dir-unavailable" "${last_attempt_epoch:-none}" "none" "$state_error_detail Cache-only validation failed."
    exit 2
  fi

  run_context_scripts "cache-only"
  if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
    if [ -n "$last_attempt_epoch" ]; then
      next_eligible_epoch=$((last_attempt_epoch + TTL_SECONDS))
    else
      next_eligible_epoch="none"
    fi
    print_result "skipped_recent" "active-refresh" "${last_attempt_epoch:-none}" "$next_eligible_epoch" "Another FPF refresh gate is already active; using cache-only validation."
    exit 0
  fi

  if [ "$environment_checked" -eq 0 ]; then
    run_environment_check || true
  fi
  print_result "blocked" "active-refresh" "${last_attempt_epoch:-none}" "none" "Another FPF refresh gate is active and cache-only validation failed."
  exit 2
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

attempt_epoch="$now_epoch"
next_eligible_epoch=$((attempt_epoch + TTL_SECONDS))
run_context_scripts "refresh"

if [ "$spec_code" -eq 0 ] && [ "$protocols_code" -eq 0 ]; then
  write_state "$attempt_epoch" "attempted" "$reason" "$next_eligible_epoch" || true
  print_result "attempted" "$reason" "$attempt_epoch" "$next_eligible_epoch" "$lock_recovery_detail"
  exit 0
fi

write_state "$attempt_epoch" "blocked" "$reason" "$next_eligible_epoch" || true
if [ "$environment_checked" -eq 0 ]; then
  run_environment_check || true
fi
print_result "blocked" "$reason" "$attempt_epoch" "$next_eligible_epoch"
exit 2
