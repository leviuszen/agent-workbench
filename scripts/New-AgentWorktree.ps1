param(
  [Parameter(Mandatory = $true)][string]$WorkbenchRoot,
  [Parameter(Mandatory = $true)][string]$TaskFolder,
  [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
  [Parameter(Mandatory = $true)][string]$Slug,
  [string]$WorktreeRoot,
  [string]$BranchName
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-WorktreeMetadata {
  param([string]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $providerSecretPattern = "(?i)\b(?:ANTHROPIC|OPENAI|DEEPSEEK|OPENROUTER|GEMINI|GOOGLE|AZURE_OPENAI|QWEN|DASHSCOPE|MISTRAL|COHERE)_[A-Z0-9_]*(?:API|TOKEN|KEY)[A-Z0-9_]*\b(?:\s*[:=]\s*|\s+)?\S*"
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace $providerSecretPattern, "[REDACTED_SECRET]"
  $redacted = $redacted -replace "api\.deepseek\S*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)(\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*)(?:[A-Za-z]:[\\/]|\\\\)[^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", '$1[REDACTED_PATH]'
  $redacted = $redacted -replace "(?i)(?<![A-Za-z0-9_])[A-Za-z]:[\\/][^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\r\n]+[\\/][^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", "[REDACTED_PATH]"
  return $redacted
}

function New-SafeWorktreeSlug {
  param([string]$Value)

  $redacted = Redact-WorktreeMetadata -Value $Value
  $safe = $redacted.ToLowerInvariant() -replace "\[[^\]]+\]", "redacted"
  $safe = $safe -replace "[^a-z0-9_-]+", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "worktree"
  }

  return $safe
}

function Invoke-GitCommand {
  param(
    [string]$WorkingDirectory,
    [string[]]$Arguments,
    [string]$ErrorMessage
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & git -C $WorkingDirectory @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($exitCode -ne 0) {
    throw "$ErrorMessage $((Redact-WorktreeMetadata -Value ($output -join "`n")))"
  }

  return $output
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
  throw "TaskFolder does not exist: $(Redact-WorktreeMetadata -Value $TaskFolder)"
}

if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
  $WorktreeRoot = Join-Path $WorkbenchRoot "worktrees"
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$statusPath = Join-Path $resolvedTaskFolder "status.json"
$contextPath = Join-Path $resolvedTaskFolder "context.md"
$logPath = Join-Path $resolvedTaskFolder "run.log"

if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw "Missing status.json in task folder."
}

if (-not (Test-Path -LiteralPath $contextPath -PathType Leaf)) {
  throw "Missing context.md in task folder."
}

if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
  New-Item -ItemType File -Path $logPath | Out-Null
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (($status.PSObject.Properties.Name -contains "isolated_workspace") -and
    $null -ne $status.isolated_workspace -and
    -not [string]::IsNullOrWhiteSpace([string]$status.isolated_workspace.path)) {
  throw "Task already has isolated_workspace.path: $(Redact-WorktreeMetadata -Value ([string]$status.isolated_workspace.path))"
}

$baseWorkspace = (Invoke-GitCommand `
  -WorkingDirectory $WorkspaceRoot `
  -Arguments @("rev-parse", "--show-toplevel") `
  -ErrorMessage "WorkspaceRoot is not inside a git repository:").Trim()

$baseCommit = (Invoke-GitCommand `
  -WorkingDirectory $WorkspaceRoot `
  -Arguments @("rev-parse", "HEAD") `
  -ErrorMessage "Could not resolve WorkspaceRoot HEAD:").Trim()

$sourceStatus = Invoke-GitCommand `
  -WorkingDirectory $baseWorkspace `
  -Arguments @("status", "--porcelain") `
  -ErrorMessage "Could not inspect source workspace status:"
$sourceDirty = @($sourceStatus | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0

New-Item -ItemType Directory -Force -Path $WorktreeRoot | Out-Null
$resolvedWorktreeRoot = (Resolve-Path -LiteralPath $WorktreeRoot).Path

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
$safeSlug = New-SafeWorktreeSlug -Value $Slug
$worktreeFolderName = "$timestamp-$suffix-$safeSlug"
$worktreePath = Join-Path $resolvedWorktreeRoot $worktreeFolderName

if ([string]::IsNullOrWhiteSpace($BranchName)) {
  $BranchName = "agent-workbench/$timestamp-$suffix-$safeSlug"
}

Invoke-GitCommand `
  -WorkingDirectory $baseWorkspace `
  -Arguments @("check-ref-format", "--branch", $BranchName) `
  -ErrorMessage "Invalid BranchName:" | Out-Null

Invoke-GitCommand `
  -WorkingDirectory $baseWorkspace `
  -Arguments @("worktree", "add", "-b", $BranchName, $worktreePath, $baseCommit) `
  -ErrorMessage "Could not create isolated worktree:" | Out-Null

$createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$status | Add-Member -NotePropertyName "isolated_workspace" -NotePropertyValue ([ordered]@{
  path = $worktreePath
  branch = $BranchName
  base_workspace = $baseWorkspace
  base_commit = $baseCommit
  source_dirty = $sourceDirty
  created_at = $createdAt
}) -Force
$status.state = "isolated_workspace_ready"
$status.updated_at = $createdAt
$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statusPath -Encoding UTF8

$contextAppend = @"

## Isolated Worktree

- path: $worktreePath
- branch: $BranchName
- base_commit: $baseCommit
- source_dirty: $sourceDirty

External agents must work only inside the isolated workspace above. Do not edit the source workspace, merge back into it, or apply patches there. Leave results in this task folder and code changes in the isolated worktree branch for Codex review.
"@
if ($sourceDirty) {
  $contextAppend += @"

Warning: source workspace had uncommitted changes when this worktree was created. Those changes are not included in the isolated worktree unless they were committed separately.
"@
}
Add-Content -LiteralPath $contextPath -Value $contextAppend -Encoding UTF8

$logLine = "[$createdAt] isolated worktree created path=$worktreePath branch=$BranchName base_workspace=$baseWorkspace base_commit=$baseCommit source_dirty=$sourceDirty slug=$Slug"
Add-Content -LiteralPath $logPath -Value (Redact-WorktreeMetadata -Value $logLine) -Encoding UTF8

Write-Output $worktreePath
