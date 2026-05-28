---
allowed-tools: Bash(bash:*)
description: Check the Claude Code fpf-work-guide installation
---

## FPF Work Guide Doctor

Run the portable doctor for the Claude Code `fpf-work-guide` install profile.

Doctor output:

!`FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.claude/fpf-work-guide/skill}" FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}" FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}" bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state`

Summarize whether the installed profile is usable, whether it needs network
access for a fresh refresh, and whether any path/cache/state warnings need user
action.
