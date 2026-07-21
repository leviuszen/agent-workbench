param(
  [Parameter(Mandatory = $true)][string]$TaskFolder,
  [string]$ClaudeExe = "",
  [string]$ClaudeLauncher = "",
  [switch]$Collect
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot "ClaudeRuntime.ps1")

function Redact-ClaudeWorkerText {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $providerKeyPattern = '\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY|[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY))\b(?:\s*[:=]\s*|\s+)?[^\s`"''<>()\[\]]*'
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace '(?i)\bapi\.deepseek[^\s`"''<>()\[\]]*', "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)(\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*)(?:[A-Za-z]:[\\/]|\\\\)[^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", '$1[REDACTED_PATH]'
  $redacted = $redacted -replace "[A-Za-z]:[\\/][^\r\n]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\r\n]+[\\/][^\r\n]+", "[REDACTED_PATH]"
  return $redacted
}

function Import-LauncherEnvironment {
  param([string]$LauncherPath)

  if ([string]::IsNullOrWhiteSpace($LauncherPath)) {
    return
  }

  if (-not (Test-Path -LiteralPath $LauncherPath -PathType Leaf)) {
    return
  }

  foreach ($line in Get-Content -LiteralPath $LauncherPath -Encoding UTF8) {
    if ($line -match '^\s*set\s+([^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
  }
}

function ConvertFrom-ClaudeMarkdownOutput {
  param(
    [string]$Value,
    [string]$RequiredHeading
  )

  $content = $Value.Trim()
  $fenced = [regex]::Match($content, '(?is)```(?:markdown|md)?\s*(.*?)\s*```')
  if ($fenced.Success) {
    $content = $fenced.Groups[1].Value.Trim()
  }

  $headingIndex = $content.IndexOf($RequiredHeading, [System.StringComparison]::OrdinalIgnoreCase)
  if ($headingIndex -ge 0) {
    $content = $content.Substring($headingIndex).Trim()
  }

  return $content
}

if ([string]::IsNullOrWhiteSpace($TaskFolder)) {
  throw "TaskFolder is required."
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
  throw "TaskFolder does not exist: $(Redact-ClaudeWorkerText -Value $TaskFolder)"
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$resolvedClaudeExe = Resolve-ClaudeCodeExecutable -ExplicitPath $ClaudeExe
$statusPath = Join-Path $resolvedTaskFolder "status.json"
$taskPath = Join-Path $resolvedTaskFolder "task.md"
$contextPath = Join-Path $resolvedTaskFolder "context.md"
$runLogPath = Join-Path $resolvedTaskFolder "run.log"

foreach ($requiredPath in @($statusPath, $taskPath, $contextPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    throw "Required task file missing: $(Split-Path -Leaf $requiredPath)"
  }
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not ($status.PSObject.Properties.Name -contains "isolated_workspace")) {
  throw "isolated_workspace.path is required before invoking Claude Code task runner."
}

$isolatedPath = $status.isolated_workspace.path
if ([string]::IsNullOrWhiteSpace($isolatedPath)) {
  throw "isolated_workspace.path is required before invoking Claude Code task runner."
}

if (-not (Test-Path -LiteralPath $isolatedPath -PathType Container)) {
  throw "isolated_workspace.path does not exist: $(Redact-ClaudeWorkerText -Value $isolatedPath)"
}

$resolvedIsolatedPath = (Resolve-Path -LiteralPath $isolatedPath).Path
Import-LauncherEnvironment -LauncherPath $ClaudeLauncher

$prompt = @"
You are working as a controlled external code worker for Agent Workbench.

Current working directory is the isolated git worktree. Modify files only in this isolated worktree:
$resolvedIsolatedPath

Read the task packet files:
- $taskPath
- $contextPath

Do not edit the source workspace, merge branches, apply patches to another workspace, or print secrets.

After making the requested code changes, return only Markdown for agent-result.md.
The first line of your response must be exactly:
# Agent Result

Include these sections:
## Files Changed
## Implementation Summary
## Tests Run
## Tests Not Run
## Risks And Open Questions
## Isolation Check
"@

Push-Location -LiteralPath $resolvedIsolatedPath
try {
  $rawOutput = & $resolvedClaudeExe --bare --print $prompt --permission-mode acceptEdits --no-session-persistence 2>&1
  if ($LASTEXITCODE -ne 0) {
    $message = Redact-ClaudeWorkerText -Value (($rawOutput | Out-String).Trim())
    throw "Claude code task invocation failed: $message"
  }
} finally {
  Pop-Location
}

$rawText = ($rawOutput | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($rawText)) {
  throw "Claude code task invocation returned empty output."
}

$cleaned = ConvertFrom-ClaudeMarkdownOutput -Value $rawText -RequiredHeading "# Agent Result"
$safeResult = Redact-ClaudeWorkerText -Value $cleaned
$agentResultPath = Join-Path $resolvedTaskFolder "agent-result.md"
$compatResultPath = Join-Path $resolvedTaskFolder "result.md"

Set-Content -LiteralPath $agentResultPath -Value $safeResult -Encoding UTF8
Set-Content -LiteralPath $compatResultPath -Value $safeResult -Encoding UTF8

$completedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$logLine = "[$completedAt] claude code task invoked isolated_workspace=$(Redact-ClaudeWorkerText -Value $resolvedIsolatedPath) result=agent-result.md claude=$(Split-Path -Leaf $resolvedClaudeExe)"
Add-Content -LiteralPath $runLogPath -Value $logLine -Encoding UTF8

if ($Collect) {
  $collectScript = Join-Path $PSScriptRoot "Collect-AgentResult.ps1"
  & $collectScript -TaskFolder $resolvedTaskFolder | Out-Null
}

Write-Output $agentResultPath
