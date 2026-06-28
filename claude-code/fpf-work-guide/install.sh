#!/usr/bin/env bash
set -euo pipefail

# Claude-native installer for the FPF Work Guide (hybrid layout).
#
# Shared source of truth lives in the Codex skill at skills/fpf-work-guide/
# (scripts/ + references/). This installer assembles a Claude-native skill at
# ~/.claude/skills/fpf-work-guide by copying that shared source and overlaying
# the Claude-native SKILL.md from this profile. It also installs the slash
# commands, the subagent, and (optionally) the SessionStart gate hook.
#
# The Codex build under skills/fpf-work-guide/ is never modified.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

claude_home="${CLAUDE_HOME:-$HOME/.claude}"
skills_dir="$claude_home/skills"
target="$skills_dir/fpf-work-guide"
commands_dir="$claude_home/commands"
agents_dir="$claude_home/agents"
settings_file="$claude_home/settings.json"

skill_src="$repo_root/skills/fpf-work-guide"   # shared Codex source (scripts/references)

run_doctor=1
install_hook=1
check_only=0

usage() {
  cat <<'EOF'
Usage: bash claude-code/fpf-work-guide/install.sh [--no-doctor] [--no-hook] [--check]

Installs the Claude-native FPF Work Guide into ~/.claude:
  ~/.claude/skills/fpf-work-guide/        (shared scripts/ + references/ + Claude SKILL.md + hooks/)
  ~/.claude/commands/fpf-context.md
  ~/.claude/commands/fpf-doctor.md
  ~/.claude/agents/fpf-work-guide.md
  ~/.claude/settings.json                 (SessionStart hook merged in, unless --no-hook)

Options:
  --no-doctor  Copy files without running the portable doctor.
  --no-hook    Do not register the SessionStart gate hook in settings.json.
  --check      Validate source files and exit without writing to ~/.claude.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-doctor) run_doctor=0 ;;
    --no-hook)   install_hook=0 ;;
    --check)     check_only=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

require_file() { [ -f "$1" ] || { echo "ERROR: missing required file: $1" >&2; exit 1; }; }
require_dir()  { [ -d "$1" ] || { echo "ERROR: missing required directory: $1" >&2; exit 1; }; }

# Shared source (from the Codex skill)
require_dir  "$skill_src"
require_dir  "$skill_src/scripts"
require_dir  "$skill_src/references"
require_file "$skill_src/scripts/update_fpf_context.sh"
require_file "$skill_src/scripts/fpf-work-guide-doctor"
# Claude-native overlay (from this profile)
require_file "$script_dir/SKILL.md"
require_file "$script_dir/agents/fpf-work-guide.md"
require_file "$script_dir/command-templates/fpf-context.md"
require_file "$script_dir/command-templates/fpf-doctor.md"
require_file "$script_dir/hooks/session-start.sh"

if [ "$check_only" -eq 1 ]; then
  echo "OK: Claude-native fpf-work-guide source files are present"
  exit 0
fi

mkdir -p "$target" "$commands_dir" "$agents_dir"

# Assemble the skill in a temp dir, then swap atomically.
tmp_skill="$skills_dir/.fpf-work-guide.tmp.$$"
rm -rf "$tmp_skill"
mkdir -p "$tmp_skill"
cp -R "$skill_src/scripts"    "$tmp_skill/scripts"
cp -R "$skill_src/references" "$tmp_skill/references"
cp    "$script_dir/SKILL.md"  "$tmp_skill/SKILL.md"
cp -R "$script_dir/hooks"      "$tmp_skill/hooks"
chmod +x "$tmp_skill/hooks/session-start.sh" 2>/dev/null || true
rm -rf "$target"
mv "$tmp_skill" "$target"

cp "$script_dir/command-templates/fpf-context.md" "$commands_dir/fpf-context.md"
cp "$script_dir/command-templates/fpf-doctor.md"  "$commands_dir/fpf-doctor.md"
cp "$script_dir/agents/fpf-work-guide.md"          "$agents_dir/fpf-work-guide.md"

echo "Installed Claude-native fpf-work-guide:"
echo "  skill:    $target"
echo "  command:  $commands_dir/fpf-context.md"
echo "  command:  $commands_dir/fpf-doctor.md"
echo "  subagent: $agents_dir/fpf-work-guide.md"

if [ "$install_hook" -eq 1 ]; then
  hook_cmd='bash "$HOME/.claude/skills/fpf-work-guide/hooks/session-start.sh"'
  if command -v python3 >/dev/null 2>&1; then
    SETTINGS_FILE="$settings_file" HOOK_CMD="$hook_cmd" python3 - <<'PY'
import json, os, sys

path = os.environ["SETTINGS_FILE"]
cmd  = os.environ["HOOK_CMD"]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        print(f"WARNING: could not parse {path} ({e}); leaving it untouched.", file=sys.stderr)
        print("Add the SessionStart hook manually from hooks/settings.snippet.json.", file=sys.stderr)
        sys.exit(0)

if not isinstance(data, dict):
    print(f"WARNING: {path} is not a JSON object; leaving it untouched.", file=sys.stderr)
    sys.exit(0)

hooks = data.setdefault("hooks", {})
sessionstart = hooks.setdefault("SessionStart", [])

def has_cmd(entries):
    for group in entries:
        for h in (group or {}).get("hooks", []):
            if isinstance(h, dict) and "session-start.sh" in str(h.get("command", "")):
                return True
    return False

if has_cmd(sessionstart):
    print("SessionStart gate hook already present; left as is.")
else:
    sessionstart.append({"hooks": [{"type": "command", "command": cmd}]})
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"Registered SessionStart gate hook in {path}")
PY
  else
    echo "WARNING: python3 not found; cannot merge settings.json safely."
    echo "Add the SessionStart hook manually from: $script_dir/hooks/settings.snippet.json"
  fi
else
  echo "Skipped SessionStart hook (--no-hook). The gate still runs via /fpf-context or the skill."
fi

if [ "$run_doctor" -eq 1 ]; then
  FPF_WORK_GUIDE_SKILL_DIR="$target" \
  FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}" \
  FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}" \
  bash "$target/scripts/fpf-work-guide-doctor" --write-state
else
  echo "Skipped doctor (--no-doctor). Run /fpf-doctor in Claude Code after opening a new session."
fi

echo "Open a new Claude Code session, then run /fpf-doctor or /fpf-context."
