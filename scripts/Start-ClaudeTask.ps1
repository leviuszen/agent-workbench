param(
  [Parameter(Mandatory = $true)][string]$TaskFolder,
  [string]$ClaudeLauncher = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot "ClaudeRuntime.ps1")

function Redact-LaunchMetadata {
  param([string]$Value)

  $providerKeyPattern = [regex]::Escape(("ANTHROPIC" + "_API_KEY"))
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\b$providerKeyPattern\b(?:\s*[:=]\s*|\s+)?\S*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "api\.deepseek\S*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)(\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*)(?:[A-Za-z]:[\\/]|\\\\)[^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", '$1[REDACTED_PATH]'
  $redacted = $redacted -replace "[A-Za-z]:[\\/][^\r\n]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\r\n]+[\\/][^\r\n]+", "[REDACTED_PATH]"
  return $redacted
}

if ([string]::IsNullOrWhiteSpace($TaskFolder)) {
  throw "TaskFolder is required."
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
  throw "TaskFolder does not exist: $(Redact-LaunchMetadata -Value $TaskFolder)"
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$resolvedClaudeLauncher = Resolve-ClaudeCodeExecutable -ExplicitPath $ClaudeLauncher
$launchedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$launcherName = Split-Path -Leaf $resolvedClaudeLauncher
$logPath = Join-Path $resolvedTaskFolder "run.log"
$logLine = "[$launchedAt] launch requested agent=claude-code task_folder=$(Redact-LaunchMetadata -Value $resolvedTaskFolder) launcher=$(Redact-LaunchMetadata -Value $launcherName)"

Add-Content -LiteralPath $logPath -Value $logLine -Encoding UTF8
Start-Process -FilePath $resolvedClaudeLauncher -WorkingDirectory $resolvedTaskFolder -WindowStyle Normal
Start-Process -FilePath "explorer.exe" -ArgumentList "`"$resolvedTaskFolder`""

Write-Output "Claude launched."
Write-Output "Task folder: $(Redact-LaunchMetadata -Value $resolvedTaskFolder)"
Write-Output "If task.md/context.md were not injected automatically, paste them into Claude."
