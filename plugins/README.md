# Plugins

This directory contains Codex plugin distribution artifacts.

Plugins are the packaging layer for sharing reusable skills beyond one local checkout or one repo-scoped `.agents/skills` folder. A plugin may bundle one or more skills and, later, optional app mappings, MCP server configuration, lifecycle hooks, and presentation assets.

Current plugins:

| Plugin | Purpose | Runtime notes |
| --- | --- | --- |
| [`fpf-work-guide`](fpf-work-guide/) | Distributes the public `fpf-work-guide` skill as an installable Codex plugin. | Skill-only package. No bundled hooks, apps, or MCP servers. Includes Bash, PowerShell, and CMD wrapper entrypoints. Requires Git for fresh refresh. |
| [`doc-to-md`](doc-to-md/) | Distributes the public `doc-to-md` skill as an installable Codex plugin. | Skill-only package. No bundled runtimes, OCR binaries, private local policies, or generated outputs. Users install core, book, and OCR runtimes locally as needed. |

The repo-local marketplace is defined at [`../.agents/plugins/marketplace.json`](../.agents/plugins/marketplace.json).
