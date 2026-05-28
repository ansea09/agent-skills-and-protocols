#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_APP_PATH="${CODEX_APP_PATH:-/Applications/Codex.app}"
DEFAULT_CACHE_HOME="${FPF_CACHE_HOME:-$CODEX_HOME_DIR/cache}"
SPEC_CACHE_DIR="${FPF_SPEC_CACHE_DIR:-$DEFAULT_CACHE_HOME/fpf-spec-mirror}"
SPEC_PATH="$SPEC_CACHE_DIR/FPF-Spec.md"
PROTOCOLS_CACHE_DIR="${FPF_PROTOCOLS_CACHE_DIR:-$DEFAULT_CACHE_HOME/codex-skills-and-protocols}"
PROTOCOLS_REGISTRY_PATH="$PROTOCOLS_CACHE_DIR/registry.yaml"
STATE_DIR="${FPF_ENV_STATE_DIR:-${FPF_REFRESH_STATE_DIR:-${FPF_UPDATE_STATE_DIR:-$PWD/.fpf-update}}}"
STATE_FILE="${FPF_ENV_STATE_FILE:-$STATE_DIR/environment.env}"
WRITE_STATE=0
PORTABLE_CHECK=0
STATE_FILE_ARG=0

usage() {
  cat <<'USAGE'
Usage:
  check_fpf_environment.sh [--write-state] [--state-file PATH] [--portable-install]

Checks whether the current shell environment can run fpf-work-guide.
It does not contact GitHub. It reports local tool/cache readiness,
compares the current environment with the last recorded environment state,
and can run a portable-install check for Codex, Claude Code, WSL, or Git Bash.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --write-state)
      WRITE_STATE=1
      shift
      ;;
    --state-file)
      [ "$#" -ge 2 ] || { echo "ERROR: --state-file requires a value" >&2; exit 2; }
      STATE_FILE="$2"
      STATE_DIR="$(dirname "$STATE_FILE")"
      STATE_FILE_ARG=1
      shift 2
      ;;
    --portable-install|--doctor)
      PORTABLE_CHECK=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

STATE_DIR="$(dirname "$STATE_FILE")"

append_list_item() {
  local current="$1"
  local item="$2"
  if [ -z "$current" ]; then
    printf '%s' "$item"
  else
    printf '%s, %s' "$current" "$item"
  fi
}

read_state_value() {
  local key="$1"
  [ -f "$STATE_FILE" ] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$STATE_FILE"
}

command_path() {
  command -v "$1" 2>/dev/null || printf 'missing'
}

command_version() {
  case "$1" in
    bash)
      bash --version 2>/dev/null | awk 'NR == 1 { print $4; exit }'
      ;;
    git)
      git --version 2>/dev/null | awk '{ print $3; exit }'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

path_mtime_epoch() {
  local path="$1"
  stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || printf 'missing'
}

path_identity() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" 2>/dev/null && pwd) || printf '%s' "$path"
  else
    printf '%s' "$path"
  fi
}

compare_state_field() {
  local key="$1"
  local current="$2"
  local previous
  previous="$(read_state_value "$key" 2>/dev/null || true)"
  [ "$previous" = "$current" ]
}

write_state() {
  local tmp_file
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  tmp_file="$STATE_FILE.$$"
  {
    printf 'CODEX_HOME_DIR=%s\n' "$CODEX_HOME_DIR"
    printf 'SKILL_DIR=%s\n' "$SKILL_DIR"
    printf 'SKILL_PATH_MODE=%s\n' "$SKILL_PATH_MODE"
    printf 'DEFAULT_CACHE_HOME=%s\n' "$DEFAULT_CACHE_HOME"
    printf 'SPEC_CACHE_DIR=%s\n' "$SPEC_CACHE_DIR"
    printf 'PROTOCOLS_CACHE_DIR=%s\n' "$PROTOCOLS_CACHE_DIR"
    printf 'CACHE_PATH_MODE=%s\n' "$CACHE_PATH_MODE"
    printf 'STATE_DIR=%s\n' "$STATE_DIR"
    printf 'STATE_PATH_MODE=%s\n' "$STATE_PATH_MODE"
    printf 'PATH_POLICY_MODE=%s\n' "$PATH_POLICY_MODE"
    printf 'CODEX_APP_PATH=%s\n' "$CODEX_APP_PATH"
    printf 'CODEX_APP_FINGERPRINT=%s\n' "$CODEX_APP_FINGERPRINT"
    printf 'OS_NAME=%s\n' "$OS_NAME"
    printf 'OS_ARCH=%s\n' "$OS_ARCH"
    printf 'SHELL_KIND=%s\n' "bash"
    printf 'BASH_PATH=%s\n' "$BASH_PATH"
    printf 'BASH_VERSION_VALUE=%s\n' "$BASH_VERSION_VALUE"
    printf 'GIT_PATH=%s\n' "$GIT_PATH"
    printf 'GIT_VERSION_VALUE=%s\n' "$GIT_VERSION_VALUE"
  } > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
}

missing_required=""
missing_skill_files=""
utility=""

for utility in awk bash date dirname mkdir mv rmdir stat uname; do
  if ! command -v "$utility" >/dev/null 2>&1; then
    missing_required="$(append_list_item "$missing_required" "$utility")"
  fi
done

OS_NAME="$(uname -s 2>/dev/null || printf 'unknown')"
OS_ARCH="$(uname -m 2>/dev/null || printf 'unknown')"
CODEX_APP_FINGERPRINT="not-found"
if [ -d "$CODEX_APP_PATH" ]; then
  CODEX_APP_FINGERPRINT="$(path_mtime_epoch "$CODEX_APP_PATH")"
fi
BASH_PATH="$(command_path bash)"
BASH_VERSION_VALUE="$(command_version bash)"
GIT_PATH="$(command_path git)"
GIT_VERSION_VALUE="missing"
GIT_STATUS="missing"
if [ "$GIT_PATH" != "missing" ]; then
  GIT_STATUS="available"
  GIT_VERSION_VALUE="$(command_version git)"
fi

CODEX_SKILL_DIR="$CODEX_HOME_DIR/skills/fpf-work-guide"
AGENTS_USER_SKILL_DIR="$HOME/.agents/skills/fpf-work-guide"
SKILL_DIR_ID="$(path_identity "$SKILL_DIR")"
CODEX_SKILL_DIR_ID="$(path_identity "$CODEX_SKILL_DIR")"
AGENTS_USER_SKILL_DIR_ID="$(path_identity "$AGENTS_USER_SKILL_DIR")"

if [ "$SKILL_DIR_ID" = "$CODEX_SKILL_DIR_ID" ]; then
  SKILL_PATH_MODE="codex-home-default"
elif [ "$SKILL_DIR_ID" = "$AGENTS_USER_SKILL_DIR_ID" ]; then
  SKILL_PATH_MODE="agents-user-default"
else
  SKILL_PATH_MODE="explicit-or-nondefault"
fi

if [ -n "${FPF_SPEC_CACHE_DIR+x}" ] || [ -n "${FPF_PROTOCOLS_CACHE_DIR+x}" ]; then
  CACHE_PATH_MODE="split-cache-override"
elif [ -n "${FPF_CACHE_HOME+x}" ]; then
  CACHE_PATH_MODE="cache-home-override"
elif [ -n "${CODEX_HOME+x}" ]; then
  CACHE_PATH_MODE="codex-home-override-cache"
else
  CACHE_PATH_MODE="codex-home-default-cache"
fi

if [ "$STATE_FILE_ARG" -eq 1 ]; then
  STATE_PATH_MODE="state-file-argument"
elif [ -n "${FPF_ENV_STATE_FILE+x}" ]; then
  STATE_PATH_MODE="state-file-override"
elif [ -n "${FPF_ENV_STATE_DIR+x}" ]; then
  STATE_PATH_MODE="env-state-dir-override"
elif [ -n "${FPF_REFRESH_STATE_DIR+x}" ]; then
  STATE_PATH_MODE="refresh-state-dir-override"
elif [ -n "${FPF_UPDATE_STATE_DIR+x}" ]; then
  STATE_PATH_MODE="update-state-dir-override"
else
  STATE_PATH_MODE="workspace-default"
fi

if [ "$SKILL_PATH_MODE" = "codex-home-default" ] \
  && [ "$CACHE_PATH_MODE" = "codex-home-default-cache" ] \
  && [ "$STATE_PATH_MODE" = "workspace-default" ]; then
  PATH_POLICY_MODE="codex-defaults"
elif [ "$SKILL_PATH_MODE" = "explicit-or-nondefault" ] \
  && { [ "$CACHE_PATH_MODE" = "cache-home-override" ] || [ "$CACHE_PATH_MODE" = "split-cache-override" ]; } \
  && [ "$STATE_PATH_MODE" != "workspace-default" ]; then
  PATH_POLICY_MODE="portable-explicit"
else
  PATH_POLICY_MODE="mixed"
fi

for utility in \
  update_fpf_context.sh \
  update_fpf_spec.sh \
  update_fpf_protocols.sh \
  check_fpf_environment.sh \
  fpf-work-guide-doctor \
  fpf_common.ps1 \
  update_fpf_context.ps1 \
  update_fpf_spec.ps1 \
  update_fpf_protocols.ps1 \
  check_fpf_environment.ps1 \
  fpf-work-guide-doctor.ps1 \
  update_fpf_context.cmd \
  fpf-work-guide-doctor.cmd
do
  if [ ! -r "$SCRIPT_DIR/$utility" ]; then
    missing_skill_files="$(append_list_item "$missing_skill_files" "$utility")"
  fi
done

PORTABLE_STATUS="not_run"
PORTABLE_REASON="not-requested"
PORTABLE_PLATFORM="$OS_NAME"
PORTABLE_AGENT_MODE="portable"
PORTABLE_WINDOWS_MODE="not-windows"
PORTABLE_SUMMARY="Portable install check was not requested."
PORTABLE_ACTION="No action needed."
PORTABLE_CONSEQUENCE="No portable-install claim was made."

if [ "$CODEX_HOME_DIR" = "$HOME/.codex" ]; then
  PORTABLE_AGENT_MODE="codex-default"
else
  PORTABLE_AGENT_MODE="custom-codex-home"
fi

if [ "$PORTABLE_CHECK" -eq 1 ]; then
  PORTABLE_STATUS="ok"
  PORTABLE_REASON="portable-install-ready"
  PORTABLE_SUMMARY="Portable install check passed for this Unix-like shell environment."
  PORTABLE_ACTION="Run the refresh gate from this skill directory or from the agent-specific command in SKILL.md."
  PORTABLE_CONSEQUENCE="The skill can validate cache and refresh from GitHub when Git and network access are available."

  case "$OS_NAME" in
    Darwin)
      PORTABLE_PLATFORM="macOS"
      ;;
    Linux)
      if [ -r /proc/version ] && grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
        PORTABLE_PLATFORM="WSL"
        PORTABLE_WINDOWS_MODE="wsl"
      else
        PORTABLE_PLATFORM="Linux"
        PORTABLE_STATUS="degraded"
        PORTABLE_REASON="linux-best-effort"
        PORTABLE_SUMMARY="This is a Unix-like shell, but the public contract is Codex/macOS-first plus WSL/Git Bash best effort."
        PORTABLE_ACTION="Proceed only if this agent can load the skill and run Bash scripts from the installed skill directory."
        PORTABLE_CONSEQUENCE="The shell scripts may work, but this is outside the primary published support target."
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PORTABLE_PLATFORM="Windows Unix shell"
      PORTABLE_WINDOWS_MODE="git-bash"
      PORTABLE_STATUS="degraded"
      PORTABLE_REASON="windows-git-bash-best-effort"
      PORTABLE_SUMMARY="Git Bash/MSYS/Cygwin-style execution is best effort; native PowerShell is implemented through the bundled .ps1 scripts and is release-verified only after the PowerShell validation lane passes."
      PORTABLE_ACTION="Use WSL or Git Bash with Bash, Git, and Unix utilities, or use the native PowerShell scripts."
      PORTABLE_CONSEQUENCE="The skill can be tested here, but path and process semantics may differ from macOS."
      ;;
    *)
      PORTABLE_STATUS="degraded"
      PORTABLE_REASON="unknown-unix-shell"
      PORTABLE_SUMMARY="The platform is not part of the primary fpf-work-guide support contract."
      PORTABLE_ACTION="Proceed only after this doctor output is reviewed and the refresh gate succeeds."
      PORTABLE_CONSEQUENCE="The skill may work, but portability is not guaranteed."
      ;;
  esac

  if [ -n "$missing_skill_files" ]; then
    PORTABLE_STATUS="blocked"
    PORTABLE_REASON="missing-skill-files"
    PORTABLE_SUMMARY="The fpf-work-guide skill installation is incomplete: $missing_skill_files."
    PORTABLE_ACTION="Reinstall the whole fpf-work-guide directory, including SKILL.md and scripts/."
    PORTABLE_CONSEQUENCE="The refresh gate cannot be treated as portable or reliable until the missing files are restored."
  fi
fi

SPEC_CACHE_STATUS="missing"
PROTOCOLS_CACHE_STATUS="missing"
CACHE_STATUS="missing"

if [ -f "$SPEC_PATH" ]; then
  SPEC_CACHE_STATUS="present"
fi
if [ -f "$PROTOCOLS_REGISTRY_PATH" ]; then
  PROTOCOLS_CACHE_STATUS="present"
fi

if [ "$SPEC_CACHE_STATUS" = "present" ] && [ "$PROTOCOLS_CACHE_STATUS" = "present" ]; then
  CACHE_STATUS="ready"
elif [ "$SPEC_CACHE_STATUS" = "present" ] || [ "$PROTOCOLS_CACHE_STATUS" = "present" ]; then
  CACHE_STATUS="partial"
fi

STATE_STATUS="same"
STATE_DETAIL="Environment state matches the recorded local state."
if [ ! -f "$STATE_FILE" ]; then
  STATE_STATUS="missing"
  STATE_DETAIL="No recorded local environment state exists."
else
  changed_fields=""
  compare_state_field CODEX_HOME_DIR "$CODEX_HOME_DIR" || changed_fields="$(append_list_item "$changed_fields" CODEX_HOME_DIR)"
  compare_state_field SKILL_DIR "$SKILL_DIR" || changed_fields="$(append_list_item "$changed_fields" SKILL_DIR)"
  compare_state_field SKILL_PATH_MODE "$SKILL_PATH_MODE" || changed_fields="$(append_list_item "$changed_fields" SKILL_PATH_MODE)"
  compare_state_field DEFAULT_CACHE_HOME "$DEFAULT_CACHE_HOME" || changed_fields="$(append_list_item "$changed_fields" DEFAULT_CACHE_HOME)"
  compare_state_field SPEC_CACHE_DIR "$SPEC_CACHE_DIR" || changed_fields="$(append_list_item "$changed_fields" SPEC_CACHE_DIR)"
  compare_state_field PROTOCOLS_CACHE_DIR "$PROTOCOLS_CACHE_DIR" || changed_fields="$(append_list_item "$changed_fields" PROTOCOLS_CACHE_DIR)"
  compare_state_field CACHE_PATH_MODE "$CACHE_PATH_MODE" || changed_fields="$(append_list_item "$changed_fields" CACHE_PATH_MODE)"
  compare_state_field STATE_DIR "$STATE_DIR" || changed_fields="$(append_list_item "$changed_fields" STATE_DIR)"
  compare_state_field STATE_PATH_MODE "$STATE_PATH_MODE" || changed_fields="$(append_list_item "$changed_fields" STATE_PATH_MODE)"
  compare_state_field PATH_POLICY_MODE "$PATH_POLICY_MODE" || changed_fields="$(append_list_item "$changed_fields" PATH_POLICY_MODE)"
  compare_state_field CODEX_APP_PATH "$CODEX_APP_PATH" || changed_fields="$(append_list_item "$changed_fields" CODEX_APP_PATH)"
  compare_state_field CODEX_APP_FINGERPRINT "$CODEX_APP_FINGERPRINT" || changed_fields="$(append_list_item "$changed_fields" CODEX_APP_FINGERPRINT)"
  compare_state_field OS_NAME "$OS_NAME" || changed_fields="$(append_list_item "$changed_fields" OS_NAME)"
  compare_state_field OS_ARCH "$OS_ARCH" || changed_fields="$(append_list_item "$changed_fields" OS_ARCH)"
  compare_state_field SHELL_KIND "bash" || changed_fields="$(append_list_item "$changed_fields" SHELL_KIND)"
  compare_state_field BASH_PATH "$BASH_PATH" || changed_fields="$(append_list_item "$changed_fields" BASH_PATH)"
  compare_state_field BASH_VERSION_VALUE "$BASH_VERSION_VALUE" || changed_fields="$(append_list_item "$changed_fields" BASH_VERSION_VALUE)"
  compare_state_field GIT_PATH "$GIT_PATH" || changed_fields="$(append_list_item "$changed_fields" GIT_PATH)"
  compare_state_field GIT_VERSION_VALUE "$GIT_VERSION_VALUE" || changed_fields="$(append_list_item "$changed_fields" GIT_VERSION_VALUE)"
  if [ -n "$changed_fields" ]; then
    STATE_STATUS="changed"
    STATE_DETAIL="Recorded local environment differs in: $changed_fields."
  fi
fi

STATUS="ok"
REASON="environment-ready"
SUMMARY="Environment check passed; required command line tools are available."
ACTION="No action needed."
CONSEQUENCE="The refresh gate can use cache-only validation or refresh from GitHub when needed."

if [ -n "$missing_required" ]; then
  STATUS="blocked"
  REASON="missing-required-commands"
  SUMMARY="Required command line utilities are unavailable: $missing_required."
  ACTION="Install the missing Unix-like command line tools or run this skill in an environment where those commands are available."
  CONSEQUENCE="The FPF refresh gate cannot safely validate cache state or run an update."
elif [ "$GIT_STATUS" = "missing" ] && [ "$CACHE_STATUS" = "ready" ]; then
  STATUS="degraded"
  REASON="git-missing-cache-ready"
  SUMMARY="Git is unavailable, so refresh from GitHub cannot run; a complete local cache is available."
  ACTION="Install Apple Command Line Tools or Git before relying on fresh GitHub updates."
  CONSEQUENCE="The skill can use the current cached copy, but it cannot confirm that the cache is fresh."
elif [ "$GIT_STATUS" = "missing" ]; then
  STATUS="blocked"
  REASON="git-missing-cache-incomplete"
  SUMMARY="Git is unavailable and a complete local FPF cache was not found."
  ACTION="Install Apple Command Line Tools or Git, or provide a valid local FPF and protocol cache."
  CONSEQUENCE="FPF-backed work is blocked because the skill cannot fetch GitHub and cannot fall back to a complete cache."
elif [ "$CACHE_STATUS" != "ready" ]; then
  REASON="cache-incomplete-git-available"
  SUMMARY="Git is available; the local FPF cache is not complete."
  ACTION="No action needed if network access to GitHub is allowed."
  CONSEQUENCE="The refresh gate can try to fetch the missing files; if GitHub is unavailable, FPF-backed work may be blocked."
fi

if [ "$PORTABLE_CHECK" -eq 1 ]; then
  if [ "$PORTABLE_STATUS" = "blocked" ]; then
    STATUS="blocked"
    REASON="$PORTABLE_REASON"
    SUMMARY="$PORTABLE_SUMMARY"
    ACTION="$PORTABLE_ACTION"
    CONSEQUENCE="$PORTABLE_CONSEQUENCE"
  elif [ "$STATUS" = "ok" ] && [ "$PORTABLE_STATUS" = "degraded" ]; then
    STATUS="degraded"
    REASON="$PORTABLE_REASON"
    SUMMARY="$PORTABLE_SUMMARY"
    ACTION="$PORTABLE_ACTION"
    CONSEQUENCE="$PORTABLE_CONSEQUENCE"
  fi
fi

if [ "$WRITE_STATE" -eq 1 ] && [ "$STATUS" != "blocked" ]; then
  if write_state; then
    STATE_STATUS="recorded"
    STATE_DETAIL="Current local environment state was recorded."
  else
    STATUS="degraded"
    REASON="state-write-failed"
    SUMMARY="Environment is usable, but the local environment state file could not be written."
    ACTION="Check write permissions for $STATE_DIR."
    CONSEQUENCE="The environment check may run again because no durable state was recorded."
  fi
fi

printf 'FPF_ENV_CHECK_STATUS=%s\n' "$STATUS"
printf 'FPF_ENV_CHECK_REASON=%s\n' "$REASON"
printf 'FPF_ENV_CHECK_SKILL_DIR=%s\n' "$SKILL_DIR"
printf 'FPF_ENV_CHECK_SKILL_PATH_MODE=%s\n' "$SKILL_PATH_MODE"
printf 'FPF_ENV_CHECK_CACHE_HOME=%s\n' "$DEFAULT_CACHE_HOME"
printf 'FPF_ENV_CHECK_SPEC_CACHE_DIR=%s\n' "$SPEC_CACHE_DIR"
printf 'FPF_ENV_CHECK_PROTOCOLS_CACHE_DIR=%s\n' "$PROTOCOLS_CACHE_DIR"
printf 'FPF_ENV_CHECK_CACHE_PATH_MODE=%s\n' "$CACHE_PATH_MODE"
printf 'FPF_ENV_CHECK_STATE_DIR=%s\n' "$STATE_DIR"
printf 'FPF_ENV_CHECK_STATE_PATH_MODE=%s\n' "$STATE_PATH_MODE"
printf 'FPF_ENV_CHECK_PATH_POLICY_MODE=%s\n' "$PATH_POLICY_MODE"
printf 'FPF_ENV_CHECK_CODEX_APP_PATH=%s\n' "$CODEX_APP_PATH"
printf 'FPF_ENV_CHECK_CODEX_APP_FINGERPRINT=%s\n' "$CODEX_APP_FINGERPRINT"
printf 'FPF_ENV_CHECK_STATE_STATUS=%s\n' "$STATE_STATUS"
printf 'FPF_ENV_CHECK_STATE_PATH=%s\n' "$STATE_FILE"
printf 'FPF_ENV_CHECK_STATE_DETAIL=%s\n' "$STATE_DETAIL"
printf 'FPF_ENV_CHECK_OS_NAME=%s\n' "$OS_NAME"
printf 'FPF_ENV_CHECK_OS_ARCH=%s\n' "$OS_ARCH"
printf 'FPF_ENV_CHECK_SHELL_KIND=%s\n' "bash"
printf 'FPF_ENV_CHECK_BASH_PATH=%s\n' "$BASH_PATH"
printf 'FPF_ENV_CHECK_BASH_VERSION=%s\n' "$BASH_VERSION_VALUE"
printf 'FPF_ENV_CHECK_GIT_STATUS=%s\n' "$GIT_STATUS"
printf 'FPF_ENV_CHECK_GIT_PATH=%s\n' "$GIT_PATH"
printf 'FPF_ENV_CHECK_GIT_VERSION=%s\n' "$GIT_VERSION_VALUE"
printf 'FPF_ENV_CHECK_CACHE_STATUS=%s\n' "$CACHE_STATUS"
printf 'FPF_ENV_CHECK_SPEC_CACHE_STATUS=%s\n' "$SPEC_CACHE_STATUS"
printf 'FPF_ENV_CHECK_PROTOCOLS_CACHE_STATUS=%s\n' "$PROTOCOLS_CACHE_STATUS"
printf 'FPF_ENV_CHECK_SUMMARY=%s\n' "$SUMMARY"
printf 'FPF_ENV_CHECK_ACTION=%s\n' "$ACTION"
printf 'FPF_ENV_CHECK_CONSEQUENCE=%s\n' "$CONSEQUENCE"

if [ "$PORTABLE_CHECK" -eq 1 ]; then
  printf 'FPF_PORTABLE_CHECK_STATUS=%s\n' "$PORTABLE_STATUS"
  printf 'FPF_PORTABLE_CHECK_REASON=%s\n' "$PORTABLE_REASON"
  printf 'FPF_PORTABLE_CHECK_PLATFORM=%s\n' "$PORTABLE_PLATFORM"
  printf 'FPF_PORTABLE_CHECK_WINDOWS_MODE=%s\n' "$PORTABLE_WINDOWS_MODE"
  printf 'FPF_PORTABLE_CHECK_AGENT_MODE=%s\n' "$PORTABLE_AGENT_MODE"
  printf 'FPF_PORTABLE_CHECK_SKILL_DIR=%s\n' "$SKILL_DIR"
  printf 'FPF_PORTABLE_CHECK_SUMMARY=%s\n' "$PORTABLE_SUMMARY"
  printf 'FPF_PORTABLE_CHECK_ACTION=%s\n' "$PORTABLE_ACTION"
  printf 'FPF_PORTABLE_CHECK_CONSEQUENCE=%s\n' "$PORTABLE_CONSEQUENCE"
fi

if [ "$STATUS" = "blocked" ]; then
  exit 2
fi

exit 0
