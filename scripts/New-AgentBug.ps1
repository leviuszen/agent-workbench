param(
  [Parameter(Mandatory = $true)][string]$WorkbenchRoot,
  [Parameter(Mandatory = $true)][string]$Slug,
  [Parameter(Mandatory = $true)][ValidateSet("low", "medium", "high", "critical")][string]$Severity,
  [Parameter(Mandatory = $true)][ValidateSet("codex", "claude-code", "reasonix", "manual", "test", "review", "collect-result")][string]$Source,
  [Parameter(Mandatory = $true)][string]$Summary,
  [Parameter(Mandatory = $false)][AllowNull()][string]$Evidence,
  [Parameter(Mandatory = $false)][AllowNull()][string]$Reproduction,
  [Parameter(Mandatory = $false)][AllowNull()][string]$ExpectedBehavior,
  [Parameter(Mandatory = $false)][AllowNull()][string]$ActualBehavior,
  [Parameter(Mandatory = $false)][AllowNull()][string]$SuggestedFix,
  [Parameter(Mandatory = $false)][AllowNull()][string]$TaskFolder,
  [Parameter(Mandatory = $false)][ValidateSet("open", "fixed", "blocked", "wontfix")][string]$State = "open"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-AgentBugText {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  $providerKeyPattern = "\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY|[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY))\b(?:\s*[:=]\s*|\s+)?[^\s`"'<>()\[\]]*"
  $redacted = $Value -replace "[A-Za-z]:[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\s]+[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace ":[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\bapi\.deepseek[^\s`"'<>()\[\]]*", "[REDACTED_SECRET]"
  return $redacted
}

function New-SafeBugSlug {
  param([string]$Value)

  $safe = (Redact-AgentBugText -Value $Value).ToLowerInvariant()
  $safe = $safe -replace "[^a-z0-9_-]+", "-"
  $safe = $safe -replace "-{2,}", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    $safe = "bug"
  }

  if ($safe.Length -gt 80) {
    $safe = $safe.Substring(0, 80).Trim("-")
  }

  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "bug"
  }

  return $safe
}

if ([string]::IsNullOrWhiteSpace($WorkbenchRoot)) {
  throw "WorkbenchRoot is required."
}

$bugsRoot = Join-Path $WorkbenchRoot "bugs"
New-Item -ItemType Directory -Force -Path $bugsRoot | Out-Null

$safeSlug = New-SafeBugSlug -Value $Slug
$bugPath = $null
$bugId = $null

for ($attempt = 0; $attempt -lt 10; $attempt += 1) {
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $bugId = "bug-$timestamp-$suffix-$safeSlug"
  $candidatePath = Join-Path $bugsRoot "$bugId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    $bugPath = $candidatePath
    break
  }
}

if ([string]::IsNullOrWhiteSpace($bugPath)) {
  throw "Could not create a unique bug id."
}

$createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$safeTaskFolder = Redact-AgentBugText -Value $TaskFolder
$safeSummary = Redact-AgentBugText -Value $Summary
$safeEvidence = Redact-AgentBugText -Value $Evidence
$safeReproduction = Redact-AgentBugText -Value $Reproduction
$safeExpectedBehavior = Redact-AgentBugText -Value $ExpectedBehavior
$safeActualBehavior = Redact-AgentBugText -Value $ActualBehavior
$safeSuggestedFix = Redact-AgentBugText -Value $SuggestedFix

$bugMd = @"
# Agent Bug

- bug_id: $bugId
- state: $State
- severity: $Severity
- source: $Source
- task_folder: $safeTaskFolder
- created_at: $createdAt
- updated_at: $createdAt

## Summary

$safeSummary

## Evidence

$safeEvidence

## Reproduction Or Trigger

$safeReproduction

## Expected Behavior

$safeExpectedBehavior

## Actual Behavior

$safeActualBehavior

## Suggested Fix

$safeSuggestedFix

## Resolution Notes
"@

Set-Content -LiteralPath $bugPath -Value $bugMd -Encoding UTF8
Write-Output $bugPath
