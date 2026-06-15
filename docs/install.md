# Installing Skills

These instructions install selected skills from this repository for local use in Codex or another agent runtime.

If you are not comfortable running installation commands manually, use the Russian prompt-first plugin guide:
[`install-plugins-for-nontechnical-users.md`](install-plugins-for-nontechnical-users.md).

## Codex Install Targets

Codex supports several skill discovery scopes. Use the smallest scope that matches the job:

| Target | Path | Use when |
| --- | --- | --- |
| Repo-scoped skill | `$REPO_ROOT/.agents/skills` | The skill should travel with one repository or workspace. |
| User-scoped skill | `$HOME/.agents/skills` | The skill should be available across the user's repositories. |
| Admin-scoped skill | `/etc/codex/skills` | A machine or container owner provides shared defaults. |
| Local legacy/current compatibility | `${CODEX_HOME:-$HOME/.codex}/skills` | A local Codex setup already loads skills from this path. |

This repository keeps staged public copies under `skills/`. That is the source artifact for review and adaptation, not automatically the runtime location.

Recommended user-scoped target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Repo-scoped target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$PWD/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Install one skill:

```bash
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
```

For quick user-facing instructions after copying a skill, read its staged
README when one exists. Current staged skill READMEs:

```text
skills/fpf-work-guide/README.md
skills/doc-to-md/README.md
skills/speech-to-md/README.md
```

### Migration From `fpf-latest`

The former local skill name was `fpf-latest`. The public skill is now named `fpf-work-guide`.

For a clean migration:

1. Install `skills/fpf-work-guide` into the active skill target.
2. Update launchers, docs, prompts, and shell variables that reference `fpf-latest` so they reference `fpf-work-guide`.
3. Keep existing FPF and protocol caches unless you have a concrete reason to rebuild them; the cache repositories are independent of the skill directory name.
4. Remove the old installed `fpf-latest` skill directory only after the new doctor and refresh gate succeed.

Typical compatibility cleanup:

```bash
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/update_fpf_context.sh"
```

For `doc-to-md`, install the skill source first, then build the local runtime:

```bash
cp -R skills/doc-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh"
```

Optional `doc-to-md` workflows are installed explicitly:

```bash
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh" --book
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh" --ocr
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh" --all
```

For `doc-to-md --hash-locked`, use only a published profile for the target OS,
architecture, and Python minor version. Current public profiles are documented
in `skills/doc-to-md/references/python-profiles.md`; unlisted Python minors are
candidate/unverified.

For `speech-to-md`, install the skill source first, then install the command
shim. The public skill does not install ASR models, `whisper.cpp` binaries, or
`ffmpeg`:

```bash
cp -R skills/speech-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/speech-to-md/scripts/install.sh"
speech-to-md --doctor
```

Transcript import works without ASR:

```bash
speech-to-md --transcript transcript.txt --source-audio recording.mp3 -o recording-audio-bundle
```

Local ASR requires a user-installed `whisper-cli` and model path:

```bash
export SPEECH_TO_MD_WHISPER_CPP_MODEL="/absolute/path/to/ggml-model.bin"
speech-to-md recording.mp3 -o recording-audio-bundle
```

MP3 may work directly through `whisper.cpp`; M4A/AAC/MP4 and other containers
normally use local `ffmpeg` normalization to mono 16 kHz WAV first:

```bash
export SPEECH_TO_MD_FFMPEG_BIN="/absolute/path/to/ffmpeg"
speech-to-md recording.m4a -o recording-audio-bundle --audio-normalization auto
```

Install all staged skills:

```bash
find skills -mindepth 1 -maxdepth 1 -type d -exec cp -R {} "$CODEX_SKILLS_TARGET/" \;
```

After installation, restart Codex or start a new Codex session so the skill list is reloaded.

If you install `fpf-work-guide` in Codex, run its portable doctor once:

```bash
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

The doctor does not contact GitHub. It verifies local shell tooling, Git availability, cache state, install completeness, and records a local environment state so normal runtime use does not repeat the check unless the environment changes or the refresh gate is blocked.

If your local Codex installation still loads skills from `${CODEX_HOME:-$HOME/.codex}/skills`, keep using that path as a local compatibility target:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export CODEX_SKILLS_TARGET="$CODEX_HOME/skills"
mkdir -p "$CODEX_SKILLS_TARGET"
```

For Claude Code or another non-Codex agent, install the same `fpf-work-guide` directory wherever that agent can read it, then run the doctor from that directory:

```bash
export FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide"
export FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-work-guide}"
export FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-work-guide}"
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/fpf-work-guide-doctor" --write-state
```

For WSL, use the same Bash command inside WSL. For Git Bash on Windows, the command is best effort. Native Windows PowerShell is implemented through the `.ps1` scripts; CMD can use the bundled `.cmd` wrappers, which delegate to PowerShell. Treat Windows as release-verified only after the PowerShell/CMD validation lane has passed on the target host or CI runner.

For native Windows PowerShell, install the same `fpf-work-guide` directory and run the PowerShell doctor:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "C:\absolute\path\to\fpf-work-guide"
$env:FPF_CACHE_HOME = "C:\absolute\path\to\fpf-cache"
$env:FPF_UPDATE_STATE_DIR = "C:\absolute\path\to\fpf-state"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\fpf-work-guide-doctor.ps1" --write-state
```

Then run the refresh gate through the PowerShell script:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

From CMD, use the wrappers:

```bat
set "FPF_WORK_GUIDE_SKILL_DIR=C:\absolute\path\to\fpf-work-guide"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\fpf-work-guide-doctor.cmd" --write-state
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\update_fpf_context.cmd"
```

## Claude Code Install Profiles

Codex plugins are not Claude Code plugins. For Claude Code, use source-only
install profiles under:

```text
claude-code/
```

Current profile:

```text
claude-code/fpf-work-guide
```

The `fpf-work-guide` Claude Code profile installs user slash commands, a
subagent, and a user-local copy of the public staged skill source. It does not
install a Codex plugin and does not use the Codex plugin marketplace.

On macOS, Linux, WSL, or Git Bash, run from the repository root:

```bash
bash claude-code/fpf-work-guide/install.sh
```

On native Windows PowerShell, run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\claude-code\fpf-work-guide\install.ps1
```

The profile installs source-only files under `~/.claude`:

```text
~/.claude/fpf-work-guide/skill
~/.claude/commands/fpf-context.md
~/.claude/commands/fpf-doctor.md
~/.claude/agents/fpf-work-guide.md
```

macOS Claude Code is the supported happy path for the profile. WSL and Git Bash
are best effort. Native Windows PowerShell entrypoints are implemented through
the underlying skill scripts and PowerShell installer, but remain
experimental/unverified until a Windows validation lane passes.

Portable installs should treat `$HOME/.codex`, `$HOME/.agents`, and `$PWD/.fpf-update` as defaults only. Use explicit paths when the agent runtime does not own those locations:

```bash
FPF_WORK_GUIDE_SKILL_DIR="/absolute/path/to/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Use exact cache paths only when the FPF specification and protocol repository must live in separate locations:

```bash
export FPF_SPEC_CACHE_DIR="/absolute/path/to/fpf-spec-mirror"
export FPF_PROTOCOLS_CACHE_DIR="/absolute/path/to/agent-skills-and-protocols"
```

Use exact state paths only when refresh state and environment state need separate lifecycle or permissions:

```bash
export FPF_REFRESH_STATE_DIR="/absolute/path/to/fpf-refresh-state"
export FPF_ENV_STATE_DIR="/absolute/path/to/fpf-env-state"
```

## Distribution Boundary

Direct skill folders are appropriate for local authoring, repo-scoped workflows, and personal setup. For reusable distribution to other developers or teams, package the skill as a Codex plugin or expose it through a plugin marketplace. Plugins are the installable distribution unit when the skill should be shared beyond one local checkout.

For non-technical plugin installation, use the prompt-first guide:
[`install-plugins-for-nontechnical-users.md`](install-plugins-for-nontechnical-users.md).

This repository includes a repo-local plugin marketplace at:

```text
.agents/plugins/marketplace.json
```

The plugin artifacts live at:

```text
plugins/fpf-work-guide
plugins/doc-to-md
plugins/speech-to-md
```

Each plugin bundles its public skill only. Plugins do not include personal launchers, LaunchAgents, session-start hooks, workspace jobs, cache, logs, local state files, private overlays, private local policy files, runtime venvs, OCR binaries, or generated outputs.

## Artifact Layers

Read [skill-artifact-model.md](skill-artifact-model.md) before packaging or redistributing skills. The installed operational copy under `$HOME/.agents/skills`, `$REPO_ROOT/.agents/skills`, `${CODEX_HOME:-$HOME/.codex}/skills`, or another agent-specific runtime location is not the same artifact as the public staged copy under `skills/`.

`fpf-work-guide` is the public skill. Local launchers, session-start hooks, LaunchAgents, workspace jobs, `.fpf-update/`, and `~/.local/state/codex-fpf/` are personal automation around that skill. They are not a public skill overlay and must not be installed or published as part of `skills/fpf-work-guide`.

Public installation may document that such automation can exist, but the staged skill contract remains the portable `fpf-work-guide` skill plus its bundled scripts.

If a workspace path is symlinked, read-only, shared by several agents, or ephemeral, pass an explicit `FPF_UPDATE_STATE_DIR` from the launcher or hook instead of relying on `$PWD/.fpf-update`. This keeps diagnostics and migration notes stable even when the shell reports the physical target path.

## Runtime State

`fpf-work-guide` uses local state files to decide whether the refresh gate should fetch from GitHub, skip because the TTL has not expired, or block because cache validation failed. These files are runtime state, not skill source.

Common state locations:

```text
$PWD/.fpf-update/latest.env
$PWD/.fpf-update/latest-output.env
$PWD/.fpf-update/environment.env
~/.local/state/codex-fpf/latest.env
~/.local/state/codex-fpf/latest-output.env
~/.local/state/codex-fpf/environment.env
```

`latest.env` is durable refresh-gate state written by `update_fpf_context.*`. `latest-output.env` is the last captured gate output written by local wrapper jobs such as a session-start launcher. Do not use wrapper output as the durable TTL state unless the gate reports it as the actual state source.

The workspace `.fpf-update/` state is usually used when the skill runs inside a repository or workspace. The `~/.local/state/codex-fpf/` state is commonly used by personal launchers or session-start hooks. Both can exist at the same time. By default a gate run reads only its configured `FPF_REFRESH_STATE_DIR`/`FPF_UPDATE_STATE_DIR` state file; it reads a secondary launcher/global state file only when `FPF_REFRESH_AUTO_STATE_FILE` is explicitly set. Always inspect `FPF_REFRESH_STATE_PATH`, `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`, and `FPF_ENV_CHECK_STATE_PATH` before deciding which state file controlled a run.

The portable doctor also reports path modes:

```text
FPF_ENV_CHECK_SKILL_PATH_MODE
FPF_ENV_CHECK_CACHE_PATH_MODE
FPF_ENV_CHECK_STATE_PATH_MODE
FPF_ENV_CHECK_PATH_POLICY_MODE
```

`FPF_ENV_CHECK_PATH_POLICY_MODE=portable-explicit` means the skill, cache, and state locations are all explicit enough for a non-default portable run. `mixed` is acceptable for local setups, but should be reviewed before publishing portability claims.

If the state path cannot be created, is not a directory, or is not writable, the refresh gate reports:

```text
FPF_REFRESH_REASON=state-dir-unavailable
```

If cache-only validation succeeds, the skill can continue with the current cached copy, but refresh timing is not durable because the state file could not be written. If cache-only validation fails, fix write permissions or set one of these variables to a writable directory:

```bash
export FPF_UPDATE_STATE_DIR="/writable/path/.fpf-update"
export FPF_REFRESH_STATE_DIR="$FPF_UPDATE_STATE_DIR"
export FPF_ENV_STATE_DIR="$FPF_UPDATE_STATE_DIR"
```

## Skill-Specific Notes

`fpf-work-guide` expects Git and network access when a refresh is required. On Unix-like shells it uses Bash and standard Unix utilities. On native Windows it uses the bundled PowerShell scripts. If network access is unavailable but a valid cache already exists, it can use the current cached copy and disclose that status. When Codex exposes `CODEX_SANDBOX_NETWORK_DISABLED=1`, the refresh gate uses cache-only validation and reports `FPF_REFRESH_REASON=sandbox-network-disabled` instead of attempting GitHub from inside the sandbox. Its scripts may run `git reset --hard` only when the cache directory contains a valid `.fpf-cache-repo` marker whose kind, repository URL, and branch match the configured cache, when the cache repository's `origin` remote matches the configured FPF/protocol repository URL, or when `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1` is explicitly set. Its user-facing install, portable invocation, Windows entrypoint, diagnostics, release notes, and publication guidance lives in `skills/fpf-work-guide/README.md`.

`doc-to-md` expects trusted local files by default. Its public skill source may include reusable workflow profiles such as `Textbook Audit + OCR Profile`, but personal defaults belong in a private local policy file and are not installed as a second public skill. Its user-facing install, workflow, OCR, diagnostics, release notes, and publication guidance lives in `skills/doc-to-md/README.md`.

`speech-to-md` expects trusted local speech audio or trusted existing
transcripts by default. Its public skill source may include command shims,
bundle builders, and runtime diagnostics, but ASR model files, `whisper.cpp`
binaries, `ffmpeg`, cloud credentials, private recordings, generated transcript
bundles, and personal defaults are local runtime or output artifacts. Its
user-facing install and runtime guidance lives in `skills/speech-to-md/README.md`.

This public repository currently stages `fpf-work-guide`, `doc-to-md`, and
`speech-to-md`. Other local or private skills should stay outside the public
staged `skills/` tree unless they are deliberately promoted later.
