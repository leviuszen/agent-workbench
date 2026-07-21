param(
  [Parameter(Mandatory = $true)][string]$WorkbenchRoot,
  [Parameter(Mandatory = $true)][string]$Slug,
[Parameter(Mandatory = $true)][ValidateSet("claude-code", "reasonix", "manual")][string]$TargetAgent,
  [Parameter(Mandatory = $true)][ValidateSet("implementation", "review", "compare", "research")][string]$Mode,
  [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
  [Parameter(Mandatory = $true)][string]$Task,
  [Parameter(Mandatory = $true)][string]$Context
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function New-SafeSlug {
  param([string]$Value)

  $safe = $Value.ToLowerInvariant() -replace "[^a-z0-9_-]+", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "task"
  }

  return $safe
}

function Redact-AgentPacketText {
  param([string]$Value)

  $providerKeyPattern = [regex]::Escape(("ANTHROPIC" + "_API_KEY"))
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\b$providerKeyPattern\b(?:\s*[:=]\s*|\s+)?\S*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "api\.deepseek\S*", "[REDACTED_SECRET]"
  return $redacted
}

function Redact-AgentSlug {
  param([string]$Value)

  $providerKeyPattern = [regex]::Escape(("ANTHROPIC" + "_API_KEY"))
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "redacted-secret"
  $redacted = $redacted -replace "(?i)\b$providerKeyPattern\b(?:\s*[:=]\s*|\s+)?\S*", "redacted-secret"
  $redacted = $redacted -replace "api\.deepseek\S*", "redacted-secret"
  return $redacted
}

$safeSlug = New-SafeSlug -Value (Redact-AgentSlug -Value $Slug)
$tasksRoot = Join-Path $WorkbenchRoot "tasks"
New-Item -ItemType Directory -Force -Path $tasksRoot | Out-Null

for ($attempt = 0; $attempt -lt 10; $attempt += 1) {
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $taskId = "$timestamp-$suffix-$safeSlug"
  $taskFolder = Join-Path $tasksRoot $taskId
  if (-not (Test-Path -LiteralPath $taskFolder)) {
    New-Item -ItemType Directory -Path $taskFolder | Out-Null
    break
  }
}

if (-not (Test-Path -LiteralPath $taskFolder -PathType Container)) {
  throw "Could not create a unique task folder."
}

$createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$safeTask = Redact-AgentPacketText -Value $Task
$safeContext = Redact-AgentPacketText -Value $Context
$expectedOutputs = [System.Collections.Generic.List[string]]::new()
if ($Mode -eq "review") {
  $expectedOutputs.Add("review.md")
} elseif ($Mode -eq "compare") {
  $expectedOutputs.Add("codex-final.md")
} else {
  $expectedOutputs.Add("agent-result.md")
  $expectedOutputs.Add("result.md")
  $expectedOutputs.Add("patch.diff")
}

$taskMd = @"
# Agent Task

- task_id: $taskId
- target_agent: $TargetAgent
- mode: $Mode
- created_at: $createdAt
- workspace_root: $WorkspaceRoot

## Assignment

$safeTask

## Required Output

Write outputs into this task folder. Use only the files requested in status.json.
"@

$contextMd = @"
# Task Context

## Workspace

$WorkspaceRoot

## Context And Constraints

$safeContext

## Safety Rules

- Do not print API keys or provider configuration.
- Do not modify the main workspace unless the task explicitly allows it.
- Prefer writing proposed code changes to patch.diff.
- If blocked, explain the blocker in result.md or review.md.
"@

$status = [ordered]@{
  task_id = $taskId
  target_agent = $TargetAgent
  mode = $Mode
  state = "created"
  created_at = $createdAt
  updated_at = $createdAt
  workspace_root = $WorkspaceRoot
  task_folder = $taskFolder
  expected_outputs = $expectedOutputs
  notes = @()
}

Set-Content -LiteralPath (Join-Path $taskFolder "task.md") -Value $taskMd -Encoding UTF8
Set-Content -LiteralPath (Join-Path $taskFolder "context.md") -Value $contextMd -Encoding UTF8
ConvertTo-Json -InputObject $status -Depth 5 | Set-Content -LiteralPath (Join-Path $taskFolder "status.json") -Encoding UTF8

$log = "[$createdAt] created task_id=$taskId target_agent=$TargetAgent mode=$Mode"
Set-Content -LiteralPath (Join-Path $taskFolder "run.log") -Value $log -Encoding UTF8

Write-Output $taskFolder
