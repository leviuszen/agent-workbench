$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) { throw $Message }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptsRoot = Join-Path $repoRoot "scripts"
$newDiscussion = Join-Path $scriptsRoot "New-AgentDiscussion.ps1"
$collectDiscussion = Join-Path $scriptsRoot "Collect-AgentDiscussion.ps1"
$invokeClaude = Join-Path $scriptsRoot "Invoke-ClaudeFeedback.ps1"
$testManifest = Join-Path $scriptsRoot "Test-AgentReferenceManifest.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-audit-reliability-" + [guid]::NewGuid().ToString("N"))
$priorClaudeExe = $env:CLAUDE_CODE_EXE

function New-Discussion {
  param(
    [string[]]$Agents = @("claude-code"),
    [string[]]$OptionalAgents = @(),
    [string[]]$ReferencePaths = @(),
    [string]$Protocol = "feedback"
  )
  $params = @{
    WorkbenchRoot = $tempRoot
    Slug = "audit-reliability"
    Topic = "Audit reliability"
    Question = "Does the audit reliability contract hold?"
    Context = "Use only the frozen evidence package."
    Mode = "code-review"
    Protocol = $Protocol
    Agents = $Agents
    OptionalAgents = $OptionalAgents
    ReferencePaths = $ReferencePaths
  }
  return ((& $newDiscussion @params | Select-Object -Last 1).Trim())
}

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $reference = Join-Path $tempRoot "required-evidence.md"
  Set-Content -LiteralPath $reference -Encoding UTF8 -Value "REFERENCE_COMPLETENESS_MARKER"

  $discussion = New-Discussion -OptionalAgents @("reasonix") -ReferencePaths @($reference)
  $statusPath = Join-Path $discussion "status.json"
  $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($status.required_agents -contains "claude-code") "Agents should remain required reviewers."
  Assert ($status.optional_agents -contains "reasonix") "OptionalAgents should be persisted separately."
  Assert ($status.agents.Count -eq 2) "The compatibility agents roster should contain required and optional reviewers."
  $brief = Get-Content -LiteralPath (Join-Path $discussion "brief.md") -Raw -Encoding UTF8
  Assert ($brief.Contains("- required: claude-code")) "The brief should identify required reviewers."
  Assert ($brief.Contains("- optional: reasonix")) "The brief should identify optional reviewers."

  & $testManifest -DiscussionFolder $discussion -RequiredBasenames "required-evidence.md"
  $snapshot = Get-ChildItem -LiteralPath (Join-Path $discussion "references\files") -File | Select-Object -First 1
  Add-Content -LiteralPath $snapshot.FullName -Encoding UTF8 -Value "CORRUPTION"
  $manifestError = $null
  try { & $testManifest -DiscussionFolder $discussion } catch { $manifestError = $_ }
  Assert ($null -ne $manifestError) "Changed frozen snapshots should fail the completeness gate."
  Assert ($manifestError.Exception.Message -match "byte count|SHA-256") "Completeness failure should identify changed evidence."

  $optionalDiscussion = New-Discussion -OptionalAgents @("reasonix") -Protocol "adversarial-discussion"
  Set-Content -LiteralPath (Join-Path $optionalDiscussion "round1\claude-code.md") -Encoding UTF8 -Value "# Code Review Feedback`n`n## Findings`n`nNo blocking finding."
  & $collectDiscussion -DiscussionFolder $optionalDiscussion | Out-Null
  $optionalStatus = Get-Content -LiteralPath (Join-Path $optionalDiscussion "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($optionalStatus.state -eq "feedback_collected") "Missing optional reviewers must not block the required Round 1 gate."
  Assert ($optionalStatus.round1_missing_agents.Count -eq 0) "Required reviewer should be complete."
  Assert ($optionalStatus.round1_missing_optional_agents -contains "reasonix") "Missing optional reviewer should remain visible."

  $requiredMissingDiscussion = New-Discussion -OptionalAgents @("reasonix")
  Set-Content -LiteralPath (Join-Path $requiredMissingDiscussion "round1\reasonix.md") -Encoding UTF8 -Value "# Code Review Feedback`n`n## Findings`n`nOptional-only evidence."
  & $collectDiscussion -DiscussionFolder $requiredMissingDiscussion | Out-Null
  $requiredMissingStatus = Get-Content -LiteralPath (Join-Path $requiredMissingDiscussion "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($requiredMissingStatus.state -eq "awaiting_round1_reviewers") "Optional feedback alone must not satisfy a required reviewer gate."
  Assert ($requiredMissingStatus.round1_missing_agents -contains "claude-code") "Missing required reviewer should remain explicit."

  $modeError = $null
  try { New-Discussion -Agents @("claude-code") | Out-Null; & $newDiscussion -WorkbenchRoot $tempRoot -Slug bad-mode -Topic t -Question q -Context c -Mode review } catch { $modeError = $_ }
  Assert ($null -ne $modeError) "Mode=review should fail."
  Assert ($modeError.Exception.Message -match "code-review.*strategy-review") "Mode=review error should name valid review modes."

  $protocolError = $null
  try { & $newDiscussion -WorkbenchRoot $tempRoot -Slug bad-protocol -Topic t -Question q -Context c -Protocol scientific } catch { $protocolError = $_ }
  Assert ($null -ne $protocolError) "Protocol=scientific should fail."
  Assert ($protocolError.Exception.Message -match "AuditProfile scientific.*Protocol adversarial-discussion") "Protocol error should show the correct scientific audit combination."

  $fakeClaude = Join-Path $tempRoot "fake-claude-autodiscovery.ps1"
  Set-Content -LiteralPath $fakeClaude -Encoding ASCII -Value @'
Write-Output "# Code Review Feedback"
Write-Output ""
Write-Output "## Findings"
Write-Output "Use automatic executable discovery."
Write-Output ""
Write-Output "## Risk Assessment"
Write-Output "CLAUDE_AUTODISCOVERY_MARKER confirms the environment override was used."
Write-Output ""
Write-Output "## Test Gaps"
Write-Output "The explicit path must still fail closed when invalid."
Write-Output ""
Write-Output "## Recommended Changes"
Write-Output "None."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output "None."
'@
  $env:CLAUDE_CODE_EXE = $fakeClaude
  $autoDiscussion = New-Discussion
  & $invokeClaude -DiscussionFolder $autoDiscussion -Round 1 | Out-Null
  $autoFeedback = Get-Content -LiteralPath (Join-Path $autoDiscussion "round1\claude-code.md") -Raw -Encoding UTF8
  Assert ($autoFeedback.Contains("CLAUDE_AUTODISCOVERY_MARKER")) "CLAUDE_CODE_EXE should be used when ClaudeExe is omitted."

  $explicitError = $null
  try { & $invokeClaude -DiscussionFolder (New-Discussion) -ClaudeExe (Join-Path $tempRoot "missing-claude.exe") } catch { $explicitError = $_ }
  Assert ($null -ne $explicitError) "An explicitly supplied missing ClaudeExe must fail closed."
  Assert ($explicitError.Exception.Message -match "Explicit ClaudeExe does not exist") "Explicit path failure should be actionable."

  $slowClaude = Join-Path $tempRoot "slow-fake-claude.ps1"
  Set-Content -LiteralPath $slowClaude -Encoding ASCII -Value @'
$countPath = Join-Path (Get-Location).Path "slow-invocation-count.txt"
$count = if (Test-Path -LiteralPath $countPath) { [int](Get-Content -LiteralPath $countPath -Raw) } else { 0 }
Set-Content -LiteralPath $countPath -Encoding ASCII -Value ($count + 1)
Start-Sleep -Seconds 3
Write-Output "# Code Review Feedback"
Write-Output ""
Write-Output "## Findings"
Write-Output "The detached reviewer completed exactly once after the caller timeout."
Write-Output ""
Write-Output "## Risk Assessment"
Write-Output "A blind retry would create competing evidence."
Write-Output ""
Write-Output "## Test Gaps"
Write-Output "External process termination is outside this regression test."
Write-Output ""
Write-Output "## Recommended Changes"
Write-Output "Adopt the existing invocation result."
Write-Output ""
Write-Output "## Questions For Codex Or User"
Write-Output "None."
'@
  $slowDiscussion = New-Discussion
  $timeoutError = $null
  try { & $invokeClaude -DiscussionFolder $slowDiscussion -ClaudeExe $slowClaude -TimeoutSeconds 1 } catch { $timeoutError = $_ }
  Assert ($null -ne $timeoutError) "Slow reviewer should exceed the short caller wait."
  Assert ($timeoutError.Exception.Message -match "continues in the background") "Timeout should explain that the reviewer is still running."

  $duplicateError = $null
  try { & $invokeClaude -DiscussionFolder $slowDiscussion -ClaudeExe $slowClaude -TimeoutSeconds 1 } catch { $duplicateError = $_ }
  Assert ($null -ne $duplicateError) "A second call while the reviewer is running should stop."
  Assert ($duplicateError.Exception.Message -match "no duplicate reviewer was started") "Second call should explicitly reject duplicate reviewer work."

  Start-Sleep -Seconds 4
  & $invokeClaude -DiscussionFolder $slowDiscussion -ClaudeExe $slowClaude -TimeoutSeconds 5 | Out-Null
  Assert (Test-Path -LiteralPath (Join-Path $slowDiscussion "round1\claude-code.md")) "A later call should adopt the completed background result."
  Assert ([int](Get-Content -LiteralPath (Join-Path $slowDiscussion "slow-invocation-count.txt") -Raw) -eq 1) "Timeout recovery must not launch a second reviewer."

  $failingClaude = Join-Path $tempRoot "failing-fake-claude.ps1"
  Set-Content -LiteralPath $failingClaude -Encoding ASCII -Value "Write-Error 'transient failure'`nexit 7"
  $failedDiscussion = New-Discussion
  $failedError = $null
  try { & $invokeClaude -DiscussionFolder $failedDiscussion -ClaudeExe $failingClaude } catch { $failedError = $_ }
  Assert ($failedError.Exception.Message -match "RetryFailedInvocation") "Failed Claude invocation should require an explicit retry."
  & $invokeClaude -DiscussionFolder $failedDiscussion -ClaudeExe $fakeClaude -RetryFailedInvocation | Out-Null
  Assert (Test-Path -LiteralPath (Join-Path $failedDiscussion "round1\claude-code.md")) "Explicit failed-invocation retry should produce canonical Claude feedback."
  Assert (@(Get-ChildItem -LiteralPath (Join-Path $failedDiscussion "failed-invocations") -Directory).Count -eq 1) "Failed Claude invocation evidence should be archived before retry."
} finally {
  $env:CLAUDE_CODE_EXE = $priorClaudeExe
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
