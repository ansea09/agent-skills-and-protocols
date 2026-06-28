---
allowed-tools: Bash(bash:*)
argument-hint: [optional task or focus]
description: Refresh or validate FPF context before FPF-backed work
---

## FPF Context Gate

Run the `fpf-work-guide` refresh gate before doing substantive FPF-backed work.

Gate output:

!`FPF_WORK_GUIDE_SKILL_DIR="${FPF_WORK_GUIDE_SKILL_DIR:-$HOME/.claude/skills/fpf-work-guide}" FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}" FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}" bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"`

Use the gate output before answering. If the gate reports cached status, say
`current cached copy` rather than `latest`. If it reports blocked or degraded
state, explain the blocking condition before proceeding.

User focus:

```text
$ARGUMENTS
```
