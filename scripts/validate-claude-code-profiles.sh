#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
profiles_dir="$repo_root/claude-code"
failed=0

if [ ! -d "$profiles_dir" ]; then
  echo "ERROR: claude-code/ directory is missing" >&2
  exit 1
fi

if find "$profiles_dir" -name .DS_Store -print | grep -q .; then
  echo "ERROR: .DS_Store files are present under claude-code/" >&2
  find "$profiles_dir" -name .DS_Store -print >&2
  failed=1
fi

profile="$profiles_dir/fpf-work-guide"

for path in \
  "$profile/README.md" \
  "$profile/install.sh" \
  "$profile/install.ps1" \
  "$profile/command-templates/fpf-context.md" \
  "$profile/command-templates/fpf-doctor.md" \
  "$profile/agents/fpf-work-guide.md" \
  "$repo_root/skills/fpf-work-guide/SKILL.md"
do
  if [ ! -f "$path" ]; then
    echo "ERROR: missing Claude Code profile file: $path" >&2
    failed=1
  fi
done

if [ -f "$profile/install.sh" ]; then
  if ! bash -n "$profile/install.sh"; then
    failed=1
  fi
  if ! bash "$profile/install.sh" --check >/dev/null; then
    failed=1
  fi
fi

if [ -f "$profile/command-templates/fpf-context.md" ]; then
  if ! grep -q "allowed-tools: Bash(bash:\\*)" "$profile/command-templates/fpf-context.md"; then
    echo "ERROR: fpf-context.md must declare Bash allowed-tools" >&2
    failed=1
  fi
  if ! grep -q "update_fpf_context.sh" "$profile/command-templates/fpf-context.md"; then
    echo "ERROR: fpf-context.md must call update_fpf_context.sh" >&2
    failed=1
  fi
fi

if [ -f "$profile/command-templates/fpf-doctor.md" ]; then
  if ! grep -q "fpf-work-guide-doctor" "$profile/command-templates/fpf-doctor.md"; then
    echo "ERROR: fpf-doctor.md must call fpf-work-guide-doctor" >&2
    failed=1
  fi
fi

if [ -f "$profile/agents/fpf-work-guide.md" ]; then
  if ! grep -q "name: fpf-work-guide" "$profile/agents/fpf-work-guide.md"; then
    echo "ERROR: fpf-work-guide subagent must declare name" >&2
    failed=1
  fi
  if ! grep -q "update_fpf_context.sh" "$profile/agents/fpf-work-guide.md"; then
    echo "ERROR: fpf-work-guide subagent must mention the refresh gate" >&2
    failed=1
  fi
fi

if command -v pwsh >/dev/null 2>&1 && [ -f "$profile/install.ps1" ]; then
  if ! pwsh -NoProfile -File "$profile/install.ps1" -Check >/dev/null; then
    failed=1
  fi
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: Claude Code install profiles passed structural validation"
