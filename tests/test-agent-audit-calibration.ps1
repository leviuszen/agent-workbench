$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
if (-not $Condition) {
throw $Message
}
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$recordScriptPath = Join-Path $repoRoot "scripts\Record-AgentAuditOutcome.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-audit-calibration-test-" + [guid]::NewGuid().ToString("N"))
$discussionFolder = Join-Path $tempRoot "discussions\discussion-alpha"
$providerKeyName = ("OPENAI" + "_API_KEY")

New-Item -ItemType Directory -Force -Path $discussionFolder | Out-Null

try {
& $recordScriptPath `
-DiscussionFolder $discussionFolder `
-FindingId "claude-1" `
-Reviewer "claude-code" `
-Outcome confirmed `
-Severity high `
-Notes "Token sk-calibrationSecret1234567890. $providerKeyName=abc123. Path C:\Users\Alice\audit.txt."

$discussionLog = Join-Path $discussionFolder "calibration-events.jsonl"
$workbenchLog = Join-Path $tempRoot "audit-calibration.jsonl"
Assert (Test-Path -LiteralPath $discussionLog -PathType Leaf) "Calibration should append a discussion-local JSONL record."
Assert (Test-Path -LiteralPath $workbenchLog -PathType Leaf) "Calibration should append a workbench JSONL record."

$discussionLines = @(Get-Content -LiteralPath $discussionLog -Encoding UTF8)
$workbenchLines = @(Get-Content -LiteralPath $workbenchLog -Encoding UTF8)
Assert ($discussionLines.Count -eq 1) "First calibration append should create one discussion event."
Assert ($workbenchLines.Count -eq 1) "First calibration append should create one workbench event."
$firstDiscussionEvent = $discussionLines[0] | ConvertFrom-Json
$firstWorkbenchEvent = $workbenchLines[0] | ConvertFrom-Json
Assert ($firstDiscussionEvent.discussion_id -eq "discussion-alpha") "Calibration event should record the discussion id."
Assert ($firstDiscussionEvent.finding_id -eq "claude-1") "Calibration event should record the finding id."
Assert ($firstDiscussionEvent.outcome -eq "confirmed") "Calibration event should record the outcome."
Assert ($firstWorkbenchEvent.reviewer -eq "claude-code") "Workbench calibration event should retain the reviewer."
Assert ($firstDiscussionEvent.notes -notmatch "sk-") "Calibration notes should redact secret-like values."
Assert (-not $firstDiscussionEvent.notes.Contains($providerKeyName)) "Calibration notes should redact provider environment variable names."
Assert ($firstDiscussionEvent.notes -notmatch "C:\\Users\\Alice") "Calibration notes should redact absolute local paths."

& $recordScriptPath -DiscussionFolder $discussionFolder -FindingId "reasonix-1" -Reviewer "reasonix" -Outcome rejected -Notes "Second append."
$discussionLinesAfterSecondAppend = @(Get-Content -LiteralPath $discussionLog -Encoding UTF8)
$workbenchLinesAfterSecondAppend = @(Get-Content -LiteralPath $workbenchLog -Encoding UTF8)
Assert ($discussionLinesAfterSecondAppend.Count -eq 2) "Second calibration append should preserve the first discussion event."
Assert ($workbenchLinesAfterSecondAppend.Count -eq 2) "Second calibration append should preserve the first workbench event."
Assert ($discussionLinesAfterSecondAppend[0] -eq $discussionLines[0]) "Second calibration append must not overwrite the first discussion line."
foreach ($line in @($discussionLinesAfterSecondAppend + $workbenchLinesAfterSecondAppend)) {
$line | ConvertFrom-Json | Out-Null
}

$invalidOutcomeError = $null
try {
& $recordScriptPath -DiscussionFolder $discussionFolder -FindingId "invalid-1" -Reviewer "claude-code" -Outcome invalid 2>&1 | Out-Null
} catch {
$invalidOutcomeError = $_
}
Assert ($null -ne $invalidOutcomeError) "Calibration should reject invalid outcomes."
} finally {
Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
