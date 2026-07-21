param(
  [Parameter(Mandatory = $true)][string]$DiscussionFolder,
  [ValidateSet(1, 2)][int]$Round = 1,
  [string]$AgentName = "claude-code",
  [string]$ClaudeExe = "",
  [string]$ClaudeLauncher = "",
  [ValidateRange(1, 86400)][int]$TimeoutSeconds = 900,
  [switch]$RetryStaleInvocation,
  [switch]$RetryFailedInvocation,
  [switch]$RawReadOnlyRecovery,
  [switch]$Collect
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot "ClaudeRuntime.ps1")

function Redact-ClaudeWorkerText {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $providerKeyPattern = '\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY|[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY))\b(?:\s*[:=]\s*|\s+)?[^\s`"''<>()\[\]]*'
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace '(?i)\bapi\.deepseek[^\s`"''<>()\[\]]*', "[REDACTED_SECRET]"
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
    return "claude-code"
  }

  return $safe
}

function ConvertTo-ClaudeProcessArgument {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Start-ClaudeFeedbackHelper {
  param([string[]]$Arguments)
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-ClaudeProcessArgument -Value $_ }) -join " ")
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    $process.Dispose()
    throw "Claude feedback helper process did not start."
  }
  return $process
}

function Import-LauncherEnvironment {
  param([string]$LauncherPath)

  if ([string]::IsNullOrWhiteSpace($LauncherPath)) {
    return
  }

  if (-not (Test-Path -LiteralPath $LauncherPath -PathType Leaf)) {
    return
  }

  foreach ($line in Get-Content -LiteralPath $LauncherPath -Encoding UTF8) {
    if ($line -match '^\s*set\s+([^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
  }
}

function ConvertFrom-ClaudeMarkdownOutput {
  param(
    [string]$Value,
    [string]$ExpectedHeading = "# Agent Discussion Feedback"
  )

  $content = $Value.Trim()
  $headingIndex = $content.IndexOf($ExpectedHeading, [System.StringComparison]::OrdinalIgnoreCase)
  if ($headingIndex -lt 0 -and $ExpectedHeading -ne "# Agent Discussion Feedback") {
    $headingIndex = $content.IndexOf("# Agent Discussion Feedback", [System.StringComparison]::OrdinalIgnoreCase)
  }

  if ($headingIndex -ge 0) {
    $content = $content.Substring($headingIndex).Trim()
    $content = [regex]::Replace($content, '(?is)\s*```\s*$', '').Trim()
    return $content
  }

  $fenced = [regex]::Match($content, '(?is)```(?:markdown|md)?\s*(.*?)\s*```')
  if ($fenced.Success) {
    $content = $fenced.Groups[1].Value.Trim()
  }

  return $content
}

function ConvertTo-AgentRelativePath {
  param(
    [string]$BaseFolder,
    [string]$Path
  )

  $base = $BaseFolder.TrimEnd("\", "/")
  $relative = $Path
  if ($relative.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    $relative = $relative.Substring($base.Length)
  }

  return ($relative.TrimStart("\", "/") -replace "\\", "/")
}

function Get-ExpectedFeedbackHeading {
  param([string]$StatusFile)

  $defaultHeading = "# Agent Discussion Feedback"
  $status = Get-Content -LiteralPath $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($status.PSObject.Properties.Name -notcontains "expected_output_format") {
    return $defaultHeading
  }

  $format = [string]$status.expected_output_format
  if ([string]::IsNullOrWhiteSpace($format)) {
    return $defaultHeading
  }

  foreach ($line in ($format -split '\r?\n')) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("# ")) {
      return $trimmed
    }
  }

  return $defaultHeading
}

function Get-ExpectedFeedbackSections {
  param([string]$StatusFile)

  $status = Get-Content -LiteralPath $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($status.PSObject.Properties.Name -notcontains "expected_output_format") {
    return @()
  }

  $format = [string]$status.expected_output_format
  if ([string]::IsNullOrWhiteSpace($format)) {
    return @()
  }

  $sections = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($format -split '\r?\n')) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("## ")) {
      $sections.Add($trimmed)
    }
  }

  return @($sections)
}

function Test-ClaudeFeedbackFormat {
  param(
    [string]$Content,
    [string]$ExpectedHeading,
    [string[]]$ExpectedSections
  )

  $trimmed = $Content.TrimStart()
  $presentSections = 0
  foreach ($section in @($ExpectedSections)) {
    if ($Content.IndexOf($section, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      $presentSections += 1
    }
  }

  if ($trimmed.Length -lt 300 -and $presentSections -eq 0) {
    return [pscustomobject]@{
      State = "invalid_feedback_empty_or_fragment"
      Reason = "output too short or fragmentary; missing expected heading and sections"
    }
  }

  if (-not $trimmed.StartsWith($ExpectedHeading, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ($presentSections -gt 0) {
      return [pscustomobject]@{
        State = "invalid_feedback_format"
        Reason = "missing expected heading: $ExpectedHeading"
      }
    }

    return [pscustomobject]@{
      State = "invalid_feedback_offtask"
      Reason = "missing expected heading and no expected sections were found"
    }
  }

  foreach ($section in @($ExpectedSections)) {
    if ($Content.IndexOf($section, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
      return [pscustomobject]@{
        State = "invalid_feedback_incomplete"
        Reason = "missing expected section: $section"
      }
    }
  }

  return $null
}

function Set-InvalidFeedbackStatus {
  param(
    [string]$StatusFile,
    [string]$InvalidFeedbackFile,
    [string]$State,
    [string]$Reason,
    [int]$Round,
    [string]$Agent
  )

  $status = Get-Content -LiteralPath $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $updatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  $relativeInvalidPath = Split-Path -Leaf (Split-Path -Parent $InvalidFeedbackFile)
  $relativeInvalidPath = "$relativeInvalidPath/$(Split-Path -Leaf $InvalidFeedbackFile)"

  $status | Add-Member -NotePropertyName "state" -NotePropertyValue $State -Force
  $status | Add-Member -NotePropertyName "invalid_feedback_reason" -NotePropertyValue $Reason -Force
  $status | Add-Member -NotePropertyName "invalid_feedback_round" -NotePropertyValue $Round -Force
  $status | Add-Member -NotePropertyName "invalid_feedback_agent" -NotePropertyValue $Agent -Force
  $status | Add-Member -NotePropertyName "invalid_feedback_file" -NotePropertyValue $relativeInvalidPath -Force
  $status | Add-Member -NotePropertyName "updated_at" -NotePropertyValue $updatedAt -Force
  $status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatusFile -Encoding UTF8
}

function Set-RecoveredFeedbackStatus {
  param(
    [string]$StatusFile,
    [string]$DiscussionFolder,
    [string]$RecoveryFeedbackFile,
    [string]$CanonicalFeedbackFile,
    [int]$Round,
    [string]$Agent
  )

  $status = Get-Content -LiteralPath $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $updatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  $priorInvalidFile = $null
  if ($status.PSObject.Properties.Name -contains "invalid_feedback_file") {
    $priorInvalidFile = [string]$status.invalid_feedback_file
  }

  $status | Add-Member -NotePropertyName "feedback_recovery_mode" -NotePropertyValue "raw_read_only" -Force
  $status | Add-Member -NotePropertyName "feedback_recovery_round" -NotePropertyValue $Round -Force
  $status | Add-Member -NotePropertyName "feedback_recovery_agent" -NotePropertyValue $Agent -Force
  $status | Add-Member -NotePropertyName "feedback_recovery_file" -NotePropertyValue (ConvertTo-AgentRelativePath -BaseFolder $DiscussionFolder -Path $RecoveryFeedbackFile) -Force
  $status | Add-Member -NotePropertyName "feedback_recovery_canonical_file" -NotePropertyValue (ConvertTo-AgentRelativePath -BaseFolder $DiscussionFolder -Path $CanonicalFeedbackFile) -Force
  if (-not [string]::IsNullOrWhiteSpace($priorInvalidFile)) {
    $status | Add-Member -NotePropertyName "feedback_recovery_prior_invalid_file" -NotePropertyValue $priorInvalidFile -Force
  }
  $status | Add-Member -NotePropertyName "updated_at" -NotePropertyValue $updatedAt -Force
  $status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatusFile -Encoding UTF8
}

function New-RetryBrief {
  param(
    [string]$DiscussionFolder,
    [string]$State,
    [string]$Reason,
    [string]$ExpectedHeading,
    [string[]]$ExpectedSections
  )

  $sectionsText = if ($ExpectedSections.Count -gt 0) {
    ($ExpectedSections | ForEach-Object { "- $_" }) -join [Environment]::NewLine
  } else {
    "- none declared"
  }

  $retryBrief = @"
# Agent Feedback Retry Brief

The previous external-agent response was rejected by Agent Workbench.

- invalid_state: $State
- reason: $Reason

## Required Response Shape

The first line must be exactly:

$ExpectedHeading

The response must include these sections:

$sectionsText

Do not return code-only snippets. Do not summarize next steps without findings. Re-read brief.md and any references/manifest.md snapshots before retrying.
"@

  Set-Content -LiteralPath (Join-Path $DiscussionFolder "retry-brief.md") -Value $retryBrief -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($DiscussionFolder)) {
  throw "DiscussionFolder is required."
}

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) {
  throw "DiscussionFolder does not exist: $(Redact-ClaudeWorkerText -Value $DiscussionFolder)"
}

$resolvedDiscussionFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$resolvedClaudeExe = Resolve-ClaudeCodeExecutable -ExplicitPath $ClaudeExe
$briefPath = Join-Path $resolvedDiscussionFolder "brief.md"
$roundFolder = Join-Path $resolvedDiscussionFolder "round$Round"
$statusPath = Join-Path $resolvedDiscussionFolder "status.json"
$runLogPath = Join-Path $resolvedDiscussionFolder "run.log"

if (-not (Test-Path -LiteralPath $briefPath -PathType Leaf)) {
  throw "brief.md is required."
}

if (-not (Test-Path -LiteralPath $roundFolder -PathType Container)) {
  throw "Round folder does not exist: round$Round"
}

if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw "status.json is required."
}

$referenceGate = Join-Path $PSScriptRoot "Test-AgentReferenceManifest.ps1"
& $referenceGate -DiscussionFolder $resolvedDiscussionFolder

$safeAgentName = ConvertTo-SafeAgentFileName -Value $AgentName
$outputPath = Join-Path $roundFolder "$safeAgentName.md"
$startedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$discussionStatus = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
$isScientificAudit = $discussionStatus.PSObject.Properties.Name -contains "audit_profile" -and $discussionStatus.audit_profile -eq "scientific"
$expectedHeading = Get-ExpectedFeedbackHeading -StatusFile $statusPath
$expectedSections = @(Get-ExpectedFeedbackSections -StatusFile $statusPath)
$referenceManifestPath = Join-Path $resolvedDiscussionFolder "references\manifest.md"
$referenceInstruction = ""
if (Test-Path -LiteralPath $referenceManifestPath -PathType Leaf) {
  $referenceInstruction = " Also read references/manifest.md and the listed snapshot files under references/files/. Use those frozen snapshots instead of original repository paths. These snapshots were copied when this discussion was created; Round 2 and RawReadOnlyRecovery cannot see source-file changes made afterward. If Codex needs a re-review of changed source files, Codex must create a fresh discussion with new ReferencePaths."
}

Import-LauncherEnvironment -LauncherPath $ClaudeLauncher

if ($Round -eq 2) {
  $synthesisPath = Join-Path $resolvedDiscussionFolder "codex-synthesis.md"
  if (-not (Test-Path -LiteralPath $synthesisPath -PathType Leaf)) {
    throw "codex-synthesis.md is required for round 2 feedback."
  }

  $scientificRoundInstruction = if ($isScientificAudit) { " Address only disputed, blocking, or weak-evidence findings from codex-synthesis.md. Mark each addressed position as maintained, revised, or withdrawn." } else { "" }
  $readInstruction = "Read the local files brief.md and codex-synthesis.md in the current working directory.$referenceInstruction Treat codex-synthesis.md as Codex's moderator synthesis from the prior round. Respond to its consensus points, disagreements, and questions.$scientificRoundInstruction"
} else {
  $scientificRoundInstruction = if ($isScientificAudit) { " Round 1 is blind and independent. Do not read another reviewer's output during scientific Round 1." } else { "" }
  $readInstruction = "Read the local file brief.md in the current working directory.$referenceInstruction$scientificRoundInstruction"
}

$prompt = @"
You are participating in an Agent Workbench discussion.

$readInstruction

Return only Markdown content for round$Round/$safeAgentName.md.
The first line of your response must be exactly:
$expectedHeading

Use the output format requested inside brief.md.
Do not wrap the answer in a Markdown code fence.
Do not edit, move, rename, delete, or create files.
Do not print API keys, provider configuration, or secrets.
"@

if ($RawReadOnlyRecovery) {
  $retryBriefInstruction = ""
  if (Test-Path -LiteralPath (Join-Path $resolvedDiscussionFolder "retry-brief.md") -PathType Leaf) {
    $retryBriefInstruction = "Read retry-brief.md as the rejection evidence and follow its required response shape."
  }

  $prompt = @"
You are participating in an Agent Workbench discussion as a controlled raw read-only recovery.

The prior feedback attempt was rejected as malformed or fragmentary. This recovery still must stay inside the same discussion folder, use only Read access, and return one complete Markdown response.

$readInstruction
$retryBriefInstruction

Return only Markdown content for round$Round/$safeAgentName.md.
The first line of your response must be exactly:
$expectedHeading

Use the output format requested inside brief.md.
Do not wrap the answer in a Markdown code fence.
Do not output only a file list, command snippet, or status fragment.
Do not edit, move, rename, delete, or create files.
Do not print API keys, provider configuration, or secrets.
"@
}

$invocationKind = if ($RawReadOnlyRecovery) { "recovery" } else { "standard" }
$invocationRoot = Join-Path $resolvedDiscussionFolder "invocations"
$invocationFolder = Join-Path $invocationRoot ("round{0}-{1}-{2}" -f $Round, $safeAgentName, $invocationKind)
$leasePath = Join-Path $invocationFolder "lease.json"
$promptPath = Join-Path $invocationFolder "prompt.md"
$stdoutPath = Join-Path $invocationFolder "stdout.md"
$stderrPath = Join-Path $invocationFolder "stderr.log"
$completionPath = Join-Path $invocationFolder "completion.json"

if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
  if ($Collect) {
    & (Join-Path $PSScriptRoot "Collect-AgentDiscussion.ps1") -DiscussionFolder $resolvedDiscussionFolder | Out-Null
  }
  Write-Output $outputPath
  return
}

$existingLease = $null
if (Test-Path -LiteralPath $leasePath -PathType Leaf) {
  $existingLease = Get-Content -LiteralPath $leasePath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if (($null -ne $existingLease) -and -not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
  $runningProcess = Get-Process -Id ([int]$existingLease.pid) -ErrorAction SilentlyContinue
  if ($null -ne $runningProcess) {
    throw "Claude feedback invocation is still running; no duplicate reviewer was started. round=$Round agent=$safeAgentName pid=$($existingLease.pid) lease=invocations/$(Split-Path -Leaf $invocationFolder)/lease.json"
  }
  if (-not $RetryStaleInvocation) {
    throw "Claude feedback invocation lease is stale and has no completion record. Inspect the invocation folder, then retry explicitly with -RetryStaleInvocation."
  }
  Remove-Item -LiteralPath $invocationFolder -Recurse -Force
  $existingLease = $null
}

if (Test-Path -LiteralPath $completionPath -PathType Leaf) {
  $priorCompletion = Get-Content -LiteralPath $completionPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$priorCompletion.state -ne "completed" -and $RetryFailedInvocation) {
    $failedRoot = Join-Path $resolvedDiscussionFolder "failed-invocations"
    New-Item -ItemType Directory -Force -Path $failedRoot | Out-Null
    $failedName = "$(Split-Path -Leaf $invocationFolder)-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N').Substring(0,6))"
    Move-Item -LiteralPath $invocationFolder -Destination (Join-Path $failedRoot $failedName)
  }
}

if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
  New-Item -ItemType Directory -Force -Path $invocationFolder | Out-Null
  [System.IO.File]::WriteAllText($promptPath, $prompt, [System.Text.UTF8Encoding]::new($false))
  $processScript = Join-Path $PSScriptRoot "Invoke-ClaudeFeedbackProcess.ps1"
  $helperArguments = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $processScript,
    "-ClaudeExe", $resolvedClaudeExe,
    "-WorkingDirectory", $resolvedDiscussionFolder,
    "-PromptFile", $promptPath,
    "-StdoutFile", $stdoutPath,
    "-StderrFile", $stderrPath,
    "-CompletionFile", $completionPath
  )
  $helperProcess = Start-ClaudeFeedbackHelper -Arguments $helperArguments
  $lease = [ordered]@{
    invocation_id = [guid]::NewGuid().ToString()
    state = "running"
    pid = $helperProcess.Id
    round = $Round
    agent = $safeAgentName
    kind = $invocationKind
    started_at = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  }
  $lease | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $leasePath -Encoding UTF8
  $helperPid = $helperProcess.Id
  $helperFinished = $helperProcess.WaitForExit($TimeoutSeconds * 1000)
  $helperProcess.Dispose()
  if (-not $helperFinished) {
    throw "Claude feedback invocation exceeded the caller wait of $TimeoutSeconds second(s) but continues in the background. Do not retry blindly; rerun this command to adopt the existing result. pid=$helperPid"
  }
}

if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
  throw "Claude feedback helper exited without writing completion evidence. Use -RetryStaleInvocation only after confirming its PID is no longer running."
}
$completion = Get-Content -LiteralPath $completionPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$completion.state -ne "completed" -or [int]$completion.exit_code -ne 0) {
  $failureText = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) { Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8 } else { [string]$completion.error }
  throw "Claude feedback invocation failed with exit code $($completion.exit_code): $(Redact-ClaudeWorkerText -Value $failureText). Inspect the invocation evidence, then use -RetryFailedInvocation for an explicit new attempt."
}

$rawText = (Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8).Trim()
if ([string]::IsNullOrWhiteSpace($rawText)) {
  throw "Claude feedback invocation returned empty output."
}

$cleaned = ConvertFrom-ClaudeMarkdownOutput -Value $rawText -ExpectedHeading $expectedHeading
$safeFeedback = Redact-ClaudeWorkerText -Value $cleaned
$formatFailure = Test-ClaudeFeedbackFormat -Content $safeFeedback -ExpectedHeading $expectedHeading -ExpectedSections $expectedSections
if ($null -ne $formatFailure) {
  $invalidRoot = Join-Path $resolvedDiscussionFolder "invalid-feedback"
  New-Item -ItemType Directory -Force -Path $invalidRoot | Out-Null
  $invalidFileName = if ($RawReadOnlyRecovery) { "round{0}-{1}-recovery.md" -f $Round, $safeAgentName } else { "round{0}-{1}.md" -f $Round, $safeAgentName }
  $invalidPath = Join-Path $invalidRoot $invalidFileName
  Set-Content -LiteralPath $invalidPath -Value $safeFeedback -Encoding UTF8
  Set-InvalidFeedbackStatus -StatusFile $statusPath -InvalidFeedbackFile $invalidPath -State $formatFailure.State -Reason $formatFailure.Reason -Round $Round -Agent $safeAgentName
  New-RetryBrief -DiscussionFolder $resolvedDiscussionFolder -State $formatFailure.State -Reason $formatFailure.Reason -ExpectedHeading $expectedHeading -ExpectedSections $expectedSections

  $completedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  $recoveryMarker = if ($RawReadOnlyRecovery) { " recovery=raw_read_only" } else { "" }
  $logLine = "[$completedAt] invalid claude feedback round=$Round agent=$safeAgentName$recoveryMarker state=$($formatFailure.State) reason=$(Redact-ClaudeWorkerText -Value $formatFailure.Reason) output=$(Redact-ClaudeWorkerText -Value $invalidPath)"
  Add-Content -LiteralPath $runLogPath -Value $logLine -Encoding UTF8
  Remove-Item -LiteralPath $invocationFolder -Recurse -Force -ErrorAction SilentlyContinue
  throw "Claude feedback did not match expected format: $($formatFailure.State): $($formatFailure.Reason)"
}

if ($RawReadOnlyRecovery) {
  $recoveryRoot = Join-Path $resolvedDiscussionFolder "recovery-feedback"
  New-Item -ItemType Directory -Force -Path $recoveryRoot | Out-Null
  $recoveryPath = Join-Path $recoveryRoot ("round{0}-{1}-direct.md" -f $Round, $safeAgentName)
  Set-Content -LiteralPath $recoveryPath -Value $safeFeedback -Encoding UTF8
}

Set-Content -LiteralPath $outputPath -Value $safeFeedback -Encoding UTF8

if ($RawReadOnlyRecovery) {
  Set-RecoveredFeedbackStatus -StatusFile $statusPath -DiscussionFolder $resolvedDiscussionFolder -RecoveryFeedbackFile $recoveryPath -CanonicalFeedbackFile $outputPath -Round $Round -Agent $safeAgentName
}

$completedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$recoveryMarker = if ($RawReadOnlyRecovery) { " recovery=raw_read_only evidence=$(Redact-ClaudeWorkerText -Value $recoveryPath)" } else { "" }
$logLine = "[$completedAt] claude feedback invoked round=$Round agent=$safeAgentName$recoveryMarker output=$(Redact-ClaudeWorkerText -Value $outputPath) claude=$(Split-Path -Leaf $resolvedClaudeExe)"
Add-Content -LiteralPath $runLogPath -Value $logLine -Encoding UTF8

if ($Collect) {
  $collectScript = Join-Path $PSScriptRoot "Collect-AgentDiscussion.ps1"
  & $collectScript -DiscussionFolder $resolvedDiscussionFolder | Out-Null
}

Write-Output $outputPath
