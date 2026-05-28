param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path -Path $ScriptDir -ChildPath "fpf_common.ps1")

$HomeDir = Get-FpfHome
$SkillDir = Split-Path -Parent $ScriptDir
$CodexHomeDir = Get-FpfEnv "CODEX_HOME" (Join-FpfPath $HomeDir @(".codex"))
$DefaultCacheHome = Get-FpfEnv "FPF_CACHE_HOME" (Join-FpfPath $CodexHomeDir @("cache"))
$SpecCacheDir = Get-FpfEnv "FPF_SPEC_CACHE_DIR" (Join-FpfPath $DefaultCacheHome @("fpf-spec-mirror"))
$SpecPath = Join-FpfPath $SpecCacheDir @("FPF-Spec.md")
$ProtocolsCacheDir = Get-FpfEnv "FPF_PROTOCOLS_CACHE_DIR" (Join-FpfPath $DefaultCacheHome @("agent-skills-and-protocols"))
$ProtocolsRegistryPath = Join-FpfPath $ProtocolsCacheDir @("registry.yaml")
$StateDir = Get-FpfEnv "FPF_ENV_STATE_DIR" (Get-FpfEnv "FPF_REFRESH_STATE_DIR" (Get-FpfEnv "FPF_UPDATE_STATE_DIR" (Join-FpfPath (Get-Location).Path @(".fpf-update"))))
$StateFile = Get-FpfEnv "FPF_ENV_STATE_FILE" (Join-FpfPath $StateDir @("environment.env"))
$WriteState = $false
$PortableCheck = $false
$StateFileArg = $false

function Show-Usage {
  Write-Output "Usage:"
  Write-Output "  check_fpf_environment.ps1 [-WriteState|--write-state] [-StateFile|--state-file PATH] [-PortableInstall|--portable-install]"
  Write-Output ""
  Write-Output "Checks whether the current PowerShell environment can run fpf-work-guide."
  Write-Output "It does not contact GitHub."
}

for ($i = 0; $i -lt $Arguments.Count; $i++) {
  switch ($Arguments[$i]) {
    { $_ -in @("-WriteState", "--write-state", "-write-state") } {
      $WriteState = $true
      continue
    }
    { $_ -in @("-PortableInstall", "--portable-install", "-portable-install", "-Doctor", "--doctor", "-doctor") } {
      $PortableCheck = $true
      continue
    }
    { $_ -in @("-StateFile", "--state-file", "-state-file") } {
      if (($i + 1) -ge $Arguments.Count) {
        Write-Error "ERROR: state file option requires a value"
        exit 2
      }
      $i++
      $StateFile = $Arguments[$i]
      $StateDir = Split-Path -Parent $StateFile
      $StateFileArg = $true
      continue
    }
    { $_ -in @("-Help", "--help", "-h") } {
      Show-Usage
      exit 0
    }
    default {
      Write-Error "ERROR: unknown argument: $($Arguments[$i])"
      Show-Usage
      exit 2
    }
  }
}

$StateDir = Split-Path -Parent $StateFile
if ([string]::IsNullOrEmpty($StateDir)) {
  $StateDir = "."
}

function Compare-StateField {
  param(
    [string]$Key,
    [string]$Current
  )
  $previous = Read-FpfKeyValue $StateFile $Key
  return $previous -eq $Current
}

function Write-EnvironmentState {
  Write-FpfAtomicLines $StateFile @(
    "CODEX_HOME_DIR=$CodexHomeDir",
    "SKILL_DIR=$SkillDir",
    "SKILL_PATH_MODE=$SkillPathMode",
    "DEFAULT_CACHE_HOME=$DefaultCacheHome",
    "SPEC_CACHE_DIR=$SpecCacheDir",
    "PROTOCOLS_CACHE_DIR=$ProtocolsCacheDir",
    "CACHE_PATH_MODE=$CachePathMode",
    "STATE_DIR=$StateDir",
    "STATE_PATH_MODE=$StatePathMode",
    "PATH_POLICY_MODE=$PathPolicyMode",
    "OS_NAME=$OsName",
    "OS_ARCH=$OsArch",
    "POWERSHELL_PATH=$PowerShellPath",
    "POWERSHELL_VERSION_VALUE=$PowerShellVersionValue",
    "GIT_PATH=$GitPath",
    "GIT_VERSION_VALUE=$GitVersionValue"
  )
}

$MissingRequired = ""
$MissingSkillFiles = ""

$OsName = "Unknown"
$OsArch = "unknown"
try {
  $OsArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
} catch {
  if ($env:PROCESSOR_ARCHITECTURE) {
    $OsArch = $env:PROCESSOR_ARCHITECTURE
  }
}
if (Test-FpfIsWindows) {
  $OsName = "Windows"
} else {
  $isMacVar = Get-Variable -Name IsMacOS -Scope Global -ErrorAction SilentlyContinue
  $isLinuxVar = Get-Variable -Name IsLinux -Scope Global -ErrorAction SilentlyContinue
  if ($null -ne $isMacVar -and [bool]$isMacVar.Value) {
    $OsName = "macOS"
  } elseif ($null -ne $isLinuxVar -and [bool]$isLinuxVar.Value) {
    $OsName = "Linux"
  }
}

$PowerShellPath = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
if (-not $PowerShellPath) {
  $PowerShellPath = "powershell"
}
$PowerShellVersionValue = $PSVersionTable.PSVersion.ToString()

$GitPath = Get-FpfCommandPath "git"
$GitVersionValue = "missing"
$GitStatus = "missing"
if ($GitPath -ne "missing") {
  $GitStatus = "available"
  $gitVersionOutput = & git --version 2>$null
  if ($LASTEXITCODE -eq 0 -and $gitVersionOutput) {
    $GitVersionValue = (($gitVersionOutput -join "`n").Trim() -replace '^git version ', '')
  }
}

if ($PowerShellVersionValue -eq "") {
  $MissingRequired = Append-FpfListItem $MissingRequired "PowerShell"
}

$CodexSkillDir = Join-FpfPath $CodexHomeDir @("skills", "fpf-work-guide")
$AgentsUserSkillDir = Join-FpfPath $HomeDir @(".agents", "skills", "fpf-work-guide")
$SkillDirId = Resolve-FpfPathIdentity $SkillDir
$CodexSkillDirId = Resolve-FpfPathIdentity $CodexSkillDir
$AgentsUserSkillDirId = Resolve-FpfPathIdentity $AgentsUserSkillDir

if ([string]::Equals($SkillDirId, $CodexSkillDirId, [StringComparison]::OrdinalIgnoreCase)) {
  $SkillPathMode = "codex-home-default"
} elseif ([string]::Equals($SkillDirId, $AgentsUserSkillDirId, [StringComparison]::OrdinalIgnoreCase)) {
  $SkillPathMode = "agents-user-default"
} else {
  $SkillPathMode = "explicit-or-nondefault"
}

if ((Test-FpfEnvSet "FPF_SPEC_CACHE_DIR") -or (Test-FpfEnvSet "FPF_PROTOCOLS_CACHE_DIR")) {
  $CachePathMode = "split-cache-override"
} elseif (Test-FpfEnvSet "FPF_CACHE_HOME") {
  $CachePathMode = "cache-home-override"
} elseif (Test-FpfEnvSet "CODEX_HOME") {
  $CachePathMode = "codex-home-override-cache"
} else {
  $CachePathMode = "codex-home-default-cache"
}

if ($StateFileArg) {
  $StatePathMode = "state-file-argument"
} elseif (Test-FpfEnvSet "FPF_ENV_STATE_FILE") {
  $StatePathMode = "state-file-override"
} elseif (Test-FpfEnvSet "FPF_ENV_STATE_DIR") {
  $StatePathMode = "env-state-dir-override"
} elseif (Test-FpfEnvSet "FPF_REFRESH_STATE_DIR") {
  $StatePathMode = "refresh-state-dir-override"
} elseif (Test-FpfEnvSet "FPF_UPDATE_STATE_DIR") {
  $StatePathMode = "update-state-dir-override"
} else {
  $StatePathMode = "workspace-default"
}

if ($SkillPathMode -eq "codex-home-default" -and $CachePathMode -eq "codex-home-default-cache" -and $StatePathMode -eq "workspace-default") {
  $PathPolicyMode = "codex-defaults"
} elseif ($SkillPathMode -eq "explicit-or-nondefault" -and ($CachePathMode -eq "cache-home-override" -or $CachePathMode -eq "split-cache-override") -and $StatePathMode -ne "workspace-default") {
  $PathPolicyMode = "portable-explicit"
} else {
  $PathPolicyMode = "mixed"
}

foreach ($utility in @(
  "fpf_common.ps1",
  "update_fpf_context.ps1",
  "update_fpf_spec.ps1",
  "update_fpf_protocols.ps1",
  "check_fpf_environment.ps1",
  "fpf-work-guide-doctor.ps1",
  "update_fpf_context.cmd",
  "fpf-work-guide-doctor.cmd"
)) {
  if (-not (Test-Path -LiteralPath (Join-FpfPath $ScriptDir @($utility)) -PathType Leaf)) {
    $MissingSkillFiles = Append-FpfListItem $MissingSkillFiles $utility
  }
}

$PortableStatus = "not_run"
$PortableReason = "not-requested"
$PortablePlatform = $OsName
$PortableAgentMode = "portable"
$PortableWindowsMode = "not-windows"
$PortableSummary = "Portable install check was not requested."
$PortableAction = "No action needed."
$PortableConsequence = "No portable-install claim was made."

if (Test-FpfPathEqual $CodexHomeDir (Join-FpfPath $HomeDir @(".codex"))) {
  $PortableAgentMode = "codex-default"
} else {
  $PortableAgentMode = "custom-codex-home"
}

if ($PortableCheck) {
  $PortableStatus = "ok"
  $PortableReason = "portable-install-ready"
  $PortableSummary = "Portable install check passed for this PowerShell environment."
  $PortableAction = "Run the refresh gate from this skill directory or from the agent-specific command in SKILL.md."
  $PortableConsequence = "The skill can validate cache and refresh from GitHub when Git and network access are available."

  if (Test-FpfIsWindows) {
    $PortablePlatform = "Windows PowerShell"
    $PortableWindowsMode = "native-powershell"
  } elseif ($OsName -eq "macOS") {
    $PortablePlatform = "macOS PowerShell"
  } elseif ($OsName -eq "Linux") {
    $PortablePlatform = "Linux PowerShell"
  } else {
    $PortableStatus = "degraded"
    $PortableReason = "unknown-powershell-platform"
    $PortableSummary = "This PowerShell platform is not part of the primary fpf-work-guide support contract."
    $PortableAction = "Proceed only after this doctor output is reviewed and the refresh gate succeeds."
    $PortableConsequence = "The skill may work, but portability is not guaranteed."
  }

  if ($MissingSkillFiles -ne "") {
    $PortableStatus = "blocked"
    $PortableReason = "missing-skill-files"
    $PortableSummary = "The fpf-work-guide skill installation is incomplete: $MissingSkillFiles."
    $PortableAction = "Reinstall the whole fpf-work-guide directory, including SKILL.md and scripts/."
    $PortableConsequence = "The refresh gate cannot be treated as portable or reliable until the missing files are restored."
  }
}

$SpecCacheStatus = "missing"
$ProtocolsCacheStatus = "missing"
$CacheStatus = "missing"

if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
  $SpecCacheStatus = "present"
}
if (Test-Path -LiteralPath $ProtocolsRegistryPath -PathType Leaf) {
  $ProtocolsCacheStatus = "present"
}

if ($SpecCacheStatus -eq "present" -and $ProtocolsCacheStatus -eq "present") {
  $CacheStatus = "ready"
} elseif ($SpecCacheStatus -eq "present" -or $ProtocolsCacheStatus -eq "present") {
  $CacheStatus = "partial"
}

$StateStatus = "same"
$StateDetail = "Environment state matches the recorded local state."
if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
  $StateStatus = "missing"
  $StateDetail = "No recorded local environment state exists."
} else {
  $ChangedFields = ""
  if (-not (Compare-StateField "CODEX_HOME_DIR" $CodexHomeDir)) { $ChangedFields = Append-FpfListItem $ChangedFields "CODEX_HOME_DIR" }
  if (-not (Compare-StateField "SKILL_DIR" $SkillDir)) { $ChangedFields = Append-FpfListItem $ChangedFields "SKILL_DIR" }
  if (-not (Compare-StateField "SKILL_PATH_MODE" $SkillPathMode)) { $ChangedFields = Append-FpfListItem $ChangedFields "SKILL_PATH_MODE" }
  if (-not (Compare-StateField "DEFAULT_CACHE_HOME" $DefaultCacheHome)) { $ChangedFields = Append-FpfListItem $ChangedFields "DEFAULT_CACHE_HOME" }
  if (-not (Compare-StateField "SPEC_CACHE_DIR" $SpecCacheDir)) { $ChangedFields = Append-FpfListItem $ChangedFields "SPEC_CACHE_DIR" }
  if (-not (Compare-StateField "PROTOCOLS_CACHE_DIR" $ProtocolsCacheDir)) { $ChangedFields = Append-FpfListItem $ChangedFields "PROTOCOLS_CACHE_DIR" }
  if (-not (Compare-StateField "CACHE_PATH_MODE" $CachePathMode)) { $ChangedFields = Append-FpfListItem $ChangedFields "CACHE_PATH_MODE" }
  if (-not (Compare-StateField "STATE_DIR" $StateDir)) { $ChangedFields = Append-FpfListItem $ChangedFields "STATE_DIR" }
  if (-not (Compare-StateField "STATE_PATH_MODE" $StatePathMode)) { $ChangedFields = Append-FpfListItem $ChangedFields "STATE_PATH_MODE" }
  if (-not (Compare-StateField "PATH_POLICY_MODE" $PathPolicyMode)) { $ChangedFields = Append-FpfListItem $ChangedFields "PATH_POLICY_MODE" }
  if (-not (Compare-StateField "OS_NAME" $OsName)) { $ChangedFields = Append-FpfListItem $ChangedFields "OS_NAME" }
  if (-not (Compare-StateField "OS_ARCH" $OsArch)) { $ChangedFields = Append-FpfListItem $ChangedFields "OS_ARCH" }
  if (-not (Compare-StateField "POWERSHELL_PATH" $PowerShellPath)) { $ChangedFields = Append-FpfListItem $ChangedFields "POWERSHELL_PATH" }
  if (-not (Compare-StateField "POWERSHELL_VERSION_VALUE" $PowerShellVersionValue)) { $ChangedFields = Append-FpfListItem $ChangedFields "POWERSHELL_VERSION_VALUE" }
  if (-not (Compare-StateField "GIT_PATH" $GitPath)) { $ChangedFields = Append-FpfListItem $ChangedFields "GIT_PATH" }
  if (-not (Compare-StateField "GIT_VERSION_VALUE" $GitVersionValue)) { $ChangedFields = Append-FpfListItem $ChangedFields "GIT_VERSION_VALUE" }
  if ($ChangedFields -ne "") {
    $StateStatus = "changed"
    $StateDetail = "Recorded local environment differs in: $ChangedFields."
  }
}

$Status = "ok"
$Reason = "environment-ready"
$Summary = "Environment check passed; required PowerShell runtime is available."
$Action = "No action needed."
$Consequence = "The refresh gate can use cache-only validation or refresh from GitHub when needed."

if ($MissingRequired -ne "") {
  $Status = "blocked"
  $Reason = "missing-required-commands"
  $Summary = "Required command line utilities are unavailable: $MissingRequired."
  $Action = "Install the missing command line tools or run this skill in an environment where those commands are available."
  $Consequence = "The FPF refresh gate cannot safely validate cache state or run an update."
} elseif ($GitStatus -eq "missing" -and $CacheStatus -eq "ready") {
  $Status = "degraded"
  $Reason = "git-missing-cache-ready"
  $Summary = "Git is unavailable, so refresh from GitHub cannot run; a complete local cache is available."
  $Action = "Install Git before relying on fresh GitHub updates."
  $Consequence = "The skill can use the current cached copy, but it cannot confirm that the cache is fresh."
} elseif ($GitStatus -eq "missing") {
  $Status = "blocked"
  $Reason = "git-missing-cache-incomplete"
  $Summary = "Git is unavailable and a complete local FPF cache was not found."
  $Action = "Install Git, or provide a valid local FPF and protocol cache."
  $Consequence = "FPF-backed work is blocked because the skill cannot fetch GitHub and cannot fall back to a complete cache."
} elseif ($CacheStatus -ne "ready") {
  $Reason = "cache-incomplete-git-available"
  $Summary = "Git is available; the local FPF cache is not complete."
  $Action = "No action needed if network access to GitHub is allowed."
  $Consequence = "The refresh gate can try to fetch the missing files; if GitHub is unavailable, FPF-backed work may be blocked."
}

if ($PortableCheck) {
  if ($PortableStatus -eq "blocked") {
    $Status = "blocked"
    $Reason = $PortableReason
    $Summary = $PortableSummary
    $Action = $PortableAction
    $Consequence = $PortableConsequence
  } elseif ($Status -eq "ok" -and $PortableStatus -eq "degraded") {
    $Status = "degraded"
    $Reason = $PortableReason
    $Summary = $PortableSummary
    $Action = $PortableAction
    $Consequence = $PortableConsequence
  }
}

if ($WriteState -and $Status -ne "blocked") {
  try {
    Write-EnvironmentState
    $StateStatus = "recorded"
    $StateDetail = "Current local environment state was recorded."
  } catch {
    $Status = "degraded"
    $Reason = "state-write-failed"
    $Summary = "Environment is usable, but the local environment state file could not be written."
    $Action = "Check write permissions for $StateDir."
    $Consequence = "The environment check may run again because no durable state was recorded."
  }
}

Write-Output "FPF_ENV_CHECK_STATUS=$Status"
Write-Output "FPF_ENV_CHECK_REASON=$Reason"
Write-Output "FPF_ENV_CHECK_SHELL_KIND=powershell"
Write-Output "FPF_ENV_CHECK_SKILL_DIR=$SkillDir"
Write-Output "FPF_ENV_CHECK_SKILL_PATH_MODE=$SkillPathMode"
Write-Output "FPF_ENV_CHECK_CACHE_HOME=$DefaultCacheHome"
Write-Output "FPF_ENV_CHECK_SPEC_CACHE_DIR=$SpecCacheDir"
Write-Output "FPF_ENV_CHECK_PROTOCOLS_CACHE_DIR=$ProtocolsCacheDir"
Write-Output "FPF_ENV_CHECK_CACHE_PATH_MODE=$CachePathMode"
Write-Output "FPF_ENV_CHECK_STATE_DIR=$StateDir"
Write-Output "FPF_ENV_CHECK_STATE_PATH_MODE=$StatePathMode"
Write-Output "FPF_ENV_CHECK_PATH_POLICY_MODE=$PathPolicyMode"
Write-Output "FPF_ENV_CHECK_STATE_STATUS=$StateStatus"
Write-Output "FPF_ENV_CHECK_STATE_PATH=$StateFile"
Write-Output "FPF_ENV_CHECK_STATE_DETAIL=$StateDetail"
Write-Output "FPF_ENV_CHECK_OS_NAME=$OsName"
Write-Output "FPF_ENV_CHECK_OS_ARCH=$OsArch"
Write-Output "FPF_ENV_CHECK_BASH_PATH=not-required"
Write-Output "FPF_ENV_CHECK_BASH_VERSION=not-required"
Write-Output "FPF_ENV_CHECK_POWERSHELL_PATH=$PowerShellPath"
Write-Output "FPF_ENV_CHECK_POWERSHELL_VERSION=$PowerShellVersionValue"
Write-Output "FPF_ENV_CHECK_GIT_STATUS=$GitStatus"
Write-Output "FPF_ENV_CHECK_GIT_PATH=$GitPath"
Write-Output "FPF_ENV_CHECK_GIT_VERSION=$GitVersionValue"
Write-Output "FPF_ENV_CHECK_CACHE_STATUS=$CacheStatus"
Write-Output "FPF_ENV_CHECK_SPEC_CACHE_STATUS=$SpecCacheStatus"
Write-Output "FPF_ENV_CHECK_PROTOCOLS_CACHE_STATUS=$ProtocolsCacheStatus"
Write-Output "FPF_ENV_CHECK_SUMMARY=$Summary"
Write-Output "FPF_ENV_CHECK_ACTION=$Action"
Write-Output "FPF_ENV_CHECK_CONSEQUENCE=$Consequence"

if ($PortableCheck) {
  Write-Output "FPF_PORTABLE_CHECK_STATUS=$PortableStatus"
  Write-Output "FPF_PORTABLE_CHECK_REASON=$PortableReason"
  Write-Output "FPF_PORTABLE_CHECK_PLATFORM=$PortablePlatform"
  Write-Output "FPF_PORTABLE_CHECK_WINDOWS_MODE=$PortableWindowsMode"
  Write-Output "FPF_PORTABLE_CHECK_AGENT_MODE=$PortableAgentMode"
  Write-Output "FPF_PORTABLE_CHECK_SKILL_DIR=$SkillDir"
  Write-Output "FPF_PORTABLE_CHECK_SUMMARY=$PortableSummary"
  Write-Output "FPF_PORTABLE_CHECK_ACTION=$PortableAction"
  Write-Output "FPF_PORTABLE_CHECK_CONSEQUENCE=$PortableConsequence"
}

if ($Status -eq "blocked") {
  exit 2
}

exit 0
