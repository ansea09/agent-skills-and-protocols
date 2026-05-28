param(
  [switch]$NoDoctor,
  [switch]$Check
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$ClaudeHome = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }
$ProfileHome = if ($env:CLAUDE_FPF_PROFILE_HOME) { $env:CLAUDE_FPF_PROFILE_HOME } else { Join-Path $ClaudeHome "fpf-work-guide" }
$CommandsDir = Join-Path $ClaudeHome "commands"
$AgentsDir = Join-Path $ClaudeHome "agents"
$SkillSrc = Join-Path $RepoRoot "skills\fpf-work-guide"

function Require-File($Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Require-Dir($Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Missing required directory: $Path"
  }
}

Require-Dir $SkillSrc
Require-File (Join-Path $SkillSrc "SKILL.md")
Require-File (Join-Path $SkillSrc "scripts\update_fpf_context.ps1")
Require-File (Join-Path $SkillSrc "scripts\fpf-work-guide-doctor.ps1")
Require-File (Join-Path $ScriptDir "command-templates\fpf-context.md")
Require-File (Join-Path $ScriptDir "command-templates\fpf-doctor.md")
Require-File (Join-Path $ScriptDir "agents\fpf-work-guide.md")

if ($Check) {
  Write-Output "OK: Claude Code fpf-work-guide install profile source files are present"
  exit 0
}

New-Item -ItemType Directory -Force -Path $ProfileHome, $CommandsDir, $AgentsDir | Out-Null

$SkillDest = Join-Path $ProfileHome "skill"
$TmpSkill = Join-Path $ProfileHome ("skill.tmp." + [guid]::NewGuid().ToString("N"))
Copy-Item -LiteralPath $SkillSrc -Destination $TmpSkill -Recurse
if (Test-Path -LiteralPath $SkillDest) {
  Remove-Item -LiteralPath $SkillDest -Recurse -Force
}
Move-Item -LiteralPath $TmpSkill -Destination $SkillDest

Copy-Item -LiteralPath (Join-Path $ScriptDir "command-templates\fpf-context.md") -Destination (Join-Path $CommandsDir "fpf-context.md") -Force
Copy-Item -LiteralPath (Join-Path $ScriptDir "command-templates\fpf-doctor.md") -Destination (Join-Path $CommandsDir "fpf-doctor.md") -Force
Copy-Item -LiteralPath (Join-Path $ScriptDir "agents\fpf-work-guide.md") -Destination (Join-Path $AgentsDir "fpf-work-guide.md") -Force

Write-Output "Installed Claude Code fpf-work-guide profile:"
Write-Output "  skill:    $SkillDest"
Write-Output "  command:  $(Join-Path $CommandsDir "fpf-context.md")"
Write-Output "  command:  $(Join-Path $CommandsDir "fpf-doctor.md")"
Write-Output "  subagent: $(Join-Path $AgentsDir "fpf-work-guide.md")"

if (-not $NoDoctor) {
  $env:FPF_WORK_GUIDE_SKILL_DIR = $SkillDest
  if (-not $env:FPF_CACHE_HOME) {
    $env:FPF_CACHE_HOME = Join-Path $HOME ".cache\fpf-work-guide"
  }
  if (-not $env:FPF_UPDATE_STATE_DIR) {
    $env:FPF_UPDATE_STATE_DIR = Join-Path $HOME ".local\state\fpf-work-guide"
  }
  powershell -ExecutionPolicy Bypass -File (Join-Path $SkillDest "scripts\fpf-work-guide-doctor.ps1") --write-state
} else {
  Write-Output "Skipped doctor (-NoDoctor). Run /fpf-doctor in Claude Code after opening a new session."
}

Write-Output "Open a new Claude Code session, then run /fpf-doctor or /fpf-context."
