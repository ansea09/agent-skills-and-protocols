param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CheckScript = Join-Path -Path $ScriptDir -ChildPath "check_fpf_environment.ps1"

& $CheckScript "--portable-install" @Arguments
exit $LASTEXITCODE
