$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Git {
  param(
    [string]$WorkingDirectory,
    [string[]]$Arguments
  )

  $output = & git -C $WorkingDirectory @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed: $output"
  }

  return $output
}

function Assert-NoSecretLikeContent {
  param(
    [string]$Content,
    [string]$Name
  )

  Assert ($Content -notmatch "sk-") "$Name contains sk- secret-like content."
  Assert (-not $Content.Contains("ANTHROPIC_API_KEY")) "$Name contains provider env var name."
  Assert ($Content -notmatch "api\.deepseek") "$Name contains api.deepseek secret-like content."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$newTaskScript = Join-Path $repoRoot "scripts\New-AgentTask.ps1"
$newWorktreeScript = Join-Path $repoRoot "scripts\New-AgentWorktree.ps1"
$collectScript = Join-Path $repoRoot "scripts\Collect-AgentResult.ps1"
$invokeScript = Join-Path $repoRoot "scripts\Invoke-ClaudeCodeTask.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-claude-code-runner-" + [guid]::NewGuid().ToString("N"))
$sourceRepo = Join-Path $tempRoot "source-repo"
$workbenchRoot = Join-Path $tempRoot "workbench"
$fakeClaude = Join-Path $tempRoot "fake-claude.ps1"
$fakeLauncher = Join-Path $tempRoot "fake-claude-launcher.bat"
$worktreePath = $null

try {
  New-Item -ItemType Directory -Force -Path $sourceRepo, $workbenchRoot | Out-Null
  Assert (Test-Path -LiteralPath $invokeScript -PathType Leaf) "Invoke-ClaudeCodeTask.ps1 does not exist."

  & git -C $sourceRepo init | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "git init failed."
  }

  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.name", "Claude Code Task Test") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.email", "claude-code-task-test@example.invalid") | Out-Null
  Set-Content -LiteralPath (Join-Path $sourceRepo "README.md") -Value "# Source Repo" -Encoding UTF8
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("add", "README.md") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("commit", "-m", "initial commit") | Out-Null

Set-Content -LiteralPath $fakeClaude -Encoding UTF8 -Value @'
Set-Content -LiteralPath "claude-worker-output.txt" -Value "fake claude changed isolated worktree" -Encoding UTF8
Write-Output "# Agent Result"
Write-Output ""
Write-Output "## Files Changed"
Write-Output ""
Write-Output "- claude-worker-output.txt"
Write-Output ""
Write-Output "## Implementation Summary"
Write-Output ""
Write-Output "Wrote a test file inside the isolated worktree."
Write-Output ""
Write-Output "## Tests Run"
Write-Output ""
Write-Output "- fake claude smoke test"
Write-Output ""
Write-Output "## Tests Not Run"
Write-Output ""
Write-Output "- full suite"
Write-Output ""
Write-Output "## Risks And Open Questions"
Write-Output ""
Write-Output "Do not leak sk-resultSecret1234567890 or ANTHROPIC_API_KEY=abc123."
Write-Output ""
Write-Output "## Isolation Check"
Write-Output ""
Write-Output "Stayed inside the isolated worktree."
'@

  Set-Content -LiteralPath $fakeLauncher -Encoding ASCII -Value @"
@echo off
set ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
set ANTHROPIC_API_KEY=sk-launcherSecret1234567890
set ANTHROPIC_MODEL=fake-model
"@

  $taskFolder = & $newTaskScript `
    -WorkbenchRoot $workbenchRoot `
    -Slug "claude-code-runner" `
    -TargetAgent claude-code `
    -Mode implementation `
    -WorkspaceRoot $sourceRepo `
    -Task "Create a small isolated worktree change." `
    -Context "Use fake Claude and do not leak sk-contextSecret1234567890."

  $taskFolder = ($taskFolder | Select-Object -Last 1).Trim()
  Assert (Test-Path -LiteralPath $taskFolder -PathType Container) "Task folder was not created."

  $missingWorktreeFailed = $false
  try {
    & $invokeScript `
      -TaskFolder $taskFolder `
      -ClaudeExe $fakeClaude `
      -ClaudeLauncher $fakeLauncher | Out-Null
  } catch {
    $missingWorktreeFailed = ($_.Exception.Message -match "isolated_workspace")
  }
  Assert $missingWorktreeFailed "Runner should fail clearly before an isolated worktree exists."

  $worktreePath = & $newWorktreeScript `
    -WorkbenchRoot $workbenchRoot `
    -TaskFolder $taskFolder `
    -WorkspaceRoot $sourceRepo `
    -Slug "claude-code-runner"

  $worktreePath = ($worktreePath | Select-Object -Last 1).Trim()
  Assert (Test-Path -LiteralPath $worktreePath -PathType Container) "Isolated worktree was not created."

  & $invokeScript `
    -TaskFolder $taskFolder `
    -ClaudeExe $fakeClaude `
    -ClaudeLauncher $fakeLauncher `
    -Collect | Out-Null

  $agentResultPath = Join-Path $taskFolder "agent-result.md"
  $compatResultPath = Join-Path $taskFolder "result.md"
  Assert (Test-Path -LiteralPath $agentResultPath -PathType Leaf) "agent-result.md was not created."
  Assert (Test-Path -LiteralPath $compatResultPath -PathType Leaf) "result.md compatibility copy was not created."

  $agentResult = Get-Content -LiteralPath $agentResultPath -Raw -Encoding UTF8
  Assert ($agentResult.TrimStart().StartsWith("# Agent Result")) "agent-result.md should start with # Agent Result."
  Assert ($agentResult.Contains("## Files Changed")) "agent-result.md missing Files Changed section."
  Assert ($agentResult.Contains("## Isolation Check")) "agent-result.md missing Isolation Check section."
  Assert-NoSecretLikeContent -Content $agentResult -Name "agent-result.md"

  Assert (Test-Path -LiteralPath (Join-Path $worktreePath "claude-worker-output.txt") -PathType Leaf) "Fake Claude did not write inside isolated worktree."
  Assert (-not (Test-Path -LiteralPath (Join-Path $sourceRepo "claude-worker-output.txt"))) "Source workspace was modified directly."

  $worktreeDiff = Invoke-Git -WorkingDirectory $worktreePath -Arguments @("status", "--short")
  Assert (($worktreeDiff -join "`n") -match "claude-worker-output\.txt") "Isolated worktree diff does not include fake Claude output."

  $collectionOutput = (& $collectScript -TaskFolder $taskFolder) -join [Environment]::NewLine
  Assert ($collectionOutput.Contains("agent-result.md: present")) "Collector should report agent-result.md status."
  Assert ($collectionOutput.Contains("## agent-result.md")) "Collector should print agent-result.md content."
  Assert ($collectionOutput.Contains("## Isolated Worktree Diff")) "Collector should include an isolated worktree diff review section."
  Assert ($collectionOutput.Contains("runtime-smoke-output.txt") -or $collectionOutput.Contains("claude-worker-output.txt")) "Collector should include changed worktree file names."
  Assert-NoSecretLikeContent -Content $collectionOutput -Name "collection output"

  $runLog = Get-Content -LiteralPath (Join-Path $taskFolder "run.log") -Raw -Encoding UTF8
  Assert ($runLog.Contains("claude code task invoked")) "run.log should include a code task invocation entry."
  Assert-NoSecretLikeContent -Content $runLog -Name "run.log"
} finally {
  if ($worktreePath -and (Test-Path -LiteralPath $worktreePath -PathType Container) -and (Test-Path -LiteralPath $sourceRepo -PathType Container)) {
    & git -C $sourceRepo worktree remove $worktreePath --force 2>$null
  }

  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
