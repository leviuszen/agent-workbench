param(
  [Parameter(Mandatory = $true)][string]$WorkbenchRoot,
  [Parameter(Mandatory = $false)][ValidateSet("open", "fixed", "blocked", "wontfix")][string]$State
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

function ConvertTo-AgentBugRelativePath {
  param(
    [string]$Path,
    [string]$Root
  )

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
  $rootPrefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar

  if ($fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($rootPrefix.Length).Replace("\", "/")
  }

  return (Split-Path -Leaf $fullPath)
}

function Get-AgentBugMetadata {
  param(
    [string]$Path,
    [string]$WorkbenchRoot
  )

  $metadata = [ordered]@{
    bug_id = ""
    state = ""
    severity = ""
    source = ""
    summary = ""
    path = (ConvertTo-AgentBugRelativePath -Path $Path -Root $WorkbenchRoot)
  }

  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $inSummary = $false
  $inMetadata = $true
  $summaryLines = [System.Collections.Generic.List[string]]::new()

  foreach ($line in $lines) {
    if ($line -like "## *") {
      $inMetadata = $false
    }

    if ($inMetadata -and $line -match "^- ([a-z_]+):\s*(.*)$") {
      $key = $matches[1]
      $value = $matches[2]
      if ($metadata.Contains($key) -and $key -ne "path") {
        $metadata[$key] = $value
      }
      continue
    }

    if ($line -eq "## Summary") {
      $inSummary = $true
      continue
    }

    if ($inSummary -and $line -like "## *") {
      $inSummary = $false
      continue
    }

    if ($inSummary -and -not [string]::IsNullOrWhiteSpace($line)) {
      $summaryLines.Add($line.Trim())
    }
  }

  if ($summaryLines.Count -gt 0) {
    $metadata["summary"] = ($summaryLines -join " ")
  }

  return [pscustomobject]$metadata
}

function Format-AgentBugCompactRow {
  param($Bug)

  return "{0} | {1} | {2} | {3} | {4} | {5}" -f `
    (Redact-AgentBugText -Value $Bug.bug_id), `
    (Redact-AgentBugText -Value $Bug.state), `
    (Redact-AgentBugText -Value $Bug.severity), `
    (Redact-AgentBugText -Value $Bug.source), `
    (Redact-AgentBugText -Value $Bug.summary), `
    $Bug.path
}

if ([string]::IsNullOrWhiteSpace($WorkbenchRoot)) {
  throw "WorkbenchRoot is required."
}

$bugsRoot = Join-Path $WorkbenchRoot "bugs"
$states = @("open", "fixed", "blocked", "wontfix")
$bugs = @()

if (Test-Path -LiteralPath $bugsRoot -PathType Container) {
  $bugs = Get-ChildItem -LiteralPath $bugsRoot -Filter "bug-*.md" -File |
    Sort-Object Name |
    ForEach-Object { Get-AgentBugMetadata -Path $_.FullName -WorkbenchRoot $WorkbenchRoot }
}

$matchingBugs = $bugs
if (-not [string]::IsNullOrWhiteSpace($State)) {
  $matchingBugs = @($bugs | Where-Object { $_.state -eq $State })
}

Write-Output "# Agent Bug Ledger"
Write-Output ""
Write-Output "Bug root: bugs"
if (-not [string]::IsNullOrWhiteSpace($State)) {
  Write-Output "State filter: $State"
}
Write-Output ""
Write-Output "## Counts By State"

foreach ($knownState in $states) {
  $count = @($bugs | Where-Object { $_.state -eq $knownState }).Count
  Write-Output "${knownState}: $count"
}

Write-Output ""
Write-Output "## Bugs"

if (@($matchingBugs).Count -eq 0) {
  Write-Output "No bug records found."
  exit 0
}

foreach ($bug in $matchingBugs) {
  Write-Output (Format-AgentBugCompactRow -Bug $bug)
}
