param(
  [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$InstallRoot = $(
    if (-not [string]::IsNullOrWhiteSpace($env:AGENT_WORKBENCH_HOME)) {
      $env:AGENT_WORKBENCH_HOME
    } elseif (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      Join-Path $env:LOCALAPPDATA "AgentWorkbench"
    } else {
      Join-Path $HOME ".agent-workbench"
    }
  )
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptsSource = Join-Path $SourceRoot "scripts"
$skillsSource = Join-Path $SourceRoot "skills"
$readmeSource = Join-Path $SourceRoot "README.md"
$scriptsTarget = Join-Path $InstallRoot "scripts"
$skillsTarget = Join-Path $InstallRoot "skills"
$tasksTarget = Join-Path $InstallRoot "tasks"
$bugsTarget = Join-Path $InstallRoot "bugs"
$worktreesTarget = Join-Path $InstallRoot "worktrees"
$discussionsTarget = Join-Path $InstallRoot "discussions"

if (-not (Test-Path -LiteralPath $scriptsSource -PathType Container)) {
  throw "Scripts source not found: $scriptsSource"
}
if (-not (Test-Path -LiteralPath $skillsSource -PathType Container)) {
  throw "Skills source not found: $skillsSource"
}

foreach ($path in @($scriptsTarget, $skillsTarget, $tasksTarget, $bugsTarget, $worktreesTarget, $discussionsTarget)) {
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Get-ChildItem -LiteralPath $scriptsSource -Filter "*.ps1" -File |
  Copy-Item -Destination $scriptsTarget -Force

Copy-Item -LiteralPath $skillsSource -Destination $InstallRoot -Recurse -Force

if (Test-Path -LiteralPath $readmeSource -PathType Leaf) {
  Copy-Item -LiteralPath $readmeSource -Destination (Join-Path $InstallRoot "README.md") -Force
}

Write-Output "Agent Workbench installed:"
Write-Output $InstallRoot
Write-Output "Scripts:"
Write-Output $scriptsTarget
Write-Output "Skills:"
Write-Output $skillsTarget
Write-Output "Tasks:"
Write-Output $tasksTarget
Write-Output "Bugs:"
Write-Output $bugsTarget
Write-Output "Worktrees:"
Write-Output $worktreesTarget
Write-Output "Discussions:"
Write-Output $discussionsTarget
if (Test-Path -LiteralPath (Join-Path $InstallRoot "README.md") -PathType Leaf) {
  Write-Output "README:"
  Write-Output (Join-Path $InstallRoot "README.md")
}
