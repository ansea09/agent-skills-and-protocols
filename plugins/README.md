# Plugins

This directory contains Codex plugin distribution artifacts.

For non-technical installation, start with the Russian prompt-first guide:
[`../docs/install-plugins-for-nontechnical-users.md`](../docs/install-plugins-for-nontechnical-users.md).

Plugins are the packaging layer for sharing reusable skills beyond one local checkout or one repo-scoped `.agents/skills` folder. A plugin may bundle one or more skills and, later, optional app mappings, MCP server configuration, lifecycle hooks, and presentation assets.

Current plugins:

| Plugin | Purpose | Runtime notes |
| --- | --- | --- |
| [`fpf-work-guide`](fpf-work-guide/) | Distributes the public `fpf-work-guide` skill as an installable Codex plugin. | Skill-only package with bundled skill README, Bash, PowerShell, and CMD wrapper entrypoints. Requires Git for fresh refresh. |
| [`doc-to-md`](doc-to-md/) | Distributes the public `doc-to-md` skill as an installable Codex plugin. | Skill-only package with bundled skill README. No bundled runtimes, OCR binaries, private local policies, or generated outputs. Users install core, book, and OCR runtimes locally as needed. |
| [`speech-to-md`](speech-to-md/) | Distributes the public `speech-to-md` skill as an installable Codex plugin. | Skill-only package with bundled skill README. No bundled ASR models, `whisper.cpp` binaries, `ffmpeg`, cloud credentials, private audio, transcripts, or generated bundles. |

The repo-local marketplace is defined at [`../.agents/plugins/marketplace.json`](../.agents/plugins/marketplace.json).
