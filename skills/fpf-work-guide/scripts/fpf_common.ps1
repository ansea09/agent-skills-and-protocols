$script:FpfUtf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

function Get-FpfEnv {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Default = ""
  )

  $value = [Environment]::GetEnvironmentVariable($Name)
  if ($null -eq $value -or $value -eq "") {
    return $Default
  }
  return $value
}

function Test-FpfEnvSet {
  param([Parameter(Mandatory = $true)][string]$Name)
  return $null -ne [Environment]::GetEnvironmentVariable($Name)
}

function Get-FpfHome {
  if ($HOME) {
    return $HOME
  }
  if ($env:USERPROFILE) {
    return $env:USERPROFILE
  }
  return (Get-Location).Path
}

function Join-FpfPath {
  param(
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string[]]$Child
  )

  $path = $Base
  foreach ($part in $Child) {
    $path = Join-Path -Path $path -ChildPath $part
  }
  return $path
}

function Test-FpfUInt {
  param([object]$Value)
  if ($null -eq $Value) {
    return $false
  }
  return ([string]$Value) -match '^[0-9]+$'
}

function Get-FpfEpochSeconds {
  param([datetime]$Date = (Get-Date))

  $epoch = [DateTime]::SpecifyKind([DateTime]"1970-01-01T00:00:00", [DateTimeKind]::Utc)
  return [int64][Math]::Floor(($Date.ToUniversalTime() - $epoch).TotalSeconds)
}

function Format-FpfEpoch {
  param([object]$Epoch)

  if (-not (Test-FpfUInt $Epoch)) {
    return "none"
  }

  $epochDate = [DateTime]::SpecifyKind([DateTime]"1970-01-01T00:00:00", [DateTimeKind]::Utc)
  $date = $epochDate.AddSeconds([int64]$Epoch).ToLocalTime()
  $offset = $date.ToString("zzz") -replace ":", ""
  return ($date.ToString("yyyy-MM-ddTHH:mm:ss") + $offset)
}

function Get-FpfPathMTimeEpoch {
  param([Parameter(Mandatory = $true)][string]$Path)

  try {
    if (Test-Path -LiteralPath $Path) {
      return (Get-FpfEpochSeconds (Get-Item -LiteralPath $Path).LastWriteTime)
    }
  } catch {
    return ""
  }
  return ""
}

function Read-FpfKeyValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Key
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }

  try {
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
      if ($line.StartsWith("$Key=")) {
        return $line.Substring($Key.Length + 1)
      }
    }
  } catch {
    return $null
  }
  return $null
}

function Read-FpfOutputValue {
  param(
    [string]$Text,
    [Parameter(Mandatory = $true)][string]$Key
  )

  if ($null -eq $Text) {
    return $null
  }

  foreach ($line in ($Text -split "`r?`n")) {
    if ($line.StartsWith("$Key=")) {
      return $line.Substring($Key.Length + 1)
    }
  }
  return $null
}

function Append-FpfListItem {
  param(
    [string]$Current,
    [Parameter(Mandatory = $true)][string]$Item
  )

  if ([string]::IsNullOrEmpty($Current)) {
    return $Item
  }
  return "$Current, $Item"
}

function Get-FpfCommandPath {
  param([Parameter(Mandatory = $true)][string]$Name)

  $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $command) {
    return "missing"
  }
  return $command.Source
}

function Test-FpfCommandAvailable {
  param([Parameter(Mandatory = $true)][string]$Name)
  return (Get-FpfCommandPath $Name) -ne "missing"
}

function Invoke-FpfGitQuiet {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  & git @Arguments > $null 2>&1
  return $LASTEXITCODE -eq 0
}

function Get-FpfGitOutput {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  $output = & git @Arguments 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return (($output -join "`n").Trim())
}

function Normalize-FpfGitUrl {
  param([string]$Value)

  if ($null -eq $Value) {
    return ""
  }
  $normalized = $Value.Trim()
  if ($normalized.EndsWith(".git", [StringComparison]::OrdinalIgnoreCase)) {
    $normalized = $normalized.Substring(0, $normalized.Length - 4)
  }
  return $normalized
}

function Get-FpfGitRemoteUrl {
  param([Parameter(Mandatory = $true)][string]$RepositoryPath)

  if (-not (Test-FpfCommandAvailable "git")) {
    return "none"
  }

  $origin = Get-FpfGitOutput @("-C", $RepositoryPath, "remote", "get-url", "origin")
  if ($origin) {
    return $origin
  }
  return "none"
}

function Test-FpfGitRemoteMatches {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryPath,
    [Parameter(Mandatory = $true)][string]$ExpectedUrl
  )

  $origin = Get-FpfGitOutput @("-C", $RepositoryPath, "remote", "get-url", "origin")
  if (-not $origin) {
    return $false
  }
  return (Normalize-FpfGitUrl $origin) -eq (Normalize-FpfGitUrl $ExpectedUrl)
}

function Test-FpfCacheMarkerMatches {
  param(
    [Parameter(Mandatory = $true)][string]$MarkerPath,
    [Parameter(Mandatory = $true)][string]$ExpectedKind,
    [Parameter(Mandatory = $true)][string]$ExpectedRepoUrl,
    [Parameter(Mandatory = $true)][string]$ExpectedBranch
  )

  if (-not (Test-Path -LiteralPath $MarkerPath -PathType Leaf)) {
    return $false
  }

  $kind = Read-FpfKeyValue $MarkerPath "kind"
  $repo = Read-FpfKeyValue $MarkerPath "repo"
  $branch = Read-FpfKeyValue $MarkerPath "branch"

  return ($kind -eq $ExpectedKind) -and
    ((Normalize-FpfGitUrl $repo) -eq (Normalize-FpfGitUrl $ExpectedRepoUrl)) -and
    ($branch -eq $ExpectedBranch)
}

function Get-FpfCacheTrustStatus {
  param(
    [Parameter(Mandatory = $true)][string]$CacheDir,
    [Parameter(Mandatory = $true)][string]$MarkerPath,
    [Parameter(Mandatory = $true)][string]$ExpectedKind,
    [Parameter(Mandatory = $true)][string]$ExpectedRepoUrl,
    [Parameter(Mandatory = $true)][string]$ExpectedBranch
  )

  if ((Get-FpfEnv "FPF_ALLOW_NONSTANDARD_CACHE_RESET" "0") -eq "1") {
    return "explicit-allow"
  }
  if (-not (Test-Path -LiteralPath (Join-FpfPath $CacheDir @(".git")) -PathType Container)) {
    return "no-git-cache"
  }
  if (Test-FpfCacheMarkerMatches $MarkerPath $ExpectedKind $ExpectedRepoUrl $ExpectedBranch) {
    return "marker-matches"
  }
  if (-not (Test-FpfCommandAvailable "git")) {
    return "unverified"
  }
  if ((Test-Path -LiteralPath $MarkerPath -PathType Leaf) -and (Test-FpfGitRemoteMatches $CacheDir $ExpectedRepoUrl)) {
    return "remote-matches-marker-mismatch"
  }
  if (Test-FpfGitRemoteMatches $CacheDir $ExpectedRepoUrl) {
    return "remote-matches"
  }
  if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
    return "marker-mismatch"
  }
  return "unverified"
}

function Test-FpfIsWindows {
  $isWindowsVar = Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue
  if ($null -ne $isWindowsVar) {
    return [bool]$isWindowsVar.Value
  }
  return $env:OS -eq "Windows_NT"
}

function Resolve-FpfPathIdentity {
  param([Parameter(Mandatory = $true)][string]$Path)

  try {
    if (Test-Path -LiteralPath $Path) {
      return (Resolve-Path -LiteralPath $Path).ProviderPath
    }
    return [System.IO.Path]::GetFullPath($Path)
  } catch {
    return $Path
  }
}

function Test-FpfPathEqual {
  param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right
  )

  $leftIdentity = Resolve-FpfPathIdentity $Left
  $rightIdentity = Resolve-FpfPathIdentity $Right
  if (Test-FpfIsWindows) {
    return [string]::Equals($leftIdentity, $rightIdentity, [StringComparison]::OrdinalIgnoreCase)
  }
  return [string]::Equals($leftIdentity, $rightIdentity, [StringComparison]::Ordinal)
}

function Write-FpfAtomicLines {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Lines
  )

  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force > $null
  }

  $tmp = "$Path.$PID"
  [System.IO.File]::WriteAllLines($tmp, $Lines, $script:FpfUtf8NoBom)
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Test-FpfWritableDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [ref]$Detail
  )

  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $Detail.Value = "Path exists but is not a directory: $Path."
    return $false
  }

  try {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
      New-Item -ItemType Directory -Path $Path -Force > $null
    }

    $testFile = Join-Path -Path $Path -ChildPath ".fpf-write-test-$PID.tmp"
    [System.IO.File]::WriteAllText($testFile, "ok", $script:FpfUtf8NoBom)
    Remove-Item -LiteralPath $testFile -Force
    $Detail.Value = ""
    return $true
  } catch {
    $Detail.Value = "Could not create or write directory: $Path."
    return $false
  }
}

function Read-FpfLooseKeyValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Key
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }

  try {
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
      $trimmed = $line.Trim()
      if ($trimmed -eq "" -or $trimmed.StartsWith("#")) {
        continue
      }
      $index = $line.IndexOf("=")
      if ($index -lt 0) {
        continue
      }
      $lhs = $line.Substring(0, $index).Trim()
      if ($lhs -eq $Key) {
        return ($line.Substring($index + 1).Trim() -replace "`r$", "")
      }
    }
  } catch {
    return $null
  }
  return $null
}

function Test-FpfSafeRelativePath {
  param([string]$Path)

  if ([string]::IsNullOrEmpty($Path)) {
    return $false
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $false
  }
  if ($Path -match '^[A-Za-z]:') {
    return $false
  }
  foreach ($part in ($Path -split '[\\/]+')) {
    if ($part -eq "..") {
      return $false
    }
  }
  return $true
}
