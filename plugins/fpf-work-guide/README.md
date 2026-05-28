# FPF Work Guide Plugin

This plugin distributes the public `fpf-work-guide` Codex skill.

## What Is Included

- `skills/fpf-work-guide/SKILL.md`
- `skills/fpf-work-guide/scripts/`
- `skills/fpf-work-guide/references/`
- `skills/fpf-work-guide/agents/openai.yaml`

## What Is Not Included

This plugin intentionally does not include personal automation:

- local launchers such as `bin/codex-fpf`;
- macOS LaunchAgents;
- session-start hooks;
- workspace jobs;
- `.fpf-update/`, cache directories, logs, or machine-local env files.

Those are local operational infrastructure around the skill. They must be installed or adapted separately by the user or team that wants automatic session-start refresh behavior.

## Runtime Contract

The bundled skill is Codex/macOS-first and includes a native Windows PowerShell path. Fresh refresh requires Git and GitHub network access. The Bash path requires Bash and standard Unix utilities. The native Windows path uses the bundled `.ps1` scripts. Cache fallback is supported when FPF and protocol caches already exist.

Native Windows PowerShell is implemented through the `.ps1` scripts. CMD is implemented through thin `.cmd` wrappers that delegate to PowerShell. Treat Windows as release-verified only after the PowerShell/CMD validation lane has passed on the target host or CI runner. WSL Bash is supported. Git Bash on Windows is best effort.

FPF chunks are primary only when their declared source commit matches `FPF_SPEC_COMMIT`. If chunks are stale, the skill uses full-spec-first behavior and reports `FPF_CHUNKS_SOURCE_COMMIT`.

The protocol repository is treated as an instruction source. Its commit and cached/fresh status are part of the runtime trust boundary.

## Validation

From the repository root:

```bash
scripts/validate-plugins.sh
```

For a portable install check after installation:

```bash
bash "$PLUGIN_ROOT/skills/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

For non-default portable runs, set explicit skill, cache, and state paths instead of relying on `$HOME/.codex`, `$HOME/.agents`, or `$PWD/.fpf-update`:

```bash
FPF_WORK_GUIDE_SKILL_DIR="$PLUGIN_ROOT/skills/fpf-work-guide" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_WORK_GUIDE_SKILL_DIR/scripts/update_fpf_context.sh"
```

Native Windows PowerShell equivalent:

```powershell
$env:FPF_WORK_GUIDE_SKILL_DIR = "$env:PLUGIN_ROOT\skills\fpf-work-guide"
$env:FPF_CACHE_HOME = "C:\absolute\path\to\fpf-cache"
$env:FPF_UPDATE_STATE_DIR = "C:\absolute\path\to\fpf-state"
powershell -ExecutionPolicy Bypass -File "$env:FPF_WORK_GUIDE_SKILL_DIR\scripts\update_fpf_context.ps1"
```

CMD wrapper equivalent:

```bat
set "FPF_WORK_GUIDE_SKILL_DIR=%PLUGIN_ROOT%\skills\fpf-work-guide"
"%FPF_WORK_GUIDE_SKILL_DIR%\scripts\update_fpf_context.cmd"
```
