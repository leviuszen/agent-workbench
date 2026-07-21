param(
[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DiscussionFolder,
[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$FindingId,
[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Reviewer,
[Parameter(Mandatory = $true)][ValidateSet("confirmed", "rejected", "duplicate", "not-testable")][string]$Outcome,
[string]$Severity = "",
[string]$Notes = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-AgentAuditNotes {
param([AllowNull()][string]$Value)

if ($null -eq $Value) {
return ""
}

$providerKeyPattern = '\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY)\b'
$redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
$redacted = $redacted -replace ("(?i)" + $providerKeyPattern + '\s*=\s*[^\s`"''<>()\[\]]+'), "[REDACTED_SECRET]"
$redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
$redacted = $redacted -replace '(?i)\b(?:api[_-]?key|token|secret|password)\s*[:=]\s*[^\s`"''<>()\[\]]+', "[REDACTED_SECRET]"
$redacted = $redacted -replace '[A-Za-z]:[\\/][^\s`"''<>()\[\]]+', "[REDACTED_PATH]"
$redacted = $redacted -replace '\\\\[^\\/\s]+[\\/][^\s`"''<>()\[\]]+', "[REDACTED_PATH]"
$redacted = $redacted -replace '(?:/Users|/home|/mnt|/Volumes)/[^\s`"''<>()\[\]]+', "[REDACTED_PATH]"
return $redacted
}

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) {
throw "DiscussionFolder does not exist: $DiscussionFolder"
}

$resolvedDiscussionFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$discussionsRoot = Split-Path -Parent $resolvedDiscussionFolder
if ((Split-Path -Leaf $discussionsRoot) -ne "discussions") {
throw "DiscussionFolder must be directly under a discussions directory."
}

$workbenchRoot = Split-Path -Parent $discussionsRoot
$event = [ordered]@{
timestamp = (Get-Date -Format "o")
discussion_id = Split-Path -Leaf $resolvedDiscussionFolder
finding_id = $FindingId
reviewer = $Reviewer
outcome = $Outcome
severity = $Severity
notes = (Redact-AgentAuditNotes -Value $Notes)
}
$serializedEvent = $event | ConvertTo-Json -Compress -Depth 3
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
foreach ($logPath in @(
(Join-Path $resolvedDiscussionFolder "calibration-events.jsonl"),
(Join-Path $workbenchRoot "audit-calibration.jsonl")
)) {
[System.IO.File]::AppendAllText($logPath, $serializedEvent + [Environment]::NewLine, $utf8NoBom)
}
