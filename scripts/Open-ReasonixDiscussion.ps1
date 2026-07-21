param(
  [Parameter(Mandatory = $true)][string]$DiscussionFolder,
  [ValidateSet(1, 2)][int]$Round = 1,
  [string]$AgentName = "reasonix",
  [string]$ReasonixExe = $env:REASONIX_DESKTOP_EXE,
  [switch]$PrepareOnly
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

function ConvertTo-SafeAgentFileName {
  param([string]$Value)

  $safe = $Value.ToLowerInvariant() -replace "[^a-z0-9_-]+", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "reasonix"
  }

  return $safe
}

if ([string]::IsNullOrWhiteSpace($DiscussionFolder)) {
  throw "DiscussionFolder is required."
}

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) {
  throw "DiscussionFolder does not exist: $(Redact-LaunchMetadata -Value $DiscussionFolder)"
}

$resolvedDiscussionFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$briefPath = Join-Path $resolvedDiscussionFolder "brief.md"
$statusPath = Join-Path $resolvedDiscussionFolder "status.json"
$roundFolder = Join-Path $resolvedDiscussionFolder "round$Round"
$runLogPath = Join-Path $resolvedDiscussionFolder "run.log"

if (-not (Test-Path -LiteralPath $briefPath -PathType Leaf)) {
  throw "brief.md is required."
}

if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw "status.json is required."
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
$isScientificAudit = $status.PSObject.Properties.Name -contains "audit_profile" -and $status.audit_profile -eq "scientific"

if (-not (Test-Path -LiteralPath $roundFolder -PathType Container)) {
  throw "Round folder does not exist: round$Round"
}

if ($Round -eq 2) {
  $synthesisPath = Join-Path $resolvedDiscussionFolder "codex-synthesis.md"
  if (-not (Test-Path -LiteralPath $synthesisPath -PathType Leaf)) {
    throw "codex-synthesis.md is required for round 2 Reasonix review."
  }
}

if (-not $PrepareOnly) {
  if ([string]::IsNullOrWhiteSpace($ReasonixExe)) {
    $command = Get-Command "reasonix-desktop.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source)) {
      $ReasonixExe = $command.Source
    }
  }

  if ([string]::IsNullOrWhiteSpace($ReasonixExe)) {
    throw "Reasonix Desktop was not found. Set REASONIX_DESKTOP_EXE or pass -ReasonixExe explicitly."
  }

  if (-not (Test-Path -LiteralPath $ReasonixExe -PathType Leaf)) {
    throw "ReasonixExe does not exist: $(Redact-LaunchMetadata -Value $ReasonixExe)"
  }

  $resolvedReasonixExe = (Resolve-Path -LiteralPath $ReasonixExe).Path
}

$safeAgentName = ConvertTo-SafeAgentFileName -Value $AgentName
$targetFeedback = "round$Round/$safeAgentName.md"
$instructionPath = Join-Path $roundFolder "$safeAgentName-instructions.md"
$referenceManifestPath = Join-Path $resolvedDiscussionFolder "references\manifest.md"
$referenceInstruction = if (Test-Path -LiteralPath $referenceManifestPath -PathType Leaf) {
  @"
- Read references/manifest.md.
- Read every listed snapshot under references/files/.
- Treat those files as frozen snapshots copied when the discussion was created.
- If Codex needs review of changed source files, Codex must create a fresh discussion with new ReferencePaths; do not infer current source state from this old discussion.
"@
} else {
  "- No reference snapshots were provided for this discussion."
}

$roundInstruction = if ($Round -eq 2 -and $isScientificAudit) {
  @"
- Read codex-synthesis.md.
- Address only disputed, blocking, or weak-evidence findings from codex-synthesis.md.
- Mark each addressed position as maintained, revised, or withdrawn.
"@
} elseif ($Round -eq 2) {
  @"
- Read codex-synthesis.md.
- Respond to Codex's synthesis, disagreements, and questions.
"@
} elseif ($isScientificAudit) {
  @"
- Round 1 is blind and independent.
- Do not read another reviewer's output during scientific Round 1.
"@
} else {
  "- Give independent Round 1 feedback before reading any other agent's feedback unless Codex explicitly included it in the brief."
}

$instruction = @"
# Reasonix Agent Workbench Review Instructions

You are Reasonix participating as an external read-only reviewer in an Agent Workbench discussion.

## Required Files To Read

- brief.md
$roundInstruction
$referenceInstruction

## Required Output

Write one complete Markdown review to:

$targetFeedback

Use the output format requested in brief.md.

## Boundaries

- Do not edit repository files.
- Do not create worktrees.
- Do not merge, patch, rename, delete, or move source files.
- Do not print API keys, provider configuration, secrets, or local absolute paths.
- Codex remains the moderator and final decision writer.
- Claude Code may produce a separate review in the same discussion. Your role is a second independent reviewer, not a replacement for Claude Code.
- Opening Reasonix Desktop prepares a manual review session; it is not completion evidence.

## Discussion Folder

$resolvedDiscussionFolder
"@

Set-Content -LiteralPath $instructionPath -Value $instruction -Encoding UTF8

$openedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$logAction = if ($PrepareOnly) { "prepared" } else { "launch requested" }
$launcherName = if ($PrepareOnly) { "prepare-only" } else { Split-Path -Leaf $resolvedReasonixExe }
$logLine = "[$openedAt] $logAction agent=$safeAgentName round=$Round discussion_folder=$(Redact-LaunchMetadata -Value $resolvedDiscussionFolder) instructions=$(Redact-LaunchMetadata -Value $instructionPath) target=$targetFeedback launcher=$(Redact-LaunchMetadata -Value $launcherName)"
Add-Content -LiteralPath $runLogPath -Value $logLine -Encoding UTF8

if (-not $PrepareOnly) {
  Start-Process -FilePath $resolvedReasonixExe -WorkingDirectory $resolvedDiscussionFolder -WindowStyle Normal
  Start-Process -FilePath "explorer.exe" -ArgumentList "`"$resolvedDiscussionFolder`""
}

Write-Output "Reasonix discussion instructions prepared."
Write-Output "Discussion folder: $(Redact-LaunchMetadata -Value $resolvedDiscussionFolder)"
Write-Output "Instructions: $(Redact-LaunchMetadata -Value $instructionPath)"
Write-Output "Expected feedback: $targetFeedback"
if ($PrepareOnly) {
  Write-Output "PrepareOnly: Reasonix was not launched."
} else {
  Write-Output "Reasonix opened."
}
