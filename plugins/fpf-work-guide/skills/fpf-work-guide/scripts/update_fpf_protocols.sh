#!/usr/bin/env bash
set -u

REPO_URL="${FPF_PROTOCOLS_REPO_URL:-https://github.com/ansea09/codex-skills-and-protocols.git}"
BRANCH="${FPF_PROTOCOLS_BRANCH:-main}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEFAULT_CACHE_HOME="${FPF_CACHE_HOME:-$CODEX_HOME_DIR/cache}"
DEFAULT_CACHE_DIR="$DEFAULT_CACHE_HOME/codex-skills-and-protocols"
CACHE_DIR="${FPF_PROTOCOLS_CACHE_DIR:-$DEFAULT_CACHE_DIR}"
CACHE_MARKER="$CACHE_DIR/.fpf-cache-repo"
EXPECTED_CACHE_KIND="fpf-protocols-cache"
REGISTRY_PATH="$CACHE_DIR/registry.yaml"
REFRESH_MODE="${FPF_REFRESH_MODE:-${FPF_UPDATE_MODE:-refresh}}"

status="missing"
warning=""
detail=""

print_result() {
  local commit="$1"
  printf 'FPF_PROTOCOLS_PATH=%s\n' "$CACHE_DIR"
  printf 'FPF_PROTOCOLS_REGISTRY_PATH=%s\n' "$REGISTRY_PATH"
  printf 'FPF_PROTOCOLS_REPO_URL=%s\n' "$REPO_URL"
  printf 'FPF_PROTOCOLS_BRANCH=%s\n' "$BRANCH"
  printf 'FPF_PROTOCOLS_REMOTE_URL=%s\n' "$(cache_remote_url)"
  printf 'FPF_PROTOCOLS_CACHE_TRUST_STATUS=%s\n' "$(cache_trust_status)"
  printf 'FPF_PROTOCOLS_COMMIT=%s\n' "$commit"
  printf 'FPF_PROTOCOLS_STATUS=%s\n' "$status"
  if [ -n "$warning" ]; then
    printf 'FPF_PROTOCOLS_WARNING=%s\n' "$warning"
  fi
  if [ -n "$detail" ]; then
    printf 'FPF_PROTOCOLS_DETAIL=%s\n' "$detail"
  fi
}

cached_commit() {
  local commit
  if command -v git >/dev/null 2>&1 && [ -d "$CACHE_DIR/.git" ]; then
    commit="$(git -C "$CACHE_DIR" rev-parse --verify HEAD 2>/dev/null)" \
      && printf '%s' "$commit" \
      || printf 'unknown'
  else
    printf 'unknown'
  fi
}

normalize_git_url() {
  local value="$1"
  value="${value%.git}"
  printf '%s' "$value"
}

marker_value() {
  local key="$1"
  [ -f "$CACHE_MARKER" ] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$CACHE_MARKER"
}

cache_marker_matches() {
  local kind repo branch
  [ -f "$CACHE_MARKER" ] || return 1
  kind="$(marker_value kind 2>/dev/null || true)"
  repo="$(marker_value repo 2>/dev/null || true)"
  branch="$(marker_value branch 2>/dev/null || true)"
  [ "$kind" = "$EXPECTED_CACHE_KIND" ] || return 1
  [ "$(normalize_git_url "$repo")" = "$(normalize_git_url "$REPO_URL")" ] || return 1
  [ "$branch" = "$BRANCH" ] || return 1
}

cache_remote_url() {
  if command -v git >/dev/null 2>&1 && [ -d "$CACHE_DIR/.git" ]; then
    git -C "$CACHE_DIR" remote get-url origin 2>/dev/null || printf 'none'
  else
    printf 'none'
  fi
}

cache_remote_matches() {
  local origin expected
  command -v git >/dev/null 2>&1 || return 1
  origin="$(git -C "$CACHE_DIR" remote get-url origin 2>/dev/null || true)"
  [ -n "$origin" ] || return 1
  origin="$(normalize_git_url "$origin")"
  expected="$(normalize_git_url "$REPO_URL")"
  [ "$origin" = "$expected" ]
}

cache_trust_status() {
  if [ "${FPF_ALLOW_NONSTANDARD_CACHE_RESET:-0}" = "1" ]; then
    printf 'explicit-allow'
    return
  fi
  if [ ! -d "$CACHE_DIR/.git" ]; then
    printf 'no-git-cache'
    return
  fi
  if cache_marker_matches; then
    printf 'marker-matches'
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    printf 'unverified'
    return
  fi
  if [ -f "$CACHE_MARKER" ] && cache_remote_matches; then
    printf 'remote-matches-marker-mismatch'
    return
  fi
  if cache_remote_matches; then
    printf 'remote-matches'
    return
  fi
  if [ -f "$CACHE_MARKER" ]; then
    printf 'marker-mismatch'
    return
  fi
  printf 'unverified'
}

cache_allows_hard_reset() {
  cache_marker_matches && return 0
  cache_remote_matches && return 0
  [ "${FPF_ALLOW_NONSTANDARD_CACHE_RESET:-0}" = "1" ] && return 0
  return 1
}

write_cache_marker() {
  {
    printf 'kind=%s\n' "$EXPECTED_CACHE_KIND"
    printf 'repo=%s\n' "$REPO_URL"
    printf 'branch=%s\n' "$BRANCH"
  } > "$CACHE_MARKER" 2>/dev/null || true
}

if [ "$REFRESH_MODE" = "cache-only" ]; then
  if [ -f "$REGISTRY_PATH" ]; then
    status="cached"
    print_result "$(cached_commit)"
    exit 0
  fi
  detail="Cache-only mode was requested, but no cached FPF Codex protocol repository exists."
  print_result "none"
  exit 2
fi

if [ "$REFRESH_MODE" != "refresh" ]; then
  detail="Unsupported FPF refresh mode: $REFRESH_MODE."
  print_result "none"
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  if [ -f "$REGISTRY_PATH" ]; then
    status="cached"
    warning="Git is unavailable; using the last cached Codex skills/protocols."
    print_result "$(cached_commit)"
    exit 0
  fi
  detail="Git is unavailable and no cached FPF Codex protocol repository exists."
  print_result "none"
  exit 2
fi

if [ ! -d "$CACHE_DIR/.git" ]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CACHE_DIR" >/dev/null 2>&1; then
    write_cache_marker
    status="fresh"
  else
    if [ -f "$REGISTRY_PATH" ]; then
      status="cached"
      warning="Could not clone the Codex skills/protocols from GitHub; using the last cached protocols."
      commit="$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
      print_result "$commit"
      exit 0
    fi
    detail="Could not clone the Codex skills/protocols from GitHub and no cached protocols exist."
    print_result "none"
    exit 2
  fi
else
  if ! cache_allows_hard_reset; then
    if [ -f "$REGISTRY_PATH" ]; then
      status="cached"
      warning="Refusing to run git reset --hard because the FPF protocols cache repository has no valid cache marker and its origin URL does not match the configured protocols repository; using cached protocols."
      print_result "$(cached_commit)"
      exit 0
    fi
    detail="Refusing to run git reset --hard because the FPF protocols cache repository has no valid cache marker and its origin URL does not match the configured protocols repository, and no cached protocols exist."
    print_result "none"
    exit 2
  fi
  if git -C "$CACHE_DIR" fetch --depth 1 origin "$BRANCH" >/dev/null 2>&1 \
    && git -C "$CACHE_DIR" checkout -q "$BRANCH" >/dev/null 2>&1 \
    && git -C "$CACHE_DIR" reset --hard "origin/$BRANCH" >/dev/null 2>&1; then
    write_cache_marker
    status="fresh"
  else
    if [ -f "$REGISTRY_PATH" ]; then
      status="cached"
      warning="Could not update the Codex skills/protocols from GitHub; using the last cached protocols."
      commit="$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
      print_result "$commit"
      exit 0
    fi
    detail="Could not update the Codex skills/protocols from GitHub and no cached protocols exist."
    print_result "none"
    exit 2
  fi
fi

if [ ! -f "$REGISTRY_PATH" ]; then
  status="missing"
  detail="The repository was fetched, but registry.yaml was not found at the repository root."
  print_result "$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
  exit 2
fi

print_result "$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
