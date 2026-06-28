#!/usr/bin/env bash
# SessionStart hook for the Claude-native FPF Work Guide.
#
# Runs the FPF context refresh gate once at session start and prints its output
# so Claude has current FPF status in context before substantive work. The gate
# itself decides whether to refresh from GitHub or validate cache-only (TTL),
# so this is usually a fast cache check, not a network fetch.
#
# This hook MUST NOT block or fail session start: any error exits 0 with a short
# note instead of a non-zero status.
set -u

SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.claude/skills/fpf-work-guide}"
CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}"
STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}"
GATE="$SKILL_DIR/scripts/update_fpf_context.sh"

if [ ! -f "$GATE" ]; then
  echo "FPF Work Guide: skill not found at $SKILL_DIR. Run /fpf-doctor to check the install."
  exit 0
fi

echo "## FPF Work Guide — session-start gate"
if ! FPF_WORK_GUIDE_SKILL_DIR="$SKILL_DIR" \
     FPF_CACHE_HOME="$CACHE_HOME" \
     FPF_UPDATE_STATE_DIR="$STATE_DIR" \
     bash "$GATE" 2>&1; then
  echo "FPF Work Guide: the refresh gate could not complete cleanly."
  echo "Use the current cached copy if valid, or run /fpf-context to retry."
fi

exit 0
