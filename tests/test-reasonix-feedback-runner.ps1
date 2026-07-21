$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptsRoot = Join-Path $repoRoot "scripts"
$newDiscussion = Join-Path $scriptsRoot "New-AgentDiscussion.ps1"
$invokeReasonix = Join-Path $scriptsRoot "Invoke-ReasonixFeedback.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-reasonix-feedback-" + [guid]::NewGuid().ToString("N"))

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $fakeReasonix = Join-Path $tempRoot "fake-reasonix.ps1"
  Set-Content -LiteralPath $fakeReasonix -Encoding ASCII -Value @'
$prompt = [Console]::In.ReadToEnd()
Set-Content -LiteralPath "reasonix-received-prompt.txt" -Encoding UTF8 -Value $prompt
Write-Output ([char]27 + "[36mReasonix status trace" + [char]27 + "[0m")
Write-Output "| thinking"
Write-Output '-> read_file {"path":"brief.md"}'
Write-Output "# Code Review Feedback"
Write-Output ""
Write-Output "## Findings"
Write-Output "Reasonix CLI produced canonical review feedback."
Write-Output ""
Write-Output "## Risk Assessment"
Write-Output "Desktop session locks remain a preflight concern."
Write-Output ""
Write-Output "## Test Gaps"
Write-Output "This test uses a fake CLI."
Write-Output ""
Write-Output "## Recommended Changes"
Write-Output "Keep the CLI path as the automated reviewer route."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output "None."
Write-Output "Total cost: 0.01"
'@
  $reference = Join-Path $tempRoot "review-target.md"
  Set-Content -LiteralPath $reference -Encoding UTF8 -Value "REASONIX_REFERENCE_MARKER"
  $discussion = & $newDiscussion `
    -WorkbenchRoot $tempRoot `
    -Slug "reasonix-feedback" `
    -Topic "Reasonix feedback" `
    -Question "Can Reasonix review the frozen package non-interactively?" `
    -Context "Use CLI review." `
    -Mode code-review `
    -Protocol feedback `
    -ReferencePaths $reference `
    -Agents reasonix
  $discussion = ($discussion | Select-Object -Last 1).Trim()

  & $invokeReasonix -DiscussionFolder $discussion -ReasonixCommand $fakeReasonix -ReasonixDesktopProcessName "" -Collect | Out-Null
  $feedbackPath = Join-Path $discussion "round1\reasonix.md"
  Assert (Test-Path -LiteralPath $feedbackPath -PathType Leaf) "Reasonix CLI should create canonical round feedback."
  $feedback = Get-Content -LiteralPath $feedbackPath -Raw -Encoding UTF8
  Assert ($feedback.TrimStart().StartsWith("# Code Review Feedback")) "Reasonix feedback should start at the contract heading."
  Assert (-not $feedback.Contains("thinking")) "Reasonix thinking trace should be removed."
  Assert (-not $feedback.Contains("read_file")) "Reasonix tool trace should be removed."
  Assert (-not $feedback.Contains("Total cost")) "Reasonix cost trace should be removed."

  $invocationFolder = Join-Path $discussion "invocations\round1-reasonix"
  Assert (Test-Path -LiteralPath (Join-Path $invocationFolder "stdout.log")) "Reasonix stdout diagnostics should be retained."
  Assert (-not (Test-Path -LiteralPath (Join-Path $invocationFolder "workspace"))) "Transient writable review workspace should be removed."
  $status = Get-Content -LiteralPath (Join-Path $discussion "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($status.state -eq "feedback_collected") "Collected Reasonix feedback should update discussion state."
  Assert ($status.round1_completed_agents -contains "reasonix") "Collector should count canonical Reasonix feedback."

  $slowReasonix = Join-Path $tempRoot "slow-fake-reasonix.ps1"
  Set-Content -LiteralPath $slowReasonix -Encoding ASCII -Value @'
[void][Console]::In.ReadToEnd()
$invocation = Split-Path (Get-Location).Path -Parent
$countPath = Join-Path $invocation "reasonix-invocation-count.txt"
$count = if (Test-Path -LiteralPath $countPath) { [int](Get-Content -LiteralPath $countPath -Raw) } else { 0 }
Set-Content -LiteralPath $countPath -Encoding ASCII -Value ($count + 1)
Start-Sleep -Seconds 3
Write-Output "# Code Review Feedback"
Write-Output ""
Write-Output "## Findings"
Write-Output "The background Reasonix result was adopted."
Write-Output ""
Write-Output "## Risk Assessment"
Write-Output "Duplicate calls are blocked."
Write-Output ""
Write-Output "## Test Gaps"
Write-Output "None."
Write-Output ""
Write-Output "## Recommended Changes"
Write-Output "Keep the lease."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output "None."
'@
  $slowDiscussion = & $newDiscussion -WorkbenchRoot $tempRoot -Slug slow-reasonix -Topic slow -Question slow -Context slow -Mode code-review -Agents reasonix
  $slowDiscussion = ($slowDiscussion | Select-Object -Last 1).Trim()
  $timeoutError = $null
  try { & $invokeReasonix -DiscussionFolder $slowDiscussion -ReasonixCommand $slowReasonix -ReasonixDesktopProcessName "" -TimeoutSeconds 1 } catch { $timeoutError = $_ }
  Assert ($timeoutError.Exception.Message -match "continues in the background") "Reasonix timeout should preserve the running process."
  $duplicateError = $null
  try { & $invokeReasonix -DiscussionFolder $slowDiscussion -ReasonixCommand $slowReasonix -ReasonixDesktopProcessName "" -TimeoutSeconds 1 } catch { $duplicateError = $_ }
  Assert ($duplicateError.Exception.Message -match "no duplicate reviewer was started") "Reasonix should block a duplicate reviewer while the lease PID is alive."
  Start-Sleep -Seconds 4
  & $invokeReasonix -DiscussionFolder $slowDiscussion -ReasonixCommand $slowReasonix -ReasonixDesktopProcessName "" -TimeoutSeconds 5 | Out-Null
  $slowInvocation = Join-Path $slowDiscussion "invocations\round1-reasonix"
  Assert ([int](Get-Content -LiteralPath (Join-Path $slowInvocation "reasonix-invocation-count.txt") -Raw) -eq 1) "Reasonix timeout takeover must not launch twice."

  $invalidReasonix = Join-Path $tempRoot "invalid-fake-reasonix.ps1"
  Set-Content -LiteralPath $invalidReasonix -Encoding ASCII -Value @'
[void][Console]::In.ReadToEnd()
Write-Output "short fragment"
'@
  $invalidDiscussion = & $newDiscussion -WorkbenchRoot $tempRoot -Slug invalid-reasonix -Topic invalid -Question invalid -Context invalid -Mode code-review -Agents reasonix
  $invalidDiscussion = ($invalidDiscussion | Select-Object -Last 1).Trim()
  $invalidError = $null
  try { & $invokeReasonix -DiscussionFolder $invalidDiscussion -ReasonixCommand $invalidReasonix -ReasonixDesktopProcessName "" } catch { $invalidError = $_ }
  Assert ($null -ne $invalidError) "Malformed Reasonix output should fail."
  Assert (Test-Path -LiteralPath (Join-Path $invalidDiscussion "invalid-feedback\round1-reasonix.md")) "Malformed Reasonix output should be preserved."
  Assert (-not (Test-Path -LiteralPath (Join-Path $invalidDiscussion "round1\reasonix.md"))) "Malformed Reasonix output must not become canonical feedback."
  $invalidStatus = Get-Content -LiteralPath (Join-Path $invalidDiscussion "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($invalidStatus.state -eq "invalid_feedback_empty_or_fragment") "Malformed Reasonix feedback should update the shared invalid state contract."

  $failingReasonix = Join-Path $tempRoot "failing-fake-reasonix.ps1"
  Set-Content -LiteralPath $failingReasonix -Encoding ASCII -Value "[void][Console]::In.ReadToEnd()`nWrite-Error 'transient failure'`nexit 9"
  $failedDiscussion = & $newDiscussion -WorkbenchRoot $tempRoot -Slug failed-reasonix -Topic failed -Question failed -Context failed -Mode code-review -Agents reasonix
  $failedDiscussion = ($failedDiscussion | Select-Object -Last 1).Trim()
  $failedError = $null
  try { & $invokeReasonix -DiscussionFolder $failedDiscussion -ReasonixCommand $failingReasonix -ReasonixDesktopProcessName "" } catch { $failedError = $_ }
  Assert ($failedError.Exception.Message -match "RetryFailedInvocation") "Failed Reasonix invocation should require an explicit retry."
  & $invokeReasonix -DiscussionFolder $failedDiscussion -ReasonixCommand $fakeReasonix -ReasonixDesktopProcessName "" -RetryFailedInvocation | Out-Null
  Assert (Test-Path -LiteralPath (Join-Path $failedDiscussion "round1\reasonix.md")) "Explicit failed-invocation retry should produce canonical Reasonix feedback."
  Assert (@(Get-ChildItem -LiteralPath (Join-Path $failedDiscussion "failed-invocations") -Directory).Count -eq 1) "Failed Reasonix invocation evidence should be archived before retry."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
