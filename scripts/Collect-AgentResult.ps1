param(
  [Parameter(Mandatory = $true)][string]$TaskFolder
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($TaskFolder)) {
  throw "TaskFolder is required."
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
  throw "TaskFolder does not exist: $TaskFolder"
}

function Redact-CollectedContent {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $providerKeyPattern = "\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY|[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY))\b(?:\s*[:=]\s*|\s+)?[^\s`"'<>()\[\]]*"
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\bapi\.deepseek[^\s`"'<>()\[\]]*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "[A-Za-z]:[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\s]+[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  return $redacted
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$fileNames = @(
  "task.md",
  "context.md",
  "status.json",
  "run.log",
  "agent-result.md",
  "agent-metrics.json",
  "result.md",
  "review.md",
  "codex-final.md",
  "patch.diff"
)

Write-Output "# Agent Result Collection"
Write-Output ""
Write-Output "Task folder: $resolvedTaskFolder"
Write-Output ""
Write-Output "## File Status"

foreach ($fileName in $fileNames) {
  $path = Join-Path $resolvedTaskFolder $fileName
  $state = if (Test-Path -LiteralPath $path -PathType Leaf) { "present" } else { "missing" }
  Write-Output "${fileName}: $state"
}

$bugSignalDetected = $false
foreach ($fileName in @("agent-result.md", "result.md", "review.md", "codex-final.md")) {
  $path = Join-Path $resolvedTaskFolder $fileName
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Write-Output ""
    Write-Output "## $fileName"
    $sanitizedContent = Redact-CollectedContent -Value (Get-Content -LiteralPath $path -Raw -Encoding UTF8)
    Write-Output $sanitizedContent
    if ($sanitizedContent -match "(?i)\b(fail|failed|error|exception|blocked|regression)\b") {
      $bugSignalDetected = $true
    }
  }
}

if ($bugSignalDetected) {
  Write-Output ""
  Write-Output "Potential bug signal detected. Register with New-AgentBug.ps1 if this is a concrete defect."
}

$patchPath = Join-Path $resolvedTaskFolder "patch.diff"
if (Test-Path -LiteralPath $patchPath -PathType Leaf) {
  Write-Output ""
  Write-Output "## Patch"
  Write-Output "Warning: review this patch manually before applying it. This script never applies patches."
  Write-Output "Patch path: $patchPath"
}

$statusPath = Join-Path $resolvedTaskFolder "status.json"
if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
  $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (($status.PSObject.Properties.Name -contains "isolated_workspace") -and
      $status.isolated_workspace.path -and
      (Test-Path -LiteralPath $status.isolated_workspace.path -PathType Container)) {
    Write-Output ""
    Write-Output "## Isolated Worktree Diff"
    Write-Output "Review required before accepting changes. This script never merges, applies patches, or modifies the source workspace."
    Write-Output "Worktree path: $(Redact-CollectedContent -Value $status.isolated_workspace.path)"
    try {
      $gitStatus = & git -C $status.isolated_workspace.path status --short 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Output "git status failed: $(Redact-CollectedContent -Value (($gitStatus | Out-String).Trim()))"
      } elseif ($gitStatus.Count -eq 0) {
        Write-Output "No worktree changes detected."
      } else {
        Write-Output "git status --short:"
        foreach ($line in $gitStatus) {
          Write-Output (Redact-CollectedContent -Value $line)
        }
      }
    } catch {
      Write-Output "git status failed: $(Redact-CollectedContent -Value $_.Exception.Message)"
    }
  }
}
