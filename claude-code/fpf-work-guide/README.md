# Claude-native FPF Work Guide (hybrid)

This profile installs a **Claude-native** build of the FPF Work Guide that runs
alongside the Codex build without changing it.

## Hybrid layout

The heavy logic — the refresh gate, cache handling, doctor, and the FPF/protocol
knowledge in `references/` — has a single source of truth in the Codex skill at
`skills/fpf-work-guide/`. This profile does **not** copy or fork that logic in
the repository; the installer pulls it at install time. Only the Claude-native
surface lives here:

| Layer | Source | Installed to |
| --- | --- | --- |
| Skill routing contract | `claude-code/fpf-work-guide/SKILL.md` | `~/.claude/skills/fpf-work-guide/SKILL.md` |
| Shared scripts + references | `skills/fpf-work-guide/{scripts,references}` | `~/.claude/skills/fpf-work-guide/{scripts,references}` |
| SessionStart gate hook | `claude-code/fpf-work-guide/hooks/` | `~/.claude/skills/fpf-work-guide/hooks/` + `~/.claude/settings.json` |
| Subagent | `claude-code/fpf-work-guide/agents/fpf-work-guide.md` | `~/.claude/agents/fpf-work-guide.md` |
| Slash commands | `claude-code/fpf-work-guide/command-templates/*` | `~/.claude/commands/{fpf-context,fpf-doctor}.md` |

Because the skill is installed under `~/.claude/skills/`, Claude Code
auto-discovers it and can trigger it from the `description` — not only via the
manual slash commands.

## What is Claude-native here

- `SKILL.md` frontmatter uses `name`, `description`, and `allowed-tools`; the
  description is written from user intent, with no Codex framing and no
  non-standard `compatibility` block (runtime detail lives in this README).
- Paths default to Claude/XDG locations: `~/.claude/skills/fpf-work-guide`,
  `~/.cache/fpf-work-guide`, `~/.local/state/fpf-work-guide` — no `CODEX_HOME`.
- The gate is wired three ways: a SessionStart hook (reliable first move), the
  `/fpf-context` command, and the skill itself.
- The mandatory Codex-style "engineering basis" footer is opt-in here, to match
  Claude's concise style; a one-line provenance note is the default.
- Windows PowerShell/CMD and Codex sandbox branches are out of scope for this
  Claude-native build (the shared scripts still contain them; they simply do not
  fire under Claude).

## Install (macOS / Linux / WSL)

From the repository root:

```bash
bash claude-code/fpf-work-guide/install.sh
```

Options:

- `--no-hook` — do not register the SessionStart gate hook (gate still available
  via `/fpf-context` and the skill).
- `--no-doctor` — copy files without running the doctor.
- `--check` — validate source files without writing to `~/.claude`.

If `python3` is unavailable, the installer cannot merge `settings.json`
automatically; add the hook manually from
[`hooks/settings.snippet.json`](hooks/settings.snippet.json).

## Use

Open a new Claude Code session, then:

```text
/fpf-doctor     # verify the install
/fpf-context    # run the gate on demand
```

With the SessionStart hook installed, the gate runs once at session start and
its output is added to context, so Claude has current FPF status before
substantive work. The gate decides refresh-vs-cache by TTL, so this is usually a
fast cache check rather than a network fetch. A fresh refresh needs `git` and
GitHub network access; with a valid cache and no network, Claude uses the
current cached copy and discloses that.

## Artifact boundary

This profile is source-only distribution glue. It must not contain local cache
or state, `.fpf-update/`, private overlays, private local policy files, personal
launchers or scheduled jobs, or generated outputs.

## Relationship to the Codex build

`skills/fpf-work-guide/` remains the Codex-native build and the single source of
the shared logic. Fixes to the gate, cache, doctor, or references go there once
and are picked up by both builds at install time. Only `SKILL.md` wording, the
hook, the subagent, the commands, and install paths are duplicated here — the
cheap, runtime-specific surface — so the two builds stay native without drifting
on the expensive logic.
