$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path -Path $ScriptDir -ChildPath "fpf_common.ps1")

$HomeDir = Get-FpfHome
$RepoUrl = Get-FpfEnv "FPF_PROTOCOLS_REPO_URL" "https://github.com/ansea09/agent-skills-and-protocols.git"
$Branch = Get-FpfEnv "FPF_PROTOCOLS_BRANCH" "main"
$CodexHomeDir = Get-FpfEnv "CODEX_HOME" (Join-FpfPath $HomeDir @(".codex"))
$DefaultCacheHome = Get-FpfEnv "FPF_CACHE_HOME" (Join-FpfPath $CodexHomeDir @("cache"))
$DefaultCacheDir = Join-FpfPath $DefaultCacheHome @("agent-skills-and-protocols")
$CacheDir = Get-FpfEnv "FPF_PROTOCOLS_CACHE_DIR" $DefaultCacheDir
$CacheMarker = Join-FpfPath $CacheDir @(".fpf-cache-repo")
$ExpectedCacheKind = "fpf-protocols-cache"
$RegistryPath = Join-FpfPath $CacheDir @("registry.yaml")
$RefreshMode = Get-FpfEnv "FPF_REFRESH_MODE" (Get-FpfEnv "FPF_UPDATE_MODE" "refresh")

$script:Status = "missing"
$script:Warning = ""
$script:Detail = ""

function Write-Result {
  param([string]$Commit)

  Write-Output "FPF_PROTOCOLS_PATH=$CacheDir"
  Write-Output "FPF_PROTOCOLS_REGISTRY_PATH=$RegistryPath"
  Write-Output "FPF_PROTOCOLS_REPO_URL=$RepoUrl"
  Write-Output "FPF_PROTOCOLS_BRANCH=$Branch"
  Write-Output "FPF_PROTOCOLS_REMOTE_URL=$(Get-FpfGitRemoteUrl $CacheDir)"
  Write-Output "FPF_PROTOCOLS_CACHE_TRUST_STATUS=$(Get-FpfCacheTrustStatus $CacheDir $CacheMarker $ExpectedCacheKind $RepoUrl $Branch)"
  Write-Output "FPF_PROTOCOLS_COMMIT=$Commit"
  Write-Output "FPF_PROTOCOLS_STATUS=$($script:Status)"
  if ($script:Warning -ne "") { Write-Output "FPF_PROTOCOLS_WARNING=$($script:Warning)" }
  if ($script:Detail -ne "") { Write-Output "FPF_PROTOCOLS_DETAIL=$($script:Detail)" }
}

function Get-CachedCommit {
  if ((Test-FpfCommandAvailable "git") -and (Test-Path -LiteralPath (Join-FpfPath $CacheDir @(".git")) -PathType Container)) {
    $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "--verify", "HEAD")
    if ($commit) {
      return $commit
    }
  }
  return "unknown"
}

function Test-CacheAllowsHardReset {
  if (Test-FpfCacheMarkerMatches $CacheMarker $ExpectedCacheKind $RepoUrl $Branch) {
    return $true
  }
  if (Test-FpfGitRemoteMatches $CacheDir $RepoUrl) {
    return $true
  }
  if ((Get-FpfEnv "FPF_ALLOW_NONSTANDARD_CACHE_RESET" "0") -eq "1") {
    return $true
  }
  return $false
}

function Write-CacheMarker {
  try {
    Write-FpfAtomicLines $CacheMarker @(
      "kind=$ExpectedCacheKind",
      "repo=$RepoUrl",
      "branch=$Branch"
    )
  } catch {
  }
}

if ($RefreshMode -eq "cache-only") {
  if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
    $script:Status = "cached"
    Write-Result (Get-CachedCommit)
    exit 0
  }
  $script:Detail = "Cache-only mode was requested, but no cached FPF Codex protocol repository exists."
  Write-Result "none"
  exit 2
}

if ($RefreshMode -ne "refresh") {
  $script:Detail = "Unsupported FPF refresh mode: $RefreshMode."
  Write-Result "none"
  exit 2
}

if (-not (Test-FpfCommandAvailable "git")) {
  if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
    $script:Status = "cached"
    $script:Warning = "Git is unavailable; using the last cached agent skills/protocols."
    Write-Result (Get-CachedCommit)
    exit 0
  }
  $script:Detail = "Git is unavailable and no cached FPF Codex protocol repository exists."
  Write-Result "none"
  exit 2
}

$GitDir = Join-FpfPath $CacheDir @(".git")
if (-not (Test-Path -LiteralPath $GitDir -PathType Container)) {
  $parent = Split-Path -Parent $CacheDir
  if ($parent) {
    New-Item -ItemType Directory -Path $parent -Force > $null
  }
  if (Invoke-FpfGitQuiet @("clone", "--depth", "1", "--branch", $Branch, $RepoUrl, $CacheDir)) {
    Write-CacheMarker
    $script:Status = "fresh"
  } else {
    if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Could not clone the agent skills/protocols from GitHub; using the last cached protocols."
      $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
      if (-not $commit) { $commit = "unknown" }
      Write-Result $commit
      exit 0
    }
    $script:Detail = "Could not clone the agent skills/protocols from GitHub and no cached protocols exist."
    Write-Result "none"
    exit 2
  }
} else {
  if (-not (Test-CacheAllowsHardReset)) {
    if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Refusing to run git reset --hard because the FPF protocols cache repository has no valid cache marker and its origin URL does not match the configured protocols repository; using cached protocols."
      Write-Result (Get-CachedCommit)
      exit 0
    }
    $script:Detail = "Refusing to run git reset --hard because the FPF protocols cache repository has no valid cache marker and its origin URL does not match the configured protocols repository, and no cached protocols exist."
    Write-Result "none"
    exit 2
  }

  $updated = (Invoke-FpfGitQuiet @("-C", $CacheDir, "fetch", "--depth", "1", "origin", $Branch)) -and
    (Invoke-FpfGitQuiet @("-C", $CacheDir, "checkout", "-q", $Branch)) -and
    (Invoke-FpfGitQuiet @("-C", $CacheDir, "reset", "--hard", "origin/$Branch"))

  if ($updated) {
    Write-CacheMarker
    $script:Status = "fresh"
  } else {
    if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Could not update the agent skills/protocols from GitHub; using the last cached protocols."
      $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
      if (-not $commit) { $commit = "unknown" }
      Write-Result $commit
      exit 0
    }
    $script:Detail = "Could not update the agent skills/protocols from GitHub and no cached protocols exist."
    Write-Result "none"
    exit 2
  }
}

if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
  $script:Status = "missing"
  $script:Detail = "The repository was fetched, but registry.yaml was not found at the repository root."
  $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
  if (-not $commit) { $commit = "unknown" }
  Write-Result $commit
  exit 2
}

$finalCommit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
if (-not $finalCommit) { $finalCommit = "unknown" }
Write-Result $finalCommit
exit 0
