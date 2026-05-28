#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

claude_home="${CLAUDE_HOME:-$HOME/.claude}"
profile_home="${CLAUDE_FPF_PROFILE_HOME:-$claude_home/fpf-work-guide}"
commands_dir="$claude_home/commands"
agents_dir="$claude_home/agents"
skill_src="$repo_root/skills/fpf-work-guide"

run_doctor=1
check_only=0

usage() {
  cat <<'EOF'
Usage: bash claude-code/fpf-work-guide/install.sh [--no-doctor] [--check]

Installs the Claude Code fpf-work-guide profile into ~/.claude by default.

Options:
  --no-doctor  Copy files without running the portable doctor.
  --check      Validate source files and exit without writing to ~/.claude.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-doctor)
      run_doctor=0
      ;;
    --check)
      check_only=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: missing required file: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    echo "ERROR: missing required directory: $1" >&2
    exit 1
  fi
}

require_dir "$skill_src"
require_file "$skill_src/SKILL.md"
require_file "$skill_src/scripts/update_fpf_context.sh"
require_file "$skill_src/scripts/fpf-work-guide-doctor"
require_file "$script_dir/command-templates/fpf-context.md"
require_file "$script_dir/command-templates/fpf-doctor.md"
require_file "$script_dir/agents/fpf-work-guide.md"

if [ "$check_only" -eq 1 ]; then
  echo "OK: Claude Code fpf-work-guide install profile source files are present"
  exit 0
fi

mkdir -p "$profile_home" "$commands_dir" "$agents_dir"

tmp_skill="$profile_home/skill.tmp.$$"
rm -rf "$tmp_skill"
cp -R "$skill_src" "$tmp_skill"
rm -rf "$profile_home/skill"
mv "$tmp_skill" "$profile_home/skill"

cp "$script_dir/command-templates/fpf-context.md" "$commands_dir/fpf-context.md"
cp "$script_dir/command-templates/fpf-doctor.md" "$commands_dir/fpf-doctor.md"
cp "$script_dir/agents/fpf-work-guide.md" "$agents_dir/fpf-work-guide.md"

echo "Installed Claude Code fpf-work-guide profile:"
echo "  skill:    $profile_home/skill"
echo "  command:  $commands_dir/fpf-context.md"
echo "  command:  $commands_dir/fpf-doctor.md"
echo "  subagent: $agents_dir/fpf-work-guide.md"

if [ "$run_doctor" -eq 1 ]; then
  FPF_WORK_GUIDE_SKILL_DIR="$profile_home/skill" \
  FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}" \
  FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}" \
  bash "$profile_home/skill/scripts/fpf-work-guide-doctor" --write-state
else
  echo "Skipped doctor (--no-doctor). Run /fpf-doctor in Claude Code after opening a new session."
fi

echo "Open a new Claude Code session, then run /fpf-doctor or /fpf-context."
