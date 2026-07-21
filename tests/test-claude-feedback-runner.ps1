$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$newDiscussionScript = Join-Path $repoRoot "scripts\New-AgentDiscussion.ps1"
$invokeScript = Join-Path $repoRoot "scripts\Invoke-ClaudeFeedback.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-claude-feedback-test-" + [guid]::NewGuid().ToString("N"))
$workbenchRoot = Join-Path $tempRoot "workbench"
$fakeClaude = Join-Path $tempRoot "fake-claude.ps1"
$fencedPreludeFakeClaude = Join-Path $tempRoot "fenced-prelude-fake-claude.ps1"
$invalidFakeClaude = Join-Path $tempRoot "invalid-fake-claude.ps1"
$fakeLauncher = Join-Path $tempRoot "fake-claude-launcher.bat"
$providerKeyName = ("ANTHROPIC" + "_API_KEY")

function Assert-NoSecretLikeContent {
  param(
    [string]$Content,
    [string]$Name
  )

  Assert ($Content -notmatch "sk-") "$Name contains sk- secret-like content."
  Assert (-not $Content.Contains($providerKeyName)) "$Name contains provider env var name."
  Assert ($Content -notmatch "api\.deepseek") "$Name contains api.deepseek secret-like content."
}

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

  Set-Content -LiteralPath $fakeClaude -Encoding ASCII -Value @'
Set-Content -LiteralPath "claude-args.txt" -Encoding UTF8 -Value ($args -join "`n")
if (-not (Test-Path -LiteralPath "brief.md")) {
  Write-Output "# Agent Discussion Feedback"
  Write-Output ""
  Write-Output "## Recommendation"
  Write-Output ""
  Write-Output "MISSING_BRIEF"
  exit 0
}

Write-Output "Below is the Markdown content for round1/claude-code.md:"
Write-Output ""
Write-Output '```markdown'
Write-Output "# Agent Discussion Feedback"
Write-Output ""
Write-Output "## Recommendation"
Write-Output ""
Write-Output "Use a staged review workflow and keep Codex as final moderator."
Write-Output ""
Write-Output "## Reasoning"
Write-Output ""
Write-Output "Fake Claude received the discussion brief and returned structured feedback."
Write-Output ""
Write-Output "## Risks"
Write-Output ""
Write-Output "Do not leak sk-feedbackSecret1234567890 or ANTHROPIC_API_KEY=abc123."
Write-Output ""
Write-Output "## Disagreements Or Unknowns"
Write-Output ""
Write-Output "None for this smoke test."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output ""
Write-Output "Should collection run automatically?"
Write-Output '```'
'@

  Set-Content -LiteralPath $fencedPreludeFakeClaude -Encoding ASCII -Value @'
Set-Content -LiteralPath "claude-args.txt" -Encoding UTF8 -Value ($args -join "`n")
Write-Output "Here is an accidental diagnostic snippet before the real response:"
Write-Output '```powershell'
Write-Output "Get-ChildItem references/files"
Write-Output '```'
Write-Output ""
Write-Output "# Agent Discussion Feedback"
Write-Output ""
Write-Output "## Recommendation"
Write-Output ""
Write-Output "Accept the structured feedback after ignoring the diagnostic prelude."
Write-Output ""
Write-Output "## Reasoning"
Write-Output ""
Write-Output "The expected heading appears after an unrelated fenced snippet."
Write-Output ""
Write-Output "## Risks"
Write-Output ""
Write-Output "A cleaner that extracts the first fence would discard this real response."
Write-Output ""
Write-Output "## Disagreements Or Unknowns"
Write-Output ""
Write-Output "None."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output ""
Write-Output "None."
'@

  Set-Content -LiteralPath $invalidFakeClaude -Encoding ASCII -Value @'
Write-Output "text"
Write-Output "Request GPT final acceptance without providing the requested structured audit."
'@

  Set-Content -LiteralPath $fakeLauncher -Encoding ASCII -Value @"
@echo off
set ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
set ANTHROPIC_API_KEY=sk-launcherSecret1234567890
set ANTHROPIC_MODEL=fake-model
"@

  $referenceSource = Join-Path $tempRoot "article-draft.md"
  Set-Content -LiteralPath $referenceSource -Encoding UTF8 -Value @"
# Article Draft

REFERENCE_PROMPT_MARKER: Claude should be told to read the discussion reference manifest.
"@

  $discussionFolder = & $newDiscussionScript `
    -WorkbenchRoot $workbenchRoot `
    -Slug "claude-feedback-runner" `
    -Topic "Feedback runner test" `
    -Question "Can Claude feedback be generated non-interactively?" `
    -Context "Use a fake Claude executable. Do not leak sk-contextSecret1234567890." `
    -ReferencePaths $referenceSource `
    -Agents claude-code

  $discussionFolder = ($discussionFolder | Select-Object -Last 1).Trim()
  Assert (Test-Path -LiteralPath $discussionFolder -PathType Container) "Discussion folder was not created."

  & $invokeScript `
    -DiscussionFolder $discussionFolder `
    -Round 1 `
    -AgentName "claude-code" `
    -ClaudeExe $fakeClaude `
    -ClaudeLauncher $fakeLauncher `
    -Collect | Out-Null

  $feedbackPath = Join-Path $discussionFolder "round1\claude-code.md"
  Assert (Test-Path -LiteralPath $feedbackPath -PathType Leaf) "Feedback file was not created."

  $feedback = Get-Content -LiteralPath $feedbackPath -Raw -Encoding UTF8
  Assert ($feedback.TrimStart().StartsWith("# Agent Discussion Feedback")) "Feedback should start with the expected heading after cleanup."
  Assert (-not $feedback.Contains("MISSING_BRIEF")) "Claude did not run from the discussion folder containing brief.md."
  Assert (-not $feedback.Contains("Below is the Markdown content")) "Feedback wrapper text was not removed."
  Assert (-not $feedback.Contains('```')) "Markdown code fence was not removed."
  Assert-NoSecretLikeContent -Content $feedback -Name "feedback"

  $status = Get-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($status.state -eq "feedback_collected") "Collect should update discussion state to feedback_collected."
  Assert ($status.round1_count -eq 1) "Collect should count one round1 feedback file."

  $runLog = Get-Content -LiteralPath (Join-Path $discussionFolder "run.log") -Raw -Encoding UTF8
  Assert ($runLog.Contains("claude feedback invoked")) "run.log should include a feedback invocation entry."
  Assert-NoSecretLikeContent -Content $runLog -Name "run.log"

  $fakeArgs = Get-Content -LiteralPath (Join-Path $discussionFolder "claude-args.txt") -Raw -Encoding UTF8
  Assert ($fakeArgs.Contains("references/manifest.md")) "Round 1 Claude prompt should instruct the agent to read reference snapshots when present."
  Assert ($fakeArgs.Contains("frozen snapshots")) "Round 1 Claude prompt should describe reference snapshots as frozen."
  Assert ($fakeArgs.Contains("fresh discussion")) "Round 1 Claude prompt should require a fresh discussion for changed source files."

  Set-Content -LiteralPath (Join-Path $discussionFolder "codex-synthesis.md") -Encoding UTF8 -Value @"
# Codex Synthesis

Round 1 converged on the moderator role, but still needs a second-round check.
"@

  & $invokeScript `
    -DiscussionFolder $discussionFolder `
    -Round 2 `
    -AgentName "claude-code" `
    -ClaudeExe $fakeClaude `
    -ClaudeLauncher $fakeLauncher | Out-Null

  $round2FeedbackPath = Join-Path $discussionFolder "round2\claude-code.md"
  Assert (Test-Path -LiteralPath $round2FeedbackPath -PathType Leaf) "Round 2 feedback file was not created."

  $fakeArgs = Get-Content -LiteralPath (Join-Path $discussionFolder "claude-args.txt") -Raw -Encoding UTF8
  Assert ($fakeArgs.Contains("codex-synthesis.md")) "Round 2 Claude prompt should instruct the agent to read codex-synthesis.md."
  Assert ($fakeArgs.Contains("references/manifest.md")) "Round 2 Claude prompt should preserve reference snapshot instructions."
  Assert ($fakeArgs.Contains("cannot see source-file changes made afterward")) "Round 2 Claude prompt should not imply it can see changed source files."

  $fencedPreludeDiscussionFolder = & $newDiscussionScript `
    -WorkbenchRoot $workbenchRoot `
    -Slug "fenced-prelude-feedback-runner" `
    -Topic "Fenced prelude feedback runner test" `
    -Question "Should the cleaner ignore an unrelated fenced snippet before the expected heading?" `
    -Context "Use a fake Claude executable that returns a fenced diagnostic snippet before real feedback." `
    -Agents claude-code

  $fencedPreludeDiscussionFolder = ($fencedPreludeDiscussionFolder | Select-Object -Last 1).Trim()
  & $invokeScript `
    -DiscussionFolder $fencedPreludeDiscussionFolder `
    -Round 1 `
    -AgentName "claude-code" `
    -ClaudeExe $fencedPreludeFakeClaude `
    -ClaudeLauncher $fakeLauncher `
    -Collect | Out-Null

  $fencedPreludeFeedback = Get-Content -LiteralPath (Join-Path $fencedPreludeDiscussionFolder "round1\claude-code.md") -Raw -Encoding UTF8
  Assert ($fencedPreludeFeedback.TrimStart().StartsWith("# Agent Discussion Feedback")) "Cleaner should keep the real feedback heading after a fenced prelude."
  Assert (-not $fencedPreludeFeedback.Contains("Get-ChildItem")) "Cleaner should not keep the unrelated fenced diagnostic snippet."
  Assert (-not $fencedPreludeFeedback.Contains('```')) "Cleaner should remove fenced-wrapper artifacts from accepted feedback."

  $invalidDiscussionFolder = & $newDiscussionScript `
    -WorkbenchRoot $workbenchRoot `
    -Slug "invalid-feedback-runner" `
    -Topic "Invalid feedback runner test" `
    -Question "Should invalid Claude feedback be rejected?" `
    -Context "Use a fake Claude executable that returns a too-short unstructured answer." `
    -Agents claude-code

  $invalidDiscussionFolder = ($invalidDiscussionFolder | Select-Object -Last 1).Trim()
  $invalidSucceeded = $true
  try {
    & $invokeScript `
      -DiscussionFolder $invalidDiscussionFolder `
      -Round 1 `
      -AgentName "claude-code" `
      -ClaudeExe $invalidFakeClaude `
      -ClaudeLauncher $fakeLauncher `
      -Collect | Out-Null
  } catch {
    $invalidSucceeded = $false
  }

  Assert (-not $invalidSucceeded) "Invalid Claude feedback should make the runner fail."
  Assert (-not (Test-Path -LiteralPath (Join-Path $invalidDiscussionFolder "round1\claude-code.md") -PathType Leaf)) "Invalid feedback should not be written as accepted round feedback."
  Assert (Test-Path -LiteralPath (Join-Path $invalidDiscussionFolder "invalid-feedback\round1-claude-code.md") -PathType Leaf) "Invalid feedback should be preserved as diagnostic evidence."
  $invalidStatus = Get-Content -LiteralPath (Join-Path $invalidDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($invalidStatus.state -eq "invalid_feedback_empty_or_fragment") "Short unstructured output should be classified as invalid_feedback_empty_or_fragment."
  Assert ($invalidStatus.invalid_feedback_reason -match "fragment|too short") "Invalid feedback status should explain the fragment failure."
  Assert (Test-Path -LiteralPath (Join-Path $invalidDiscussionFolder "retry-brief.md") -PathType Leaf) "Invalid feedback should create retry-brief.md."

  & $invokeScript `
    -DiscussionFolder $invalidDiscussionFolder `
    -Round 1 `
    -AgentName "claude-code" `
    -ClaudeExe $fakeClaude `
    -ClaudeLauncher $fakeLauncher `
    -RawReadOnlyRecovery `
    -Collect | Out-Null

  $recoveredFeedbackPath = Join-Path $invalidDiscussionFolder "round1\claude-code.md"
  $recoveryEvidencePath = Join-Path $invalidDiscussionFolder "recovery-feedback\round1-claude-code-direct.md"
  Assert (Test-Path -LiteralPath $recoveredFeedbackPath -PathType Leaf) "Raw read-only recovery should write the canonical feedback file."
  Assert (Test-Path -LiteralPath $recoveryEvidencePath -PathType Leaf) "Raw read-only recovery should preserve direct evidence separately."
  $recoveredStatus = Get-Content -LiteralPath (Join-Path $invalidDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($recoveredStatus.state -eq "feedback_collected") "Collected recovery should mark feedback_collected."
  Assert ($recoveredStatus.round1_count -eq 1) "Recovery evidence should not be double-counted as round feedback."
  Assert ($recoveredStatus.feedback_recovery_mode -eq "raw_read_only") "Status should record the recovery mode."
  Assert ($recoveredStatus.feedback_recovery_file -eq "recovery-feedback/round1-claude-code-direct.md") "Status should record the recovery evidence file."
  Assert ($recoveredStatus.feedback_recovery_canonical_file -eq "round1/claude-code.md") "Status should record the canonical recovered feedback file."
  Assert ($recoveredStatus.feedback_recovery_prior_invalid_file -eq "invalid-feedback/round1-claude-code.md") "Status should retain the prior invalid evidence path."
  $recoveryRunLog = Get-Content -LiteralPath (Join-Path $invalidDiscussionFolder "run.log") -Raw -Encoding UTF8
  Assert ($recoveryRunLog.Contains("recovery=raw_read_only")) "run.log should record raw read-only recovery."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
