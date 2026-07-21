param(
[Parameter(Mandatory = $true)][string]$TaskFolder,
[ValidateSet("claude-code", "reasonix")][string]$Agent,
[string]$ClaudeExe = "",
[string]$ClaudeLauncher = "",
[string]$ReasonixCommand = $(if ([string]::IsNullOrWhiteSpace($env:REASONIX_COMMAND)) { "reasonix" } else { $env:REASONIX_COMMAND }),
[string]$ReasonixModel,
[int]$ReasonixMaxSteps = 30,
[switch]$Collect
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($TaskFolder)) {
throw "TaskFolder is required."
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
throw "TaskFolder does not exist: $TaskFolder"
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$statusPath = Join-Path $resolvedTaskFolder "status.json"
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
throw "Missing status.json in task folder."
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Agent)) {
$Agent = [string]$status.target_agent
}

switch ($Agent) {
"claude-code" {
$script = Join-Path $PSScriptRoot "Invoke-ClaudeCodeTask.ps1"
& $script -TaskFolder $resolvedTaskFolder -ClaudeExe $ClaudeExe -ClaudeLauncher $ClaudeLauncher -Collect:$Collect
}
"reasonix" {
$script = Join-Path $PSScriptRoot "Invoke-ReasonixTask.ps1"
$reasonixArgs = @{
TaskFolder = $resolvedTaskFolder
ReasonixCommand = $ReasonixCommand
MaxSteps = $ReasonixMaxSteps
Collect = $Collect
}
if (-not [string]::IsNullOrWhiteSpace($ReasonixModel)) {
$reasonixArgs.Model = $ReasonixModel
}
& $script @reasonixArgs
}
default {
throw "Unsupported worker agent: $Agent"
}
}
