$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Git {
  param([string]$WorkingDirectory, [string[]]$Arguments)
  $output = & git -C $WorkingDirectory @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed: $output"
  }
  return $output
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-public-example-" + [guid]::NewGuid().ToString("N"))
$workbenchRoot = Join-Path $tempRoot "runtime"
$sourceRepo = Join-Path $tempRoot "sample-repository"
$worktreePath = $null

try {
  New-Item -ItemType Directory -Force -Path $workbenchRoot, $sourceRepo | Out-Null

  $discussionParams = @{
    WorkbenchRoot = $workbenchRoot
    Slug = "cache-policy-review"
    Topic = "Review a cache invalidation proposal"
    Question = "Which assumptions could make this proposal fail?"
    Context = "Use only the frozen reference snapshot. Do not edit source files."
    Mode = "strategy-review"
    Protocol = "adversarial-discussion"
    AuditProfile = "scientific"
    Agents = @("claude-code", "reasonix")
    ReferencePaths = @((Join-Path $repoRoot "examples\sample-design-note.md"))
    ReviewerLenses = @{
      "claude-code" = "implementation feasibility and hidden coupling"
      "reasonix" = "evidence quality and falsification"
    }
  }

  $discussionFolder = & (Join-Path $repoRoot "scripts\New-AgentDiscussion.ps1") @discussionParams
  $discussionFolder = ($discussionFolder | Select-Object -Last 1).Trim()
  & (Join-Path $repoRoot "scripts\Test-AgentReferenceManifest.ps1") -DiscussionFolder $discussionFolder | Out-Null
  $discussionStatus = Get-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($discussionStatus.state -eq "created") "Synthetic review did not preserve the created state before reviewer invocation."
  Assert ($discussionStatus.current_round -eq 1) "Synthetic review did not initialize Round 1."
  Assert (-not [string]::IsNullOrWhiteSpace([string]$discussionStatus.evidence_bundle_id)) "Synthetic review did not create an evidence bundle ID."
  Assert ((Test-Path -LiteralPath (Join-Path $discussionFolder "references\manifest.md") -PathType Leaf)) "Synthetic review did not create a reference manifest."

  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("init") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.name", "Example User") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.email", "example@example.invalid") | Out-Null
  Set-Content -LiteralPath (Join-Path $sourceRepo "config.txt") -Value "enabled=true" -Encoding ASCII
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("add", "config.txt") | Out-Null
  Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("commit", "-m", "initial") | Out-Null

  $taskFolder = & (Join-Path $repoRoot "scripts\New-AgentTask.ps1") `
    -WorkbenchRoot $workbenchRoot `
    -Slug "validate-config" `
    -TargetAgent claude-code `
    -Mode implementation `
    -WorkspaceRoot $sourceRepo `
    -Task "Add a focused configuration validation check and its tests." `
    -Context "Change only the configuration module and its focused tests."
  $taskFolder = ($taskFolder | Select-Object -Last 1).Trim()

  $worktreePath = & (Join-Path $repoRoot "scripts\New-AgentWorktree.ps1") `
    -WorkbenchRoot $workbenchRoot `
    -TaskFolder $taskFolder `
    -WorkspaceRoot $sourceRepo `
    -Slug "validate-config"
  $worktreePath = ($worktreePath | Select-Object -Last 1).Trim()

  $taskStatus = Get-Content -LiteralPath (Join-Path $taskFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($taskStatus.state -eq "isolated_workspace_ready") "Synthetic worker task did not reach isolated_workspace_ready."
  Assert ($taskStatus.isolated_workspace.path -eq $worktreePath) "Synthetic worker status does not point to the created worktree."
  Assert (Test-Path -LiteralPath $worktreePath -PathType Container) "Synthetic worker worktree was not created."

  Write-Output "PASS public example workflows"
} finally {
  if ($worktreePath -and (Test-Path -LiteralPath $worktreePath -PathType Container) -and (Test-Path -LiteralPath $sourceRepo -PathType Container)) {
    & git -C $sourceRepo worktree remove $worktreePath --force 2>$null
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
