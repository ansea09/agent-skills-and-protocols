# Claude Code Install Profile: fpf-work-guide

This profile installs Claude Code-native entrypoints for the public
`fpf-work-guide` skill:

- user slash command `/fpf-context`;
- user slash command `/fpf-doctor`;
- user subagent `fpf-work-guide`;
- a user-local copy of the public skill source at
  `~/.claude/fpf-work-guide/skill`.

The profile does not install a Codex plugin and does not use the Codex plugin
marketplace. It reuses the same public skill source from `skills/fpf-work-guide`.

## Support Status

| Runtime | Status | Notes |
| --- | --- | --- |
| Claude Code on macOS | Supported path | Uses Bash slash commands and the public skill shell scripts. |
| Claude Code on WSL | Candidate / best effort | Uses the Bash path inside WSL with explicit cache and state paths. |
| Claude Code with Git Bash on Windows | Best effort | Path/process semantics may differ from macOS. |
| Claude Code on native Windows PowerShell | Implemented but experimental/unverified | The underlying skill has PowerShell scripts and this profile has a PowerShell installer; slash-command Bash pre-exec behavior may not match macOS. |

Fresh refresh requires `git` and GitHub network access. If a valid FPF/protocol
cache already exists, the skill can use the current cached copy and must
disclose cached/fresh status.

## Install On macOS, Linux, WSL, Or Git Bash

From the repository root:

```bash
bash claude-code/fpf-work-guide/install.sh
```

The installer copies source-only artifacts into `~/.claude`:

```text
~/.claude/fpf-work-guide/skill
~/.claude/commands/fpf-context.md
~/.claude/commands/fpf-doctor.md
~/.claude/agents/fpf-work-guide.md
```

It then runs the portable doctor with Claude Code-specific cache/state paths:

```bash
FPF_WORK_GUIDE_SKILL_DIR="$HOME/.claude/fpf-work-guide/skill" \
FPF_CACHE_HOME="$HOME/.cache/fpf-work-guide" \
FPF_UPDATE_STATE_DIR="$HOME/.local/state/fpf-work-guide" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state
```

Use `--no-doctor` to copy files without running the doctor.
Use `--check` to validate the profile without writing to `~/.claude`.

## Install On Native Windows PowerShell

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\claude-code\fpf-work-guide\install.ps1
```

The installer copies source-only artifacts into `%USERPROFILE%\.claude` and runs
the PowerShell doctor against the installed skill copy.

Use `-NoDoctor` to copy files without running the doctor.
Use `-Check` to validate the profile without writing to `%USERPROFILE%\.claude`.

## Claude Code Commands

After opening a new Claude Code session, run:

```text
/fpf-doctor
/fpf-context
```

`/fpf-context` runs the refresh gate and then asks Claude to use the gate output
before doing substantive FPF-backed work.

## Artifact Boundary

This profile is source-only distribution glue for Claude Code. It must not
contain:

- local cache or state;
- `.fpf-update/`;
- private overlays;
- private local policy files;
- personal launchers or scheduled jobs;
- generated outputs.
