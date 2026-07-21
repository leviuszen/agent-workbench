$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\New-AgentWorktree.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-worktree-test-" + [guid]::NewGuid().ToString("N"))
$sourceRepo = Join-Path $tempRoot "source-repo"
$workbenchRoot = Join-Path $tempRoot "workbench"
$taskFolder = Join-Path $workbenchRoot "tasks\20260611-0000-test-task"
$worktreePath = $null
$cleanWorktreePath = $null
$providerKeyName = ("OPENAI" + "_API_KEY")

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

try {
  New-Item -ItemType Directory -Force -Path $sourceRepo, $taskFolder | Out-Null

  & git -C $sourceRepo init | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "git init failed."
  }

  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.name", "Agent Worktree Test") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.email", "agent-worktree-test@example.invalid") | Out-Null
  Set-Content -LiteralPath (Join-Path $sourceRepo "README.md") -Value "# Test Repo" -Encoding UTF8
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("add", "README.md") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("commit", "-m", "initial commit") | Out-Null
  Set-Content -LiteralPath (Join-Path $sourceRepo "dirty.txt") -Value "uncommitted change" -Encoding UTF8

  $createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  $status = [ordered]@{
    task_id = "20260611-0000-test-task"
    target_agent = "manual"
    mode = "implementation"
    state = "created"
    created_at = $createdAt
    updated_at = $createdAt
    workspace_root = $sourceRepo
    task_folder = $taskFolder
    expected_outputs = @("result.md", "patch.diff")
    notes = @()
  }

  ConvertTo-Json -InputObject $status -Depth 5 | Set-Content -LiteralPath (Join-Path $taskFolder "status.json") -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $taskFolder "context.md") -Value "# Task Context`n`nExisting context." -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $taskFolder "run.log") -Value "[$createdAt] created task." -Encoding UTF8

  $secretSlug = "demo-sk-testSecret1234567890-$providerKeyName=abc-api.deepseek.com-C:\secret\path"
  $worktreePath = & $scriptPath `
    -WorkbenchRoot $workbenchRoot `
    -TaskFolder $taskFolder `
    -WorkspaceRoot $sourceRepo `
    -Slug $secretSlug

  if ($LASTEXITCODE -ne 0) {
    throw "New-AgentWorktree.ps1 failed."
  }

  $worktreePath = ($worktreePath | Select-Object -Last 1).Trim()
  Assert (-not [string]::IsNullOrWhiteSpace($worktreePath)) "Script did not output a worktree path."
  Assert ($worktreePath -notmatch "sk-") "Worktree path leaked sk- secret-like content."
  Assert (-not $worktreePath.Contains($providerKeyName)) "Worktree path leaked provider env var name."
  Assert ($worktreePath -notmatch "api\.deepseek") "Worktree path leaked api.deepseek."
  Assert (Test-Path -LiteralPath $worktreePath -PathType Container) "Isolated worktree does not exist."

  $gitStatus = Invoke-Git -WorkingDirectory $worktreePath -Arguments @("status", "--short", "--branch")
  Assert (($gitStatus -join "`n") -match "##") "git status did not report branch information."

  $updatedStatus = Get-Content -LiteralPath (Join-Path $taskFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($updatedStatus.state -eq "isolated_workspace_ready") "status.json state was not updated."
  Assert (-not [string]::IsNullOrWhiteSpace($updatedStatus.isolated_workspace.path)) "Missing isolated_workspace.path."
  Assert (-not [string]::IsNullOrWhiteSpace($updatedStatus.isolated_workspace.branch)) "Missing isolated_workspace.branch."
  Assert (-not [string]::IsNullOrWhiteSpace($updatedStatus.isolated_workspace.base_workspace)) "Missing isolated_workspace.base_workspace."
  Assert (-not [string]::IsNullOrWhiteSpace($updatedStatus.isolated_workspace.base_commit)) "Missing isolated_workspace.base_commit."
  Assert (-not [string]::IsNullOrWhiteSpace($updatedStatus.isolated_workspace.created_at)) "Missing isolated_workspace.created_at."
  Assert ($updatedStatus.isolated_workspace.path -eq $worktreePath) "status.json path does not match output path."

  $context = Get-Content -LiteralPath (Join-Path $taskFolder "context.md") -Raw -Encoding UTF8
  Assert ($context.Contains("## Isolated Worktree")) "context.md missing Isolated Worktree section."
  Assert ($context.Contains($worktreePath)) "context.md missing isolated worktree path."

  $runLog = Get-Content -LiteralPath (Join-Path $taskFolder "run.log") -Raw -Encoding UTF8
  Assert ($runLog -notmatch "sk-") "run.log contains sk- secret-like content."
  Assert (-not $runLog.Contains($providerKeyName)) "run.log contains provider env var name."
  Assert ($runLog -notmatch "api\.deepseek") "run.log contains api.deepseek."
  Assert ($updatedStatus.isolated_workspace.source_dirty -eq $true) "status.json did not record dirty source workspace."
  Assert ($context.Contains("source workspace had uncommitted changes")) "context.md missing dirty workspace warning."
  Assert ($runLog.Contains("source_dirty=True")) "run.log missing dirty workspace flag."

  $duplicateFailed = $false
  try {
    & $scriptPath `
      -WorkbenchRoot $workbenchRoot `
      -TaskFolder $taskFolder `
      -WorkspaceRoot $sourceRepo `
      -Slug "duplicate-run" | Out-Null
  } catch {
    $duplicateFailed = ($_.Exception.Message -match "already has isolated_workspace")
  }
  Assert $duplicateFailed "Second worktree creation for the same task did not fail clearly."

  $invalidBranchTaskFolder = Join-Path $workbenchRoot "tasks\20260611-0001-invalid-branch"
  New-Item -ItemType Directory -Force -Path $invalidBranchTaskFolder | Out-Null
  ConvertTo-Json -InputObject $status -Depth 5 | Set-Content -LiteralPath (Join-Path $invalidBranchTaskFolder "status.json") -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $invalidBranchTaskFolder "context.md") -Value "# Task Context`n`nInvalid branch test." -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $invalidBranchTaskFolder "run.log") -Value "[$createdAt] created task." -Encoding UTF8

  $invalidBranchFailed = $false
  try {
    & $scriptPath `
      -WorkbenchRoot $workbenchRoot `
      -TaskFolder $invalidBranchTaskFolder `
      -WorkspaceRoot $sourceRepo `
      -Slug "invalid-branch" `
      -BranchName "bad branch name" | Out-Null
  } catch {
    $invalidBranchFailed = ($_.Exception.Message -match "Invalid BranchName")
  }
  Assert $invalidBranchFailed "Invalid BranchName did not fail clearly."

  Remove-Item -LiteralPath (Join-Path $sourceRepo "dirty.txt") -Force
  $cleanTaskFolder = Join-Path $workbenchRoot "tasks\20260611-0002-clean-source"
  New-Item -ItemType Directory -Force -Path $cleanTaskFolder | Out-Null
  ConvertTo-Json -InputObject $status -Depth 5 | Set-Content -LiteralPath (Join-Path $cleanTaskFolder "status.json") -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $cleanTaskFolder "context.md") -Value "# Task Context`n`nClean source test." -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $cleanTaskFolder "run.log") -Value "[$createdAt] created task." -Encoding UTF8

  $cleanWorktreePath = & $scriptPath `
    -WorkbenchRoot $workbenchRoot `
    -TaskFolder $cleanTaskFolder `
    -WorkspaceRoot $sourceRepo `
    -Slug "clean-source"
  if ($LASTEXITCODE -ne 0) {
    throw "New-AgentWorktree.ps1 failed for clean source."
  }

  $cleanWorktreePath = ($cleanWorktreePath | Select-Object -Last 1).Trim()
  $cleanStatus = Get-Content -LiteralPath (Join-Path $cleanTaskFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $cleanContext = Get-Content -LiteralPath (Join-Path $cleanTaskFolder "context.md") -Raw -Encoding UTF8
  $cleanRunLog = Get-Content -LiteralPath (Join-Path $cleanTaskFolder "run.log") -Raw -Encoding UTF8
  Assert ($cleanStatus.isolated_workspace.source_dirty -eq $false) "Clean source repo was marked dirty."
  Assert (-not $cleanContext.Contains("source workspace had uncommitted changes")) "Clean source context contains dirty warning."
  Assert ($cleanRunLog.Contains("source_dirty=False")) "Clean source run.log missing source_dirty=False."
} finally {
  if ($worktreePath -and (Test-Path -LiteralPath $worktreePath -PathType Container) -and (Test-Path -LiteralPath $sourceRepo -PathType Container)) {
    & git -C $sourceRepo worktree remove $worktreePath --force 2>$null
  }

  if ($cleanWorktreePath -and (Test-Path -LiteralPath $cleanWorktreePath -PathType Container) -and (Test-Path -LiteralPath $sourceRepo -PathType Container)) {
    & git -C $sourceRepo worktree remove $cleanWorktreePath --force 2>$null
  }

  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
