$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path -Path $ScriptDir -ChildPath "fpf_common.ps1")

$HomeDir = Get-FpfHome
$CodexHomeDir = Get-FpfEnv "CODEX_HOME" (Join-FpfPath $HomeDir @(".codex"))
$DefaultCacheHome = Get-FpfEnv "FPF_CACHE_HOME" (Join-FpfPath $CodexHomeDir @("cache"))
$StateDir = Get-FpfEnv "FPF_REFRESH_STATE_DIR" (Get-FpfEnv "FPF_UPDATE_STATE_DIR" (Join-FpfPath (Get-Location).Path @(".fpf-update")))
$StateFile = Join-FpfPath $StateDir @("latest.env")
$AutoStateFile = Get-FpfEnv "FPF_REFRESH_AUTO_STATE_FILE" ""
$LockDir = Join-FpfPath $StateDir @("update.lock")
$TtlSeconds = Get-FpfEnv "FPF_REFRESH_TTL_SECONDS" "21600"
$LockStaleSeconds = Get-FpfEnv "FPF_REFRESH_LOCK_STALE_SECONDS" "900"
$ForceRefresh = Get-FpfEnv "FPF_REFRESH_FORCE" (Get-FpfEnv "FPF_UPDATE_FORCE" "0")
$ForceReason = Get-FpfEnv "FPF_REFRESH_REASON" "forced"
$SpecCacheDir = Get-FpfEnv "FPF_SPEC_CACHE_DIR" (Join-FpfPath $DefaultCacheHome @("fpf-spec-mirror"))
$SpecPath = Join-FpfPath $SpecCacheDir @("FPF-Spec.md")
$ProtocolsCacheDir = Get-FpfEnv "FPF_PROTOCOLS_CACHE_DIR" (Join-FpfPath $DefaultCacheHome @("agent-skills-and-protocols"))
$ProtocolsRegistryPath = Join-FpfPath $ProtocolsCacheDir @("registry.yaml")
$EnvStateDir = Get-FpfEnv "FPF_ENV_STATE_DIR" $StateDir
$EnvStateFile = Get-FpfEnv "FPF_ENV_STATE_FILE" (Join-FpfPath $EnvStateDir @("environment.env"))
$EnvCheckScript = Join-FpfPath $ScriptDir @("check_fpf_environment.ps1")
$SpecScript = Join-FpfPath $ScriptDir @("update_fpf_spec.ps1")
$ProtocolsScript = Join-FpfPath $ScriptDir @("update_fpf_protocols.ps1")
$EnvCheckPolicy = Get-FpfEnv "FPF_ENV_CHECK_POLICY" "fingerprint"

$script:SpecOutput = ""
$script:ProtocolsOutput = ""
$script:SpecCode = 0
$script:ProtocolsCode = 0
$script:EnvironmentOutput = ""
$script:EnvironmentProbeOutput = ""
$script:EnvironmentCode = 0
$script:EnvironmentProbeCode = 0
$script:EnvironmentChecked = $false
$script:LockRecoveryDetail = ""
$script:StateErrorDetail = ""
$script:NowEpoch = 0
$script:LockAcquired = $false
$script:LastAttemptStatePath = "none"

function Test-StateDirReady {
  $detailValue = ""
  $detailRef = [ref]$detailValue
  if (Test-Path -LiteralPath $StateDir -PathType Leaf) {
    $script:StateErrorDetail = "FPF refresh state path exists but is not a directory: $StateDir."
    return $false
  }
  if (Test-FpfWritableDirectory $StateDir $detailRef) {
    $script:StateErrorDetail = ""
    return $true
  }
  $script:StateErrorDetail = "Could not create or write FPF refresh state directory: $StateDir."
  return $false
}

function Invoke-ChildScript {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Mode
  )

  $previousMode = [Environment]::GetEnvironmentVariable("FPF_REFRESH_MODE")
  [Environment]::SetEnvironmentVariable("FPF_REFRESH_MODE", $Mode, "Process")
  try {
    $output = & $Path 2>&1
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    return @{
      Output = (($output | ForEach-Object { $_.ToString() }) -join "`n")
      Code = [int]$code
    }
  } catch {
    return @{
      Output = $_.Exception.Message
      Code = 2
    }
  } finally {
    [Environment]::SetEnvironmentVariable("FPF_REFRESH_MODE", $previousMode, "Process")
  }
}

function Invoke-ContextScripts {
  param([Parameter(Mandatory = $true)][string]$Mode)

  $spec = Invoke-ChildScript $SpecScript $Mode
  $script:SpecOutput = $spec.Output
  $script:SpecCode = $spec.Code

  $protocols = Invoke-ChildScript $ProtocolsScript $Mode
  $script:ProtocolsOutput = $protocols.Output
  $script:ProtocolsCode = $protocols.Code
}

function Test-NeedsEnvironmentCheck {
  if ((Get-FpfEnv "FPF_ENV_CHECK_FORCE" (Get-FpfEnv "FPF_PREFLIGHT_FORCE" "0")) -eq "1") {
    return $true
  }
  if (-not (Test-Path -LiteralPath $EnvStateFile -PathType Leaf)) {
    return $true
  }
  if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf) -or -not (Test-Path -LiteralPath $ProtocolsRegistryPath -PathType Leaf)) {
    return $true
  }
  return $false
}

function Test-NeedsEnvironmentProbe {
  if ($EnvCheckPolicy -eq "on-demand" -or $EnvCheckPolicy -eq "disabled") {
    return $false
  }
  if ($script:EnvironmentChecked) {
    return $false
  }
  if (-not (Test-Path -LiteralPath $EnvStateFile -PathType Leaf)) {
    return $false
  }
  if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf) -or -not (Test-Path -LiteralPath $ProtocolsRegistryPath -PathType Leaf)) {
    return $false
  }
  return $true
}

function Invoke-EnvironmentCheck {
  if (-not (Test-Path -LiteralPath $EnvCheckScript -PathType Leaf)) {
    $script:EnvironmentOutput = @(
      "FPF_ENV_CHECK_STATUS=blocked",
      "FPF_ENV_CHECK_REASON=missing-environment-check-script",
      "FPF_ENV_CHECK_SUMMARY=The fpf-work-guide PowerShell environment check script is missing or not readable.",
      "FPF_ENV_CHECK_ACTION=Restore scripts/check_fpf_environment.ps1 in the fpf-work-guide skill.",
      "FPF_ENV_CHECK_CONSEQUENCE=The refresh gate cannot verify whether this environment is safe to use."
    ) -join "`n"
    $script:EnvironmentCode = 2
    $script:EnvironmentChecked = $true
    return $false
  }

  try {
    $output = & $EnvCheckScript "--state-file" $EnvStateFile "--write-state" 2>&1
    $script:EnvironmentOutput = (($output | ForEach-Object { $_.ToString() }) -join "`n")
    $script:EnvironmentCode = [int]$LASTEXITCODE
  } catch {
    $script:EnvironmentOutput = $_.Exception.Message
    $script:EnvironmentCode = 2
  }
  $script:EnvironmentChecked = $true
  return $script:EnvironmentCode -eq 0
}

function Invoke-EnvironmentProbe {
  if (-not (Test-Path -LiteralPath $EnvCheckScript -PathType Leaf)) {
    $script:EnvironmentProbeOutput = @(
      "FPF_ENV_CHECK_STATUS=blocked",
      "FPF_ENV_CHECK_REASON=missing-environment-check-script",
      "FPF_ENV_CHECK_SUMMARY=The fpf-work-guide PowerShell environment check script is missing or not readable.",
      "FPF_ENV_CHECK_ACTION=Restore scripts/check_fpf_environment.ps1 in the fpf-work-guide skill.",
      "FPF_ENV_CHECK_CONSEQUENCE=The refresh gate cannot verify whether this environment is safe to use."
    ) -join "`n"
    $script:EnvironmentProbeCode = 2
    return $false
  }

  try {
    $output = & $EnvCheckScript "--state-file" $EnvStateFile 2>&1
    $script:EnvironmentProbeOutput = (($output | ForEach-Object { $_.ToString() }) -join "`n")
    $script:EnvironmentProbeCode = [int]$LASTEXITCODE
  } catch {
    $script:EnvironmentProbeOutput = $_.Exception.Message
    $script:EnvironmentProbeCode = 2
  }
  return $script:EnvironmentProbeCode -eq 0
}

function Handle-EnvironmentProbe {
  if (-not (Invoke-EnvironmentProbe)) {
    $script:EnvironmentOutput = $script:EnvironmentProbeOutput
    $script:EnvironmentCode = $script:EnvironmentProbeCode
    $script:EnvironmentChecked = $true
    return $false
  }

  $probeStatus = Read-FpfOutputValue $script:EnvironmentProbeOutput "FPF_ENV_CHECK_STATUS"
  $probeStateStatus = Read-FpfOutputValue $script:EnvironmentProbeOutput "FPF_ENV_CHECK_STATE_STATUS"

  if ($probeStateStatus -eq "changed") {
    return (Invoke-EnvironmentCheck)
  }

  if ($probeStatus -eq "degraded") {
    $script:EnvironmentOutput = $script:EnvironmentProbeOutput
    $script:EnvironmentCode = 0
    $script:EnvironmentChecked = $true
  }

  return $true
}

function Acquire-Lock {
  try {
    New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop > $null
    return $true
  } catch {
  }

  $lockEpoch = Get-FpfPathMTimeEpoch $LockDir
  if ((Test-FpfUInt $LockStaleSeconds) -and ([int64]$LockStaleSeconds -gt 0) -and (Test-FpfUInt $lockEpoch)) {
    $lockAge = [int64]$script:NowEpoch - [int64]$lockEpoch
    if ($lockAge -ge [int64]$LockStaleSeconds) {
      try {
        [System.IO.Directory]::Delete($LockDir, $false)
        New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop > $null
        $script:LockRecoveryDetail = "Recovered stale FPF refresh lock older than ${LockStaleSeconds}s."
        return $true
      } catch {
      }
    }
  }
  return $false
}

function Release-Lock {
  if ($script:LockAcquired) {
    try {
      [System.IO.Directory]::Delete($LockDir, $false)
    } catch {
    }
    $script:LockAcquired = $false
  }
}

function Write-RefreshState {
  param(
    [Parameter(Mandatory = $true)][object]$AttemptEpoch,
    [Parameter(Mandatory = $true)][string]$Decision,
    [Parameter(Mandatory = $true)][string]$Reason,
    [Parameter(Mandatory = $true)][object]$NextEpoch
  )

  $specStatus = Read-FpfOutputValue $script:SpecOutput "FPF_SPEC_STATUS"
  if (-not $specStatus) { $specStatus = "unknown" }
  $specCommit = Read-FpfOutputValue $script:SpecOutput "FPF_SPEC_COMMIT"
  if (-not $specCommit) { $specCommit = "unknown" }
  $specRepoCommit = Read-FpfOutputValue $script:SpecOutput "FPF_SPEC_REPO_COMMIT"
  if (-not $specRepoCommit) { $specRepoCommit = $specCommit }
  $specSourceCommit = Read-FpfOutputValue $script:SpecOutput "FPF_SPEC_SOURCE_COMMIT"
  if (-not $specSourceCommit) { $specSourceCommit = "unknown" }
  $protocolsStatus = Read-FpfOutputValue $script:ProtocolsOutput "FPF_PROTOCOLS_STATUS"
  if (-not $protocolsStatus) { $protocolsStatus = "unknown" }
  $protocolsCommit = Read-FpfOutputValue $script:ProtocolsOutput "FPF_PROTOCOLS_COMMIT"
  if (-not $protocolsCommit) { $protocolsCommit = "unknown" }

  Write-FpfAtomicLines $StateFile @(
    "LAST_REFRESH_ATTEMPT_EPOCH=$AttemptEpoch",
    "LAST_REFRESH_ATTEMPT_AT=$(Format-FpfEpoch $AttemptEpoch)",
    "LAST_REFRESH_DECISION=$Decision",
    "LAST_REFRESH_REASON=$Reason",
    "FPF_REFRESH_TTL_SECONDS=$TtlSeconds",
    "FPF_REFRESH_NEXT_ELIGIBLE_EPOCH=$NextEpoch",
    "FPF_REFRESH_NEXT_ELIGIBLE_AT=$(Format-FpfEpoch $NextEpoch)",
    "FPF_SPEC_STATUS=$specStatus",
    "FPF_SPEC_COMMIT=$specCommit",
    "FPF_SPEC_REPO_COMMIT=$specRepoCommit",
    "FPF_SPEC_SOURCE_COMMIT=$specSourceCommit",
    "FPF_PROTOCOLS_STATUS=$protocolsStatus",
    "FPF_PROTOCOLS_COMMIT=$protocolsCommit"
  )
}

function Write-RefreshResult {
  param(
    [Parameter(Mandatory = $true)][string]$Decision,
    [Parameter(Mandatory = $true)][string]$Reason,
    [Parameter(Mandatory = $true)][object]$LastAttemptEpoch,
    [Parameter(Mandatory = $true)][object]$NextEligibleEpoch,
    [string]$Detail = ""
  )

  Write-Output "FPF_REFRESH_DECISION=$Decision"
  Write-Output "FPF_REFRESH_REASON=$Reason"
  Write-Output "FPF_REFRESH_TTL_SECONDS=$TtlSeconds"
  Write-Output "FPF_REFRESH_LOCK_STALE_SECONDS=$LockStaleSeconds"
  Write-Output "FPF_ENV_CHECK_POLICY=$EnvCheckPolicy"
  Write-Output "FPF_REFRESH_LAST_ATTEMPT_AT=$(Format-FpfEpoch $LastAttemptEpoch)"
  Write-Output "FPF_REFRESH_NEXT_ELIGIBLE_AT=$(Format-FpfEpoch $NextEligibleEpoch)"
  Write-Output "FPF_REFRESH_STATE_PATH=$StateFile"
  Write-Output "FPF_REFRESH_LAST_ATTEMPT_STATE_PATH=$($script:LastAttemptStatePath)"
  if ($AutoStateFile -ne "") {
    Write-Output "FPF_REFRESH_AUTO_STATE_PATH=$AutoStateFile"
  }
  if ($script:EnvironmentOutput -ne "") {
    Write-Output $script:EnvironmentOutput
  }
  if ($Detail -ne "") {
    Write-Output "FPF_REFRESH_DETAIL=$Detail"
  }
  if ($script:SpecOutput -ne "") {
    Write-Output $script:SpecOutput
  }
  if ($script:ProtocolsOutput -ne "") {
    Write-Output $script:ProtocolsOutput
  }
}

try {
  if (-not (Test-FpfUInt $TtlSeconds)) {
    $TtlSeconds = "21600"
  }
  if (-not (Test-FpfUInt $LockStaleSeconds)) {
    $LockStaleSeconds = "900"
  }

  if (-not (Test-StateDirReady)) {
    Invoke-ContextScripts "cache-only"
    if ($script:SpecCode -eq 0 -and $script:ProtocolsCode -eq 0) {
      Write-RefreshResult "skipped_recent" "state-dir-unavailable" "none" "none" "$($script:StateErrorDetail) Using cache-only validation without durable refresh state."
      exit 0
    }
    Write-RefreshResult "blocked" "state-dir-unavailable" "none" "none" "$($script:StateErrorDetail) Cache-only validation failed."
    exit 2
  }

  if (Test-NeedsEnvironmentCheck) {
    if (-not (Invoke-EnvironmentCheck)) {
      Write-RefreshResult "blocked" "environment-check" "none" "none"
      exit 2
    }
  } elseif (Test-NeedsEnvironmentProbe) {
    if (-not (Handle-EnvironmentProbe)) {
      Write-RefreshResult "blocked" "environment-check" "none" "none"
      exit 2
    }
  }

  $script:NowEpoch = Get-FpfEpochSeconds
  $lastAttemptEpoch = Read-FpfKeyValue $StateFile "LAST_REFRESH_ATTEMPT_EPOCH"
  if (-not (Test-FpfUInt $lastAttemptEpoch)) {
    $lastAttemptEpoch = ""
  } else {
    $script:LastAttemptStatePath = $StateFile
  }
  if ($lastAttemptEpoch -eq "" -and $AutoStateFile -ne "") {
    $autoAttemptEpoch = Read-FpfKeyValue $AutoStateFile "LAST_REFRESH_ATTEMPT_EPOCH"
    if (Test-FpfUInt $autoAttemptEpoch) {
      $lastAttemptEpoch = $autoAttemptEpoch
      $script:LastAttemptStatePath = $AutoStateFile
    }
  }

  $mode = "cache-only"
  $reason = "recent-cache"

  if ($ForceRefresh -eq "1") {
    $mode = "refresh"
    $reason = $ForceReason
  } elseif ($lastAttemptEpoch -eq "") {
    $mode = "refresh"
    $reason = "missing-state"
  } else {
    $ageSeconds = [int64]$script:NowEpoch - [int64]$lastAttemptEpoch
    if ($ageSeconds -ge [int64]$TtlSeconds) {
      $mode = "refresh"
      $reason = "ttl-expired"
    }
  }

  if ($mode -eq "cache-only") {
    $nextEligibleEpoch = [int64]$lastAttemptEpoch + [int64]$TtlSeconds
    Invoke-ContextScripts "cache-only"
    if ($script:SpecCode -eq 0 -and $script:ProtocolsCode -eq 0) {
      Write-RefreshResult "skipped_recent" $reason $lastAttemptEpoch $nextEligibleEpoch
      exit 0
    }
    $mode = "refresh"
    $reason = "missing-cache"
  }

  if ($lastAttemptEpoch -ne "") {
    $lastAttemptForOutput = $lastAttemptEpoch
  } else {
    $lastAttemptForOutput = "none"
  }

  if (-not (Acquire-Lock)) {
    if (-not (Test-StateDirReady)) {
      Invoke-ContextScripts "cache-only"
      if ($script:SpecCode -eq 0 -and $script:ProtocolsCode -eq 0) {
        Write-RefreshResult "skipped_recent" "state-dir-unavailable" $lastAttemptForOutput "none" "$($script:StateErrorDetail) Using cache-only validation without durable refresh state."
        exit 0
      }
      Write-RefreshResult "blocked" "state-dir-unavailable" $lastAttemptForOutput "none" "$($script:StateErrorDetail) Cache-only validation failed."
      exit 2
    }

    Invoke-ContextScripts "cache-only"
    if ($script:SpecCode -eq 0 -and $script:ProtocolsCode -eq 0) {
      if ($lastAttemptEpoch -ne "") {
        $nextEligibleEpoch = [int64]$lastAttemptEpoch + [int64]$TtlSeconds
      } else {
        $nextEligibleEpoch = "none"
      }
      Write-RefreshResult "skipped_recent" "active-refresh" $lastAttemptForOutput $nextEligibleEpoch "Another FPF refresh gate is already active; using cache-only validation."
      exit 0
    }

    if (-not $script:EnvironmentChecked) {
      [void](Invoke-EnvironmentCheck)
    }
    Write-RefreshResult "blocked" "active-refresh" $lastAttemptForOutput "none" "Another FPF refresh gate is active and cache-only validation failed."
    exit 2
  }
  $script:LockAcquired = $true

  $attemptEpoch = $script:NowEpoch
  $nextEligibleEpoch = [int64]$attemptEpoch + [int64]$TtlSeconds
  Invoke-ContextScripts "refresh"

  if ($script:SpecCode -eq 0 -and $script:ProtocolsCode -eq 0) {
    try { Write-RefreshState $attemptEpoch "attempted" $reason $nextEligibleEpoch } catch { }
    Write-RefreshResult "attempted" $reason $attemptEpoch $nextEligibleEpoch $script:LockRecoveryDetail
    exit 0
  }

  try { Write-RefreshState $attemptEpoch "blocked" $reason $nextEligibleEpoch } catch { }
  if (-not $script:EnvironmentChecked) {
    [void](Invoke-EnvironmentCheck)
  }
  Write-RefreshResult "blocked" $reason $attemptEpoch $nextEligibleEpoch
  exit 2
} finally {
  Release-Lock
}
