param(
  [Parameter(Mandatory = $true)][string]$DiscussionFolder,
  [ValidateSet(1, 2)][int]$Round = 1,
  [string]$AgentName = "reasonix",
  [string]$ReasonixCommand = $(if ([string]::IsNullOrWhiteSpace($env:REASONIX_COMMAND)) { "reasonix" } else { $env:REASONIX_COMMAND }),
  [string]$Model,
  [ValidateRange(1, 200)][int]$MaxSteps = 30,
  [string]$ReasonixDesktopProcessName = "reasonix-desktop",
  [ValidateRange(1, 86400)][int]$TimeoutSeconds = 900,
  [switch]$RetryStaleInvocation,
  [switch]$RetryFailedInvocation,
  [switch]$Collect
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-ReasonixFeedbackText {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return "" }
  $safe = $Value -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED_SECRET]'
  $safe = $safe -replace '(?i)\b[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY)\b\s*[:=]\s*\S+', '[REDACTED_SECRET]'
  $safe = $safe -replace '[A-Za-z]:[\\/][^\r\n]+', '[REDACTED_PATH]'
  return $safe
}

function Resolve-ReasonixFeedbackCommand {
  param([string]$Command)
  if ([string]::IsNullOrWhiteSpace($Command)) { throw "ReasonixCommand is required." }
  if (($Command -match '^[A-Za-z]:[\/]') -or $Command.Contains("\") -or $Command.Contains("/")) {
    if (-not (Test-Path -LiteralPath $Command -PathType Leaf)) { throw "ReasonixCommand does not exist: $(Redact-ReasonixFeedbackText -Value $Command)" }
    return (Resolve-Path -LiteralPath $Command).Path
  }
  $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $resolved) { throw "ReasonixCommand was not found on PATH: $Command" }
  return $resolved.Source
}

function ConvertTo-ReasonixArgument {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Start-ReasonixFeedbackHelper {
  param([string[]]$Arguments)
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-ReasonixArgument -Value $_ }) -join " ")
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) { $process.Dispose(); throw "Reasonix feedback helper process did not start." }
  return $process
}

function Get-FeedbackContract {
  param([object]$Status)
  $format = [string]$Status.expected_output_format
  $heading = "# Agent Discussion Feedback"
  $sections = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($format -split '\r?\n')) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("# ") -and $heading -eq "# Agent Discussion Feedback") { $heading = $trimmed }
    if ($trimmed.StartsWith("## ")) { $sections.Add($trimmed) }
  }
  return [pscustomobject]@{ Heading = $heading; Sections = @($sections); Format = $format }
}

function ConvertFrom-ReasonixFeedbackOutput {
  param([string]$Value, [string]$Heading)
  $ansiPattern = ([string][char]27) + '\[[0-?]*[ -/]*[@-~]'
  $content = [regex]::Replace($Value, $ansiPattern, "").Trim()
  $headingIndex = $content.IndexOf($Heading, [System.StringComparison]::OrdinalIgnoreCase)
  if ($headingIndex -lt 0) { return $content }
  $content = $content.Substring($headingIndex).Trim()
  $cleanLines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($content -split '\r?\n')) {
    if ($line -match '^\s*[\u00B7]\s+\d+\s+tok\b') { continue }
    if ($line -match '^\s*[|\u258E]\s*thinking\s*$') { continue }
    if ($line -match '^\s*->\s+[A-Za-z0-9_-]+\s+\{.*\}\s*$') { continue }
    if ($line -match '^\s*(Cost|Total cost|Tokens?)\s*[:=]') { continue }
    $cleanLines.Add($line)
  }
  return ($cleanLines -join [Environment]::NewLine).Trim()
}

function Reject-ReasonixFeedback {
  param([string]$State, [string]$Reason, [string]$Feedback)
  $invalidRoot = Join-Path $resolvedFolder "invalid-feedback"
  New-Item -ItemType Directory -Force -Path $invalidRoot | Out-Null
  $invalidPath = Join-Path $invalidRoot ("round{0}-{1}.md" -f $Round, $safeAgent)
  Set-Content -LiteralPath $invalidPath -Value $Feedback -Encoding UTF8
  $invalidStatus = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $invalidStatus | Add-Member -NotePropertyName "state" -NotePropertyValue $State -Force
  $invalidStatus | Add-Member -NotePropertyName "invalid_feedback_reason" -NotePropertyValue $Reason -Force
  $invalidStatus | Add-Member -NotePropertyName "invalid_feedback_round" -NotePropertyValue $Round -Force
  $invalidStatus | Add-Member -NotePropertyName "invalid_feedback_agent" -NotePropertyValue $safeAgent -Force
  $invalidStatus | Add-Member -NotePropertyName "invalid_feedback_file" -NotePropertyValue ("invalid-feedback/round{0}-{1}.md" -f $Round, $safeAgent) -Force
  $invalidStatus | Add-Member -NotePropertyName "updated_at" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz") -Force
  $invalidStatus | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statusPath -Encoding UTF8
  Add-Content -LiteralPath (Join-Path $resolvedFolder "run.log") -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')] invalid reasonix feedback round=$Round agent=$safeAgent state=$State reason=$Reason" -Encoding UTF8
  Remove-Item -LiteralPath $invocationFolder -Recurse -Force -ErrorAction SilentlyContinue
  throw "Reasonix feedback did not match expected format: ${State}: $Reason"
}

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) { throw "DiscussionFolder does not exist." }
$resolvedFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$statusPath = Join-Path $resolvedFolder "status.json"
$briefPath = Join-Path $resolvedFolder "brief.md"
$roundFolder = Join-Path $resolvedFolder "round$Round"
foreach ($required in @($statusPath, $briefPath, $roundFolder)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Required discussion artifact is missing: $(Split-Path -Leaf $required)" }
}
& (Join-Path $PSScriptRoot "Test-AgentReferenceManifest.ps1") -DiscussionFolder $resolvedFolder

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
$contract = Get-FeedbackContract -Status $status
$safeAgent = ($AgentName.ToLowerInvariant() -replace '[^a-z0-9_-]+', '-').Trim('-')
$outputPath = Join-Path $roundFolder "$safeAgent.md"
if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
  if ($Collect) { & (Join-Path $PSScriptRoot "Collect-AgentDiscussion.ps1") -DiscussionFolder $resolvedFolder | Out-Null }
  Write-Output $outputPath
  return
}

$invocationFolder = Join-Path $resolvedFolder ("invocations\round{0}-{1}" -f $Round, $safeAgent)
$leasePath = Join-Path $invocationFolder "lease.json"
$completionPath = Join-Path $invocationFolder "completion.json"
$stdoutLog = Join-Path $invocationFolder "stdout.log"
$stderrLog = Join-Path $invocationFolder "stderr.log"
$scratch = Join-Path $invocationFolder "workspace"
$existingLease = $null
if (Test-Path -LiteralPath $leasePath -PathType Leaf) { $existingLease = Get-Content -LiteralPath $leasePath -Raw -Encoding UTF8 | ConvertFrom-Json }
if (($null -ne $existingLease) -and -not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
  $running = Get-Process -Id ([int]$existingLease.pid) -ErrorAction SilentlyContinue
  if ($null -ne $running) { throw "Reasonix feedback invocation is still running; no duplicate reviewer was started. round=$Round agent=$safeAgent pid=$($existingLease.pid)" }
  if (-not $RetryStaleInvocation) { throw "Reasonix feedback invocation lease is stale and has no completion record. Inspect it, then retry explicitly with -RetryStaleInvocation." }
  Remove-Item -LiteralPath $invocationFolder -Recurse -Force
}

if (Test-Path -LiteralPath $completionPath -PathType Leaf) {
  $priorCompletion = Get-Content -LiteralPath $completionPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$priorCompletion.state -ne "completed" -and $RetryFailedInvocation) {
    $failedRoot = Join-Path $resolvedFolder "failed-invocations"
    New-Item -ItemType Directory -Force -Path $failedRoot | Out-Null
    $failedName = "$(Split-Path -Leaf $invocationFolder)-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N').Substring(0,6))"
    Move-Item -LiteralPath $invocationFolder -Destination (Join-Path $failedRoot $failedName)
  }
}

if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
  if (-not [string]::IsNullOrWhiteSpace($ReasonixDesktopProcessName)) {
    $desktop = Get-Process -Name $ReasonixDesktopProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $desktop) { throw "Reasonix Desktop is running and may hold the CLI session lock. Close it before CLI review. process=$ReasonixDesktopProcessName pid=$($desktop.Id)" }
  }
  New-Item -ItemType Directory -Force -Path $scratch | Out-Null
  Copy-Item -LiteralPath $briefPath -Destination (Join-Path $scratch "brief.md") -Force
  if ($Round -eq 2) {
    $synthesisPath = Join-Path $resolvedFolder "codex-synthesis.md"
    if (-not (Test-Path -LiteralPath $synthesisPath -PathType Leaf)) { throw "codex-synthesis.md is required for round 2 feedback." }
    Copy-Item -LiteralPath $synthesisPath -Destination (Join-Path $scratch "codex-synthesis.md") -Force
  }
  $references = Join-Path $resolvedFolder "references"
  if (Test-Path -LiteralPath $references -PathType Container) { Copy-Item -LiteralPath $references -Destination (Join-Path $scratch "references") -Recurse -Force }
  $scratchToml = (Resolve-Path -LiteralPath $scratch).Path.Replace("\", "/")
  $runtimeConfig = "[sandbox]`nworkspace_root = `"$scratchToml`"`n`n[permissions]`nmode = `"allow`"`ndeny = [`"Bash(*)`"]`n"
  [System.IO.File]::WriteAllText((Join-Path $scratch "reasonix.toml"), $runtimeConfig, [System.Text.UTF8Encoding]::new($false))
  $roundInstruction = if ($Round -eq 2) { "Read codex-synthesis.md and answer only disputed, blocking, or weak-evidence points. Mark each position maintained, revised, or withdrawn." } else { "Round 1 is blind and independent. Do not read another reviewer's output during scientific Round 1." }
  $prompt = @"
You are a controlled read-only external reviewer in Agent Workbench.
Read brief.md and every frozen snapshot listed in references/manifest.md when present. $roundInstruction
Do not edit files. Bash is denied. Return only the requested Markdown review to stdout.
The first line must be exactly:
$($contract.Heading)
Include every required section from the output format in brief.md.
"@
  $promptFile = Join-Path $invocationFolder "prompt.md"
  [System.IO.File]::WriteAllText($promptFile, $prompt, [System.Text.UTF8Encoding]::new($false))
  $resolvedReasonix = Resolve-ReasonixFeedbackCommand -Command $ReasonixCommand
  $helperArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "Invoke-ReasonixFeedbackProcess.ps1"), "-ReasonixCommand", $resolvedReasonix, "-WorkingDirectory", $scratch, "-PromptFile", $promptFile, "-StdoutFile", $stdoutLog, "-StderrFile", $stderrLog, "-CompletionFile", $completionPath, "-MaxSteps", [string]$MaxSteps)
  if (-not [string]::IsNullOrWhiteSpace($Model)) { $helperArgs += @("-Model", $Model) }
  $helper = Start-ReasonixFeedbackHelper -Arguments $helperArgs
  $lease = [ordered]@{ invocation_id=[guid]::NewGuid().ToString(); state="running"; pid=$helper.Id; round=$Round; agent=$safeAgent; started_at=(Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz") }
  $lease | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $leasePath -Encoding UTF8
  $helperPid = $helper.Id
  $finished = $helper.WaitForExit($TimeoutSeconds * 1000)
  $helper.Dispose()
  if (-not $finished) { throw "Reasonix feedback invocation exceeded the caller wait of $TimeoutSeconds second(s) but continues in the background. Rerun this command to adopt the result; do not start a duplicate. pid=$helperPid" }
}

if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf)) { throw "Reasonix feedback helper exited without completion evidence." }
$completion = Get-Content -LiteralPath $completionPath -Raw -Encoding UTF8 | ConvertFrom-Json
$safeStdout = if (Test-Path -LiteralPath $stdoutLog) { Get-Content -LiteralPath $stdoutLog -Raw -Encoding UTF8 } else { "" }
$safeStderr = if (Test-Path -LiteralPath $stderrLog) { Get-Content -LiteralPath $stderrLog -Raw -Encoding UTF8 } else { [string]$completion.error }
Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue

if ([string]$completion.state -ne "completed" -or [int]$completion.exit_code -ne 0) {
  $failure = ($safeStderr + [Environment]::NewLine + $safeStdout).Trim()
  if ($failure -match '(?i)this session is in use by another Reasonix window or process') { throw "Reasonix CLI session is locked. Close Reasonix Desktop and other Reasonix processes, then retry." }
  throw "Reasonix feedback invocation failed with exit code $($completion.exit_code): $failure. Inspect the invocation evidence, then use -RetryFailedInvocation for an explicit new attempt."
}
$feedback = ConvertFrom-ReasonixFeedbackOutput -Value $safeStdout -Heading $contract.Heading
if (-not $feedback.TrimStart().StartsWith($contract.Heading, [System.StringComparison]::OrdinalIgnoreCase)) {
  $state = if ($feedback.Trim().Length -lt 300) { "invalid_feedback_empty_or_fragment" } else { "invalid_feedback_offtask" }
  Reject-ReasonixFeedback -State $state -Reason "missing expected heading $($contract.Heading)" -Feedback $feedback
}
foreach ($section in $contract.Sections) {
  if ($feedback.IndexOf($section, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    Reject-ReasonixFeedback -State "invalid_feedback_incomplete" -Reason "missing expected section $section" -Feedback $feedback
  }
}
Set-Content -LiteralPath $outputPath -Value $feedback -Encoding UTF8
$completedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
Add-Content -LiteralPath (Join-Path $resolvedFolder "run.log") -Value "[$completedAt] reasonix CLI feedback invoked round=$Round agent=$safeAgent output=round$Round/$safeAgent.md bash=denied" -Encoding UTF8
if ($Collect) { & (Join-Path $PSScriptRoot "Collect-AgentDiscussion.ps1") -DiscussionFolder $resolvedFolder | Out-Null }
Write-Output $outputPath
