$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path -Path $ScriptDir -ChildPath "fpf_common.ps1")

$HomeDir = Get-FpfHome
$RepoUrl = Get-FpfEnv "FPF_SPEC_REPO_URL" "https://github.com/ansea09/fpf-spec-mirror.git"
$Branch = Get-FpfEnv "FPF_SPEC_BRANCH" "main"
$CodexHomeDir = Get-FpfEnv "CODEX_HOME" (Join-FpfPath $HomeDir @(".codex"))
$DefaultCacheHome = Get-FpfEnv "FPF_CACHE_HOME" (Join-FpfPath $CodexHomeDir @("cache"))
$DefaultCacheDir = Join-FpfPath $DefaultCacheHome @("fpf-spec-mirror")
$CacheDir = Get-FpfEnv "FPF_SPEC_CACHE_DIR" $DefaultCacheDir
$CacheMarker = Join-FpfPath $CacheDir @(".fpf-cache-repo")
$ExpectedCacheKind = "fpf-spec-cache"
$SpecPath = Join-FpfPath $CacheDir @("FPF-Spec.md")
$ChunksLayoutManifestPath = Get-FpfEnv "FPF_CHUNKS_LAYOUT_MANIFEST_PATH" (Join-FpfPath $CacheDir @("fpf-chunks-layout.env"))
$RefreshMode = Get-FpfEnv "FPF_REFRESH_MODE" (Get-FpfEnv "FPF_UPDATE_MODE" "refresh")

$script:Status = "missing"
$script:Warning = ""
$script:Detail = ""
$script:ChunksLayoutStatus = "legacy"
$script:ChunksLayoutSource = "legacy-defaults"
$script:ChunksLayoutVersion = "legacy-1"
$script:ChunksLayoutDetail = ""
$script:ChunksRootRel = "fpf_chunks"
$script:ChunksIndexRel = "000-index.md"
$script:ChunksMetadataRel = "metadata.jsonl"
$script:ChunksByPatternRel = "by_pattern"
$script:ChunksBySectionRel = "by_section"
$script:ChunksNonPatternsRel = "non_patterns"
$script:ChunksPath = ""
$script:ChunksIndexPath = ""
$script:ChunksMetadataPath = ""
$script:ChunksByPatternDir = ""
$script:ChunksBySectionDir = ""
$script:ChunksNonPatternsDir = ""
$script:ChunksStatus = "missing"
$script:ChunksMode = "blocked"
$script:ChunksWarning = ""
$script:ChunksDetail = ""
$script:ChunksSourceCommit = "unknown"

function Set-ChunkPaths {
  $script:ChunksPath = Join-FpfPath $CacheDir @($script:ChunksRootRel)
  $script:ChunksIndexPath = Join-FpfPath $script:ChunksPath @($script:ChunksIndexRel)
  $script:ChunksMetadataPath = Join-FpfPath $script:ChunksPath @($script:ChunksMetadataRel)
  $script:ChunksByPatternDir = Join-FpfPath $script:ChunksPath @($script:ChunksByPatternRel)
  $script:ChunksBySectionDir = Join-FpfPath $script:ChunksPath @($script:ChunksBySectionRel)
  $script:ChunksNonPatternsDir = Join-FpfPath $script:ChunksPath @($script:ChunksNonPatternsRel)
}

function Test-LayoutManifestHasRequiredKeys {
  $required = @(
    "FPF_CHUNKS_LAYOUT_VERSION",
    "FPF_CHUNKS_ROOT",
    "FPF_CHUNKS_INDEX",
    "FPF_CHUNKS_METADATA",
    "FPF_CHUNKS_BY_PATTERN",
    "FPF_CHUNKS_BY_SECTION",
    "FPF_CHUNKS_NON_PATTERNS"
  )

  foreach ($key in $required) {
    if ($null -eq (Read-FpfLooseKeyValue $ChunksLayoutManifestPath $key)) {
      return $false
    }
  }
  return $true
}

function Load-ChunkLayout {
  $script:ChunksLayoutStatus = "legacy"
  $script:ChunksLayoutSource = "legacy-defaults"
  $script:ChunksLayoutVersion = "legacy-1"
  $script:ChunksLayoutDetail = ""
  $script:ChunksRootRel = "fpf_chunks"
  $script:ChunksIndexRel = "000-index.md"
  $script:ChunksMetadataRel = "metadata.jsonl"
  $script:ChunksByPatternRel = "by_pattern"
  $script:ChunksBySectionRel = "by_section"
  $script:ChunksNonPatternsRel = "non_patterns"
  Set-ChunkPaths

  if (-not (Test-Path -LiteralPath $ChunksLayoutManifestPath -PathType Leaf)) {
    return $true
  }

  $script:ChunksLayoutSource = "manifest"

  try {
    $stream = [System.IO.File]::OpenRead($ChunksLayoutManifestPath)
    $stream.Dispose()
  } catch {
    $script:ChunksLayoutStatus = "invalid"
    $script:ChunksLayoutDetail = "Chunk layout manifest exists but is not readable: $ChunksLayoutManifestPath."
    return $false
  }

  if (-not (Test-LayoutManifestHasRequiredKeys)) {
    $script:ChunksLayoutStatus = "invalid"
    $script:ChunksLayoutDetail = "Chunk layout manifest is missing one or more required keys."
    return $false
  }

  $script:ChunksLayoutVersion = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_LAYOUT_VERSION"
  $script:ChunksRootRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_ROOT"
  $script:ChunksIndexRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_INDEX"
  $script:ChunksMetadataRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_METADATA"
  $script:ChunksByPatternRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_BY_PATTERN"
  $script:ChunksBySectionRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_BY_SECTION"
  $script:ChunksNonPatternsRel = Read-FpfLooseKeyValue $ChunksLayoutManifestPath "FPF_CHUNKS_NON_PATTERNS"

  $paths = @(
    $script:ChunksRootRel,
    $script:ChunksIndexRel,
    $script:ChunksMetadataRel,
    $script:ChunksByPatternRel,
    $script:ChunksBySectionRel,
    $script:ChunksNonPatternsRel
  )

  foreach ($path in $paths) {
    if (-not (Test-FpfSafeRelativePath $path)) {
      $script:ChunksLayoutStatus = "invalid"
      $script:ChunksLayoutDetail = "Chunk layout manifest contains an unsafe or empty relative path."
      $script:ChunksRootRel = "fpf_chunks"
      $script:ChunksIndexRel = "000-index.md"
      $script:ChunksMetadataRel = "metadata.jsonl"
      $script:ChunksByPatternRel = "by_pattern"
      $script:ChunksBySectionRel = "by_section"
      $script:ChunksNonPatternsRel = "non_patterns"
      Set-ChunkPaths
      return $false
    }
  }

  $script:ChunksLayoutStatus = "ready"
  Set-ChunkPaths
  return $true
}

function Add-MissingChunkEntrypoint {
  param([string]$Entrypoint)
  if ([string]::IsNullOrEmpty($script:ChunksDetail)) {
    $script:ChunksDetail = $Entrypoint
  } else {
    $script:ChunksDetail = "$($script:ChunksDetail), $Entrypoint"
  }
}

function Get-ChunksSourceCommit {
  if (Test-Path -LiteralPath $script:ChunksIndexPath -PathType Leaf) {
    try {
      foreach ($line in [System.IO.File]::ReadLines($script:ChunksIndexPath)) {
        if ($line -match '^Commit SHA:\s*`([0-9a-fA-F]+)`') {
          return $Matches[1]
        }
      }
    } catch {
    }
  }

  if (Test-Path -LiteralPath $script:ChunksMetadataPath -PathType Leaf) {
    try {
      foreach ($line in [System.IO.File]::ReadLines($script:ChunksMetadataPath)) {
        if ($line -match '"commit_sha"\s*:\s*"([0-9a-fA-F]+)"') {
          return $Matches[1]
        }
      }
    } catch {
    }
  }

  return "unknown"
}

function Test-Chunks {
  param([Parameter(Mandatory = $true)][string]$SpecCommit)

  $script:ChunksStatus = "missing"
  $script:ChunksMode = "blocked"
  $script:ChunksWarning = ""
  $script:ChunksDetail = ""
  $script:ChunksSourceCommit = "unknown"

  if (-not (Load-ChunkLayout)) {
    $script:ChunksStatus = "degraded"
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-fallback"
      $script:ChunksWarning = "FPF chunks layout manifest is invalid; use FPF-Spec.md fallback for pattern lookup."
      $script:ChunksDetail = $script:ChunksLayoutDetail
    } else {
      $script:ChunksMode = "blocked"
      $script:ChunksWarning = "FPF chunks layout manifest is invalid and FPF-Spec.md is unavailable."
      $script:ChunksDetail = $script:ChunksLayoutDetail
    }
    return
  }

  if (-not (Test-Path -LiteralPath $script:ChunksPath -PathType Container)) {
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-fallback"
      $script:ChunksWarning = "FPF chunks are unavailable; use FPF-Spec.md fallback for pattern lookup."
      $script:ChunksDetail = "Missing chunk entrypoint: $($script:ChunksRootRel) directory."
    } else {
      $script:ChunksDetail = "Missing chunk entrypoint: $($script:ChunksRootRel) directory; FPF-Spec.md is also unavailable."
    }
    return
  }

  if (-not (Test-Path -LiteralPath $script:ChunksIndexPath -PathType Leaf)) {
    Add-MissingChunkEntrypoint $script:ChunksIndexRel
  }
  if (-not (Test-Path -LiteralPath $script:ChunksByPatternDir -PathType Container)) {
    Add-MissingChunkEntrypoint "$($script:ChunksByPatternRel) directory"
  }
  if (-not (Test-Path -LiteralPath $script:ChunksBySectionDir -PathType Container)) {
    Add-MissingChunkEntrypoint "$($script:ChunksBySectionRel) directory"
  }
  if (-not (Test-Path -LiteralPath $script:ChunksNonPatternsDir -PathType Container)) {
    Add-MissingChunkEntrypoint "$($script:ChunksNonPatternsRel) directory"
  }

  if (-not [string]::IsNullOrEmpty($script:ChunksDetail)) {
    $script:ChunksStatus = "degraded"
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-fallback"
      $script:ChunksWarning = "FPF chunks layout is incomplete; use FPF-Spec.md fallback for affected lookups."
      $script:ChunksDetail = "Missing chunk entrypoints: $($script:ChunksDetail)."
    } else {
      $script:ChunksMode = "blocked"
      $script:ChunksWarning = "FPF chunks layout is incomplete and FPF-Spec.md is unavailable."
      $script:ChunksDetail = "Missing chunk entrypoints: $($script:ChunksDetail)."
    }
    return
  }

  $script:ChunksSourceCommit = Get-ChunksSourceCommit
  if ($script:ChunksSourceCommit -eq "unknown") {
    $script:ChunksStatus = "degraded"
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-fallback"
      $script:ChunksWarning = "FPF chunks source commit is unavailable; use FPF-Spec.md fallback for pattern lookup."
      $script:ChunksDetail = "Could not determine the commit used to generate FPF chunks."
    } else {
      $script:ChunksMode = "blocked"
      $script:ChunksWarning = "FPF chunks source commit is unavailable and FPF-Spec.md is unavailable."
      $script:ChunksDetail = "Could not determine the commit used to generate FPF chunks."
    }
    return
  }

  if ($SpecCommit -eq "unknown" -or $SpecCommit -eq "none") {
    $script:ChunksStatus = "degraded"
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-fallback"
      $script:ChunksWarning = "FPF specification commit is unavailable; cannot verify chunk source commit, so use FPF-Spec.md fallback for pattern lookup."
      $script:ChunksDetail = "FPF chunks source commit is $($script:ChunksSourceCommit), but FPF spec commit is $SpecCommit."
    } else {
      $script:ChunksMode = "blocked"
      $script:ChunksWarning = "FPF specification commit is unavailable and FPF-Spec.md is unavailable."
      $script:ChunksDetail = "FPF chunks source commit is $($script:ChunksSourceCommit), but FPF spec commit is $SpecCommit."
    }
    return
  }

  if ($script:ChunksSourceCommit -ne $SpecCommit) {
    $script:ChunksStatus = "stale"
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:ChunksMode = "full-spec-first"
      $script:ChunksWarning = "FPF chunks were generated from a different specification commit; use FPF-Spec.md first and disclose the stale chunk cache."
      $script:ChunksDetail = "FPF chunks source commit $($script:ChunksSourceCommit) does not match FPF spec commit $SpecCommit."
    } else {
      $script:ChunksMode = "blocked"
      $script:ChunksWarning = "FPF chunks were generated from a different specification commit and FPF-Spec.md is unavailable."
      $script:ChunksDetail = "FPF chunks source commit $($script:ChunksSourceCommit) does not match FPF spec commit $SpecCommit."
    }
    return
  }

  $script:ChunksStatus = "ready"
  $script:ChunksMode = "chunk-first"

  if (-not (Test-Path -LiteralPath $script:ChunksMetadataPath -PathType Leaf)) {
    $script:ChunksStatus = "degraded"
    $script:ChunksWarning = "FPF chunks metadata.jsonl is unavailable; use the index and direct chunk paths."
    $script:ChunksDetail = "Optional chunk manifest metadata.jsonl was not found."
  }
}

function Write-Result {
  param([string]$Commit)

  Test-Chunks $Commit
  Write-Output "FPF_SPEC_PATH=$SpecPath"
  Write-Output "FPF_SPEC_COMMIT=$Commit"
  Write-Output "FPF_SPEC_STATUS=$($script:Status)"
  if ($script:Warning -ne "") { Write-Output "FPF_SPEC_WARNING=$($script:Warning)" }
  if ($script:Detail -ne "") { Write-Output "FPF_SPEC_DETAIL=$($script:Detail)" }
  Write-Output "FPF_CHUNKS_LAYOUT_MANIFEST_PATH=$ChunksLayoutManifestPath"
  Write-Output "FPF_CHUNKS_LAYOUT_STATUS=$($script:ChunksLayoutStatus)"
  Write-Output "FPF_CHUNKS_LAYOUT_SOURCE=$($script:ChunksLayoutSource)"
  Write-Output "FPF_CHUNKS_LAYOUT_VERSION=$($script:ChunksLayoutVersion)"
  if ($script:ChunksLayoutDetail -ne "") { Write-Output "FPF_CHUNKS_LAYOUT_DETAIL=$($script:ChunksLayoutDetail)" }
  Write-Output "FPF_CHUNKS_PATH=$($script:ChunksPath)"
  Write-Output "FPF_CHUNKS_INDEX_PATH=$($script:ChunksIndexPath)"
  Write-Output "FPF_CHUNKS_METADATA_PATH=$($script:ChunksMetadataPath)"
  Write-Output "FPF_CHUNKS_BY_PATTERN_DIR=$($script:ChunksByPatternDir)"
  Write-Output "FPF_CHUNKS_BY_SECTION_DIR=$($script:ChunksBySectionDir)"
  Write-Output "FPF_CHUNKS_NON_PATTERNS_DIR=$($script:ChunksNonPatternsDir)"
  Write-Output "FPF_CHUNKS_SOURCE_COMMIT=$($script:ChunksSourceCommit)"
  Write-Output "FPF_CHUNKS_STATUS=$($script:ChunksStatus)"
  Write-Output "FPF_CHUNKS_MODE=$($script:ChunksMode)"
  if ($script:ChunksWarning -ne "") { Write-Output "FPF_CHUNKS_WARNING=$($script:ChunksWarning)" }
  if ($script:ChunksDetail -ne "") { Write-Output "FPF_CHUNKS_DETAIL=$($script:ChunksDetail)" }
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
  if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
    $script:Status = "cached"
    Write-Result (Get-CachedCommit)
    exit 0
  }
  $script:Detail = "Cache-only mode was requested, but no cached FPF specification exists."
  Write-Result "none"
  exit 2
}

if ($RefreshMode -ne "refresh") {
  $script:Detail = "Unsupported FPF refresh mode: $RefreshMode."
  Write-Result "none"
  exit 2
}

if (-not (Test-FpfCommandAvailable "git")) {
  if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
    $script:Status = "cached"
    $script:Warning = "Git is unavailable; using the last cached FPF specification."
    Write-Result (Get-CachedCommit)
    exit 0
  }
  $script:Detail = "Git is unavailable and no cached FPF specification exists."
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
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Could not clone the FPF mirror from GitHub; using the last cached FPF specification."
      $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
      if (-not $commit) { $commit = "unknown" }
      Write-Result $commit
      exit 0
    }
    $script:Detail = "Could not clone the FPF mirror from GitHub and no cached FPF specification exists."
    Write-Result "none"
    exit 2
  }
} else {
  if (-not (Test-CacheAllowsHardReset)) {
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Refusing to run git reset --hard because the FPF cache repository has no valid cache marker and its origin URL does not match the configured FPF repository; using the cached FPF specification."
      Write-Result (Get-CachedCommit)
      exit 0
    }
    $script:Detail = "Refusing to run git reset --hard because the FPF cache repository has no valid cache marker and its origin URL does not match the configured FPF repository, and no cached FPF specification exists."
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
    if (Test-Path -LiteralPath $SpecPath -PathType Leaf) {
      $script:Status = "cached"
      $script:Warning = "Could not update the FPF mirror from GitHub; using the last cached FPF specification."
      $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
      if (-not $commit) { $commit = "unknown" }
      Write-Result $commit
      exit 0
    }
    $script:Detail = "Could not update the FPF mirror from GitHub and no cached FPF specification exists."
    Write-Result "none"
    exit 2
  }
}

if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
  $script:Status = "missing"
  $script:Detail = "The repository was fetched, but FPF-Spec.md was not found at the repository root."
  $commit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
  if (-not $commit) { $commit = "unknown" }
  Write-Result $commit
  exit 2
}

$finalCommit = Get-FpfGitOutput @("-C", $CacheDir, "rev-parse", "HEAD")
if (-not $finalCommit) { $finalCommit = "unknown" }
Write-Result $finalCommit
exit 0
