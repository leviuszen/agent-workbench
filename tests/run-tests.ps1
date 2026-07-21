$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$testRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = Get-ChildItem -LiteralPath $testRoot -Filter "test-*.ps1" -File | Sort-Object Name
$engineName = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh.exe" } else { "powershell.exe" }
$enginePath = Join-Path $PSHOME $engineName

if ($tests.Count -eq 0) {
  throw "No tests found in $testRoot"
}

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
  throw "Current PowerShell engine was not found: $enginePath"
}

$passed = 0
foreach ($test in $tests) {
  Write-Host "RUN $($test.Name)"
  & $enginePath -NoProfile -ExecutionPolicy Bypass -File $test.FullName
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    exit $exitCode
  }
  $passed += 1
  Write-Host "PASS $($test.Name)"
}

Write-Host "All $passed tests passed."
