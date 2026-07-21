param(
[Parameter(Mandatory = $true)][string]$TaskFolder,
[string]$ReasonixCommand = $(if ([string]::IsNullOrWhiteSpace($env:REASONIX_COMMAND)) { "reasonix" } else { $env:REASONIX_COMMAND }),
[string]$Model,
[int]$MaxSteps = 30,
[string]$ReasonixDesktopProcessName = "reasonix-desktop",
[switch]$Collect
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-ReasonixWorkerText {
param([AllowNull()][string]$Value)

if ($null -eq $Value) {
return $null
}

$providerKeyPattern = '\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|TOGETHER_API_KEY|FIREWORKS_API_KEY|PERPLEXITY_API_KEY)\b(?:\s*[:=]\s*|\s+)?\S*'
$genericSecretPattern = '\b[A-Za-z0-9_]*(?:API|TOKEN|KEY|SECRET)[A-Za-z0-9_]*\b\s*[:=]\s*\S+'
$redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
$redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
$redacted = $redacted -replace "(?i)$genericSecretPattern", "[REDACTED_SECRET]"
$redacted = $redacted -replace '(?i)\bapi\.deepseek[^\s`"''<>()\[\]]*', "[REDACTED_SECRET]"
$redacted = $redacted -replace "(?i)(\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*)(?:[A-Za-z]:[\\/]|\\\\)[^\r\n]*?(?=\s+[A-Za-z_][A-Za-z0-9_]*=|$)", '$1[REDACTED_PATH]'
$redacted = $redacted -replace "[A-Za-z]:[\\/][^\r\n]+", "[REDACTED_PATH]"
$redacted = $redacted -replace "\\\\[^\\/\r\n]+[\\/][^\r\n]+", "[REDACTED_PATH]"
return $redacted
}

function Resolve-ReasonixCommand {
param([string]$Command)

if ([string]::IsNullOrWhiteSpace($Command)) {
throw "ReasonixCommand is required."
}

if (($Command -match "^[A-Za-z]:[\\/]") -or $Command.Contains("\") -or $Command.Contains("/")) {
if (-not (Test-Path -LiteralPath $Command -PathType Leaf)) {
throw "ReasonixCommand does not exist: $(Redact-ReasonixWorkerText -Value $Command)"
}

return (Resolve-Path -LiteralPath $Command).Path
}

$resolved = Get-Command $Command -ErrorAction SilentlyContinue
if ($null -eq $resolved) {
throw "ReasonixCommand was not found on PATH: $Command"
}

return $resolved.Source
}

function ConvertFrom-ReasonixMarkdownOutput {
param(
[string]$Value,
[string]$RequiredHeading
)

$ansiPattern = ([string][char]27) + '\[[0-?]*[ -/]*[@-~]'
$content = [regex]::Replace($Value, $ansiPattern, "").Trim()
$headingIndex = $content.IndexOf($RequiredHeading, [System.StringComparison]::OrdinalIgnoreCase)
if ($headingIndex -lt 0) {
throw "Reasonix output did not contain required heading: $RequiredHeading"
}

$prefix = $content.Substring(0, $headingIndex)
$headingWasInsideFence = ([regex]::Matches($prefix, '```').Count % 2) -eq 1
$content = $content.Substring($headingIndex).Trim()
if ($headingWasInsideFence) {
$content = [regex]::Replace($content, '(?s)\s*```\s*$', '').Trim()
}
$cleanLines = [System.Collections.Generic.List[string]]::new()
foreach ($line in ($content -split "`r?`n")) {
if ($line -match '^\s*[\u00B7]\s+\d+\s+tok\b') {
continue
}
if ($line -match '^\s*[|\u258E]\s*thinking\s*$') {
continue
}
if ($line -match '^\s*->\s+[A-Za-z0-9_-]+\s+\{.*\}\s*$') {
continue
}
$cleanLines.Add($line)
}

return (($cleanLines -join [Environment]::NewLine).Trim())
}

function Assert-ReasonixDesktopNotRunning {
param([string]$ProcessName)

if ([string]::IsNullOrWhiteSpace($ProcessName)) {
return
}

$desktopProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $desktopProcess) {
throw "Reasonix Desktop is running and may hold the CLI session lock. Close Reasonix Desktop, then retry the Agent Workbench task. process=$ProcessName pid=$($desktopProcess.Id)"
}
}

function ConvertTo-ReasonixTomlPath {
param([string]$Value)

return $Value.Replace("\", "/").Replace('"', '\"')
}

function ConvertTo-CmdArgument {
param([string]$Value)

if ($null -eq $Value) {
return '""'
}

$escaped = $Value -replace '"', '\"'
return '"' + $escaped + '"'
}

function Invoke-ReasonixCommand {
param(
[string]$Command,
[string[]]$Arguments,
[string]$InputText,
[string]$WorkingDirectory
)

$extension = [System.IO.Path]::GetExtension($Command)
$processFile = $Command
$processArguments = [System.Collections.Generic.List[string]]::new()

if ($extension -match '(?i)^\.ps1$') {
$processFile = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$processArguments.Add("-NoProfile")
$processArguments.Add("-ExecutionPolicy")
$processArguments.Add("Bypass")
$processArguments.Add("-File")
$processArguments.Add($Command)
foreach ($argument in $Arguments) {
$processArguments.Add($argument)
}
} elseif ($extension -match '(?i)^\.(cmd|bat)$') {
$cmdLineParts = [System.Collections.Generic.List[string]]::new()
$cmdLineParts.Add((ConvertTo-CmdArgument -Value $Command))
foreach ($argument in $Arguments) {
$cmdLineParts.Add((ConvertTo-CmdArgument -Value $argument))
}

$cmdLine = $cmdLineParts -join " "
$processFile = $env:ComSpec
$processArguments.Add("/d")
$processArguments.Add("/s")
$processArguments.Add("/c")
$processArguments.Add($cmdLine)
} else {
foreach ($argument in $Arguments) {
$processArguments.Add($argument)
}
}

$argumentLine = (($processArguments | ForEach-Object { ConvertTo-CmdArgument -Value $_ }) -join " ")
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $processFile
$startInfo.Arguments = $argumentLine
$startInfo.WorkingDirectory = $WorkingDirectory
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
try {
if (-not $process.Start()) {
throw "Reasonix process did not start."
}

$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$process.StandardInput.Write($InputText)
$process.StandardInput.Close()
$process.WaitForExit()
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()

return [pscustomobject]@{
ExitCode = [int]$process.ExitCode
Stdout = $stdout.TrimEnd()
Stderr = $stderr
}
} finally {
$process.Dispose()
}
}

if ([string]::IsNullOrWhiteSpace($TaskFolder)) {
throw "TaskFolder is required."
}

if (-not (Test-Path -LiteralPath $TaskFolder -PathType Container)) {
throw "TaskFolder does not exist: $(Redact-ReasonixWorkerText -Value $TaskFolder)"
}

if ($MaxSteps -lt 1) {
throw "MaxSteps must be greater than zero."
}

$resolvedTaskFolder = (Resolve-Path -LiteralPath $TaskFolder).Path
$resolvedReasonixCommand = Resolve-ReasonixCommand -Command $ReasonixCommand
Assert-ReasonixDesktopNotRunning -ProcessName $ReasonixDesktopProcessName
$statusPath = Join-Path $resolvedTaskFolder "status.json"
$taskPath = Join-Path $resolvedTaskFolder "task.md"
$contextPath = Join-Path $resolvedTaskFolder "context.md"
$runLogPath = Join-Path $resolvedTaskFolder "run.log"
$stdoutLogPath = Join-Path $resolvedTaskFolder "reasonix-stdout.log"
$stderrLogPath = Join-Path $resolvedTaskFolder "reasonix-stderr.log"

foreach ($requiredPath in @($statusPath, $taskPath, $contextPath)) {
if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
throw "Required task file missing: $(Split-Path -Leaf $requiredPath)"
}
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not ($status.PSObject.Properties.Name -contains "isolated_workspace")) {
throw "isolated_workspace.path is required before invoking Reasonix task runner."
}

$isolatedPath = $status.isolated_workspace.path
if ([string]::IsNullOrWhiteSpace($isolatedPath)) {
throw "isolated_workspace.path is required before invoking Reasonix task runner."
}

if (-not (Test-Path -LiteralPath $isolatedPath -PathType Container)) {
throw "isolated_workspace.path does not exist: $(Redact-ReasonixWorkerText -Value $isolatedPath)"
}

$resolvedIsolatedPath = (Resolve-Path -LiteralPath $isolatedPath).Path
$taskContent = Get-Content -LiteralPath $taskPath -Raw -Encoding UTF8
$contextContent = Get-Content -LiteralPath $contextPath -Raw -Encoding UTF8
$promptFolder = Join-Path $resolvedIsolatedPath ".agent-workbench"
$promptPath = Join-Path $promptFolder "reasonix-task.md"
$metricsPath = Join-Path $resolvedTaskFolder "agent-metrics.json"
$runtimeConfigPath = Join-Path $resolvedIsolatedPath "reasonix.toml"
$hadRuntimeConfig = Test-Path -LiteralPath $runtimeConfigPath -PathType Leaf
$runtimeConfigBytes = if ($hadRuntimeConfig) { [System.IO.File]::ReadAllBytes($runtimeConfigPath) } else { $null }

New-Item -ItemType Directory -Force -Path $promptFolder | Out-Null

$prompt = @"
You are working as a controlled external code worker for Agent Workbench.

Current working directory is the isolated git worktree. Modify files only in this isolated worktree:
$resolvedIsolatedPath

Read and follow the task packet below. Do not edit the source workspace, merge branches, apply patches to another workspace, commit, push, or print secrets.

Agent Workbench disables the Reasonix Bash tool on Windows because Reasonix v1.17.9 cannot OS-sandbox Bash there. Use Reasonix file tools for edits. Do not modify reasonix.toml. Do not claim shell tests were run; list them under Tests Not Run so Codex can run them after collection.

Return only Markdown for agent-result.md to stdout. The first line of your final response must be exactly:
# Agent Result

Include these sections:
## Files Changed
## Implementation Summary
## Tests Run
## Tests Not Run
## Risks And Open Questions
## Isolation Check

If you are blocked, still return # Agent Result with the blocker explained under Risks And Open Questions.

--- task.md ---
$taskContent

--- context.md ---
$contextContent
"@

Set-Content -LiteralPath $promptPath -Value $prompt -Encoding UTF8

$tomlWorkspaceRoot = ConvertTo-ReasonixTomlPath -Value $resolvedIsolatedPath
$runtimeConfig = @"
[sandbox]
workspace_root = "$tomlWorkspaceRoot"

[permissions]
mode = "allow"
deny = ["Bash(*)"]
"@
[System.IO.File]::WriteAllText($runtimeConfigPath, $runtimeConfig, [System.Text.UTF8Encoding]::new($false))

$arguments = [System.Collections.Generic.List[string]]::new()
$arguments.Add("run")
if (-not [string]::IsNullOrWhiteSpace($Model)) {
$arguments.Add("--model")
$arguments.Add($Model)
}
$arguments.Add("--max-steps")
$arguments.Add([string]$MaxSteps)
$arguments.Add("--dir")
$arguments.Add($resolvedIsolatedPath)
$arguments.Add("--metrics")
$arguments.Add($metricsPath)

$execution = $null
try {
$execution = Invoke-ReasonixCommand `
-Command $resolvedReasonixCommand `
-Arguments ([string[]]$arguments.ToArray()) `
-InputText $prompt `
-WorkingDirectory $resolvedIsolatedPath
} finally {
if ($hadRuntimeConfig) {
[System.IO.File]::WriteAllBytes($runtimeConfigPath, $runtimeConfigBytes)
} else {
Remove-Item -LiteralPath $runtimeConfigPath -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $promptPath -Force -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $promptFolder -PathType Container) {
$remainingPromptFiles = @(Get-ChildItem -LiteralPath $promptFolder -Force -ErrorAction SilentlyContinue)
if ($remainingPromptFiles.Count -eq 0) {
Remove-Item -LiteralPath $promptFolder -Force -ErrorAction SilentlyContinue
}
}
}

$rawText = $execution.Stdout.Trim()
$stderrText = $execution.Stderr.Trim()
$safeStdoutLog = Redact-ReasonixWorkerText -Value $rawText
$safeStderrLog = Redact-ReasonixWorkerText -Value $stderrText
$logEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($stdoutLogPath, $safeStdoutLog, $logEncoding)
[System.IO.File]::WriteAllText($stderrLogPath, $safeStderrLog, $logEncoding)

if ($execution.ExitCode -ne 0) {
$failureEvidence = (($stderrText, $rawText | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine).Trim()
if ($failureEvidence -match '(?i)this session is in use by another Reasonix window or process') {
throw "Reasonix CLI session is locked. Close Reasonix Desktop and any other Reasonix process, then retry the Agent Workbench task."
}
$message = Redact-ReasonixWorkerText -Value $failureEvidence
throw "Reasonix task invocation failed with exit code $($execution.ExitCode): $message"
}

$worktreeResultPath = Join-Path $resolvedIsolatedPath "agent-result.md"
if ([string]::IsNullOrWhiteSpace($rawText) -and (Test-Path -LiteralPath $worktreeResultPath -PathType Leaf)) {
$rawText = Get-Content -LiteralPath $worktreeResultPath -Raw -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($rawText)) {
throw "Reasonix task invocation returned empty output and no worktree agent-result.md."
}

$cleaned = ConvertFrom-ReasonixMarkdownOutput -Value $rawText -RequiredHeading "# Agent Result"
$safeResult = Redact-ReasonixWorkerText -Value $cleaned
$agentResultPath = Join-Path $resolvedTaskFolder "agent-result.md"
$compatResultPath = Join-Path $resolvedTaskFolder "result.md"

Set-Content -LiteralPath $agentResultPath -Value $safeResult -Encoding UTF8
Set-Content -LiteralPath $compatResultPath -Value $safeResult -Encoding UTF8

if (Test-Path -LiteralPath $worktreeResultPath -PathType Leaf) {
Remove-Item -LiteralPath $worktreeResultPath -Force -ErrorAction SilentlyContinue
}

$completedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$modelLabel = if ([string]::IsNullOrWhiteSpace($Model)) { "default" } else { $Model }
$logLine = "[$completedAt] reasonix task invoked isolated_workspace=$(Redact-ReasonixWorkerText -Value $resolvedIsolatedPath) result=agent-result.md metrics=agent-metrics.json reasonix=$(Split-Path -Leaf $resolvedReasonixCommand) model=$modelLabel max_steps=$MaxSteps bash=denied stdout_log=reasonix-stdout.log stderr_log=reasonix-stderr.log"
Add-Content -LiteralPath $runLogPath -Value $logLine -Encoding UTF8

if ($Collect) {
$collectScript = Join-Path $PSScriptRoot "Collect-AgentResult.ps1"
& $collectScript -TaskFolder $resolvedTaskFolder | Out-Null
}

Write-Output $agentResultPath
