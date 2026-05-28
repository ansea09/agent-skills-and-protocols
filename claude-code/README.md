# Claude Code Install Profiles

This directory contains Claude Code install profiles for public skills in this
repository.

These profiles are not Codex plugins. They are Claude Code adapters that install
Claude Code-native artifacts such as slash commands and subagents while reusing
the public staged skill source under `skills/`.

Current profiles:

| Profile | Purpose | Status |
| --- | --- | --- |
| [`fpf-work-guide`](fpf-work-guide/) | Installs Claude Code slash commands and a subagent that invoke the public `fpf-work-guide` refresh gate and doctor. | macOS Bash path supported; WSL/Git Bash best effort; native Windows PowerShell path implemented through the underlying skill scripts and installer, but experimental/unverified until Windows validation passes. |

Profiles must stay source-only. They must not include local cache, state,
private overlays, runtime virtual environments, generated outputs, or personal
automation.
