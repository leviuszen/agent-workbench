$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
if (-not $Condition) {
throw $Message
}
}

function Invoke-Git {
param(
[string]$WorkingDirectory,
[string[]]$Arguments
)

$output = & git -C $WorkingDirectory @Arguments 2>&1
if ($LASTEXITCODE -ne 0) {
throw "git $($Arguments -join ' ') failed: $output"
}

return $output
}

function Assert-NoSecretLikeContent {
param(
[string]$Content,
[string]$Name
)

Assert ($Content -notmatch "sk-") "$Name contains sk- secret-like content."
Assert (-not $Content.Contains("ANTHROPIC_API_KEY")) "$Name contains provider env var name."
Assert (-not $Content.Contains("OPENAI_API_KEY")) "$Name contains OpenAI provider env var name."
Assert ($Content -notmatch "api\.deepseek") "$Name contains api.deepseek secret-like content."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$newTaskScript = Join-Path $repoRoot "scripts\New-AgentTask.ps1"
$newWorktreeScript = Join-Path $repoRoot "scripts\New-AgentWorktree.ps1"
$collectScript = Join-Path $repoRoot "scripts\Collect-AgentResult.ps1"
$invokeReasonixScript = Join-Path $repoRoot "scripts\Invoke-ReasonixTask.ps1"
$invokeAgentScript = Join-Path $repoRoot "scripts\Invoke-AgentTask.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-reasonix-runner-" + [guid]::NewGuid().ToString("N"))
$sourceRepo = Join-Path $tempRoot "source-repo"
$workbenchRoot = Join-Path $tempRoot "workbench"
$fakeReasonix = Join-Path $tempRoot "fake-reasonix.ps1"
$fakeLockedReasonix = Join-Path $tempRoot "fake-reasonix-locked.ps1"
$worktreePath = $null

try {
New-Item -ItemType Directory -Force -Path $sourceRepo, $workbenchRoot | Out-Null
Assert (Test-Path -LiteralPath $invokeReasonixScript -PathType Leaf) "Invoke-ReasonixTask.ps1 does not exist."
Assert (Test-Path -LiteralPath $invokeAgentScript -PathType Leaf) "Invoke-AgentTask.ps1 does not exist."

& git -C $sourceRepo init | Out-Null
if ($LASTEXITCODE -ne 0) {
throw "git init failed."
}

Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.name", "Reasonix Task Test") | Out-Null
Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("config", "user.email", "reasonix-task-test@example.invalid") | Out-Null
Set-Content -LiteralPath (Join-Path $sourceRepo "README.md") -Value "# Source Repo" -Encoding UTF8
Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("add", "README.md") | Out-Null
Invoke-Git -WorkingDirectory $sourceRepo -Arguments @("commit", "-m", "initial commit") | Out-Null

Set-Content -LiteralPath $fakeReasonix -Encoding UTF8 -Value @'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$CliArguments = @($args)
$TaskInput = [Console]::In.ReadToEnd()

$metrics = $null
for ($index = 0; $index -lt $CliArguments.Count; $index += 1) {
if ($CliArguments[$index] -eq "--metrics" -and ($index + 1) -lt $CliArguments.Count) {
$metrics = $CliArguments[$index + 1]
}
}

Set-Content -LiteralPath "reasonix-worker-output.txt" -Value "fake reasonix changed isolated worktree" -Encoding UTF8
Get-Content -LiteralPath "reasonix.toml" -Raw -Encoding UTF8 | Set-Content -LiteralPath "reasonix-config-capture.txt" -Encoding UTF8
if (-not [string]::IsNullOrWhiteSpace($metrics)) {
Set-Content -LiteralPath $metrics -Value '{"ok":true,"worker":"reasonix"}' -Encoding UTF8
}

$escape = [char]27
Write-Output ($escape + "[2m | thinking" + $escape + "[0m")
Write-Output "-> bash { fake tool trace }"
Write-Output '```text'
Write-Output 'preamble code block that is not the final report'
Write-Output '```'
Write-Output "# Agent Result"
Write-Output ""
Write-Output "## Files Changed"
Write-Output ""
Write-Output "- reasonix-worker-output.txt"
Write-Output ""
Write-Output "## Implementation Summary"
Write-Output ""
Write-Output "Wrote a test file inside the isolated worktree."
Write-Output ""
Write-Output "## Tests Run"
Write-Output ""
Write-Output "- fake reasonix smoke test"
Write-Output ""
Write-Output "## Tests Not Run"
Write-Output ""
Write-Output "- full suite"
Write-Output ""
Write-Output "## Risks And Open Questions"
Write-Output ""
Write-Output "Do not leak sk-resultSecret1234567890 or ANTHROPIC_API_KEY=abc123."
Write-Output ""
Write-Output "## Isolation Check"
Write-Output ""
Write-Output "Stayed inside the isolated worktree."
Write-Output ([char]0x00B7 + " 12000 tok | in 11900 | out 100 | cost")
exit 0
'@

Set-Content -LiteralPath $fakeLockedReasonix -Encoding UTF8 -Value @'
$ErrorActionPreference = "Continue"
Write-Error "error: this session is in use by another Reasonix window or process; close the other Reasonix window or process first"
exit 1
'@

$taskFolder = & $newTaskScript `
-WorkbenchRoot $workbenchRoot `
-Slug "reasonix-runner" `
-TargetAgent reasonix `
-Mode implementation `
-WorkspaceRoot $sourceRepo `
-Task "Create a small isolated worktree change." `
-Context "Use fake Reasonix and do not leak sk-contextSecret1234567890 or OPENAI_API_KEY=abc123."

$taskFolder = ($taskFolder | Select-Object -Last 1).Trim()
Assert (Test-Path -LiteralPath $taskFolder -PathType Container) "Task folder was not created."

$missingWorktreeFailed = $false
try {
& $invokeReasonixScript `
-TaskFolder $taskFolder `
-ReasonixCommand $fakeReasonix | Out-Null
} catch {
$missingWorktreeFailed = ($_.Exception.Message -match "isolated_workspace")
}
Assert $missingWorktreeFailed "Runner should fail clearly before an isolated worktree exists."

$worktreePath = & $newWorktreeScript `
-WorkbenchRoot $workbenchRoot `
-TaskFolder $taskFolder `
-WorkspaceRoot $sourceRepo `
-Slug "reasonix-runner"

$worktreePath = ($worktreePath | Select-Object -Last 1).Trim()
Assert (Test-Path -LiteralPath $worktreePath -PathType Container) "Isolated worktree was not created."

$originalReasonixConfig = "# original project config`ndefault_model = `"project-default`"`n"
[System.IO.File]::WriteAllText(
(Join-Path $worktreePath "reasonix.toml"),
$originalReasonixConfig,
[System.Text.UTF8Encoding]::new($false)
)

$desktopGuardFailed = $false
$currentPowerShellProcessName = [System.Diagnostics.Process]::GetCurrentProcess().ProcessName
try {
& $invokeReasonixScript `
-TaskFolder $taskFolder `
-ReasonixCommand $fakeReasonix `
-ReasonixDesktopProcessName $currentPowerShellProcessName | Out-Null
} catch {
$desktopGuardFailed = ($_.Exception.Message -match "Reasonix Desktop is running") -and ($_.Exception.Message -match "Close Reasonix Desktop")
}
Assert $desktopGuardFailed "Runner should stop with an actionable message when Reasonix Desktop is running."

$lockFailureWasClear = $false
try {
& $invokeReasonixScript `
-TaskFolder $taskFolder `
-ReasonixCommand $fakeLockedReasonix `
-ReasonixDesktopProcessName "reasonix-desktop-test-not-running" | Out-Null
} catch {
$lockFailureWasClear = ($_.Exception.Message -match "Reasonix CLI session is locked") -and ($_.Exception.Message -match "Close Reasonix Desktop")
}
Assert $lockFailureWasClear "Runner should translate the Reasonix session-lock error into an actionable message."

& $invokeAgentScript `
-TaskFolder $taskFolder `
-Agent reasonix `
-ReasonixCommand $fakeReasonix `
-ReasonixMaxSteps 7 `
-Collect | Out-Null

$agentResultPath = Join-Path $taskFolder "agent-result.md"
$compatResultPath = Join-Path $taskFolder "result.md"
$metricsPath = Join-Path $taskFolder "agent-metrics.json"
Assert (Test-Path -LiteralPath $agentResultPath -PathType Leaf) "agent-result.md was not created."
Assert (Test-Path -LiteralPath $compatResultPath -PathType Leaf) "result.md compatibility copy was not created."
Assert (Test-Path -LiteralPath $metricsPath -PathType Leaf) "agent-metrics.json was not created."

$agentResult = Get-Content -LiteralPath $agentResultPath -Raw -Encoding UTF8
Assert ($agentResult.TrimStart().StartsWith("# Agent Result")) "agent-result.md should start with # Agent Result."
Assert ($agentResult.Contains("## Files Changed")) "agent-result.md missing Files Changed section."
Assert ($agentResult.Contains("## Isolation Check")) "agent-result.md missing Isolation Check section."
Assert ($agentResult -notmatch [regex]::Escape([string][char]27)) "agent-result.md contains ANSI escape sequences."
Assert (-not $agentResult.Contains("thinking")) "agent-result.md contains Reasonix thinking status."
Assert (-not $agentResult.Contains("-> bash")) "agent-result.md contains Reasonix tool trace."
Assert ($agentResult -notmatch "\d+\s+tok") "agent-result.md contains Reasonix token/cost status."
Assert-NoSecretLikeContent -Content $agentResult -Name "agent-result.md"

$capturedConfig = Get-Content -LiteralPath (Join-Path $worktreePath "reasonix-config-capture.txt") -Raw -Encoding UTF8
Assert ($capturedConfig.Contains('deny = ["Bash(*)"]')) "Runtime Reasonix config should deny all Bash calls on Windows."
Assert ($capturedConfig.Contains("workspace_root")) "Runtime Reasonix config should set workspace_root."
Assert (-not $capturedConfig.Contains('bash = "off"')) "Runtime Reasonix config must not present unconfined Bash as a safety control."
$restoredConfig = Get-Content -LiteralPath (Join-Path $worktreePath "reasonix.toml") -Raw -Encoding UTF8
Assert ($restoredConfig -eq $originalReasonixConfig) "Original reasonix.toml should be restored after the worker exits."

$stdoutLogPath = Join-Path $taskFolder "reasonix-stdout.log"
$stderrLogPath = Join-Path $taskFolder "reasonix-stderr.log"
Assert (Test-Path -LiteralPath $stdoutLogPath -PathType Leaf) "Reasonix stdout log was not created."
Assert (Test-Path -LiteralPath $stderrLogPath -PathType Leaf) "Reasonix stderr log was not created."
Assert ((Get-Item -LiteralPath $stderrLogPath).Length -eq 0) "Successful Reasonix run should leave a truly empty stderr log."
$stdoutLog = Get-Content -LiteralPath $stdoutLogPath -Raw -Encoding UTF8
Assert ($stdoutLog.Contains("thinking")) "Reasonix stdout log should preserve redacted execution evidence."

Assert (Test-Path -LiteralPath (Join-Path $worktreePath "reasonix-worker-output.txt") -PathType Leaf) "Fake Reasonix did not write inside isolated worktree."
Assert (-not (Test-Path -LiteralPath (Join-Path $sourceRepo "reasonix-worker-output.txt"))) "Source workspace was modified directly."
Assert (-not (Test-Path -LiteralPath (Join-Path $worktreePath ".agent-workbench"))) "Transient Reasonix prompt folder should be removed."

$worktreeDiff = Invoke-Git -WorkingDirectory $worktreePath -Arguments @("status", "--short")
Assert (($worktreeDiff -join "`n") -match "reasonix-worker-output\.txt") "Isolated worktree diff does not include fake Reasonix output."

$collectionOutput = (& $collectScript -TaskFolder $taskFolder) -join [Environment]::NewLine
Assert ($collectionOutput.Contains("agent-result.md: present")) "Collector should report agent-result.md status."
Assert ($collectionOutput.Contains("agent-metrics.json: present")) "Collector should report agent-metrics.json status."
Assert ($collectionOutput.Contains("## agent-result.md")) "Collector should print agent-result.md content."
Assert ($collectionOutput.Contains("## Isolated Worktree Diff")) "Collector should include an isolated worktree diff review section."
Assert ($collectionOutput.Contains("reasonix-worker-output.txt")) "Collector should include changed worktree file names."
Assert-NoSecretLikeContent -Content $collectionOutput -Name "collection output"

$runLog = Get-Content -LiteralPath (Join-Path $taskFolder "run.log") -Raw -Encoding UTF8
Assert ($runLog.Contains("reasonix task invoked")) "run.log should include a reasonix task invocation entry."
Assert ($runLog.Contains("max_steps=7")) "run.log should include the Reasonix max step limit."
Assert-NoSecretLikeContent -Content $runLog -Name "run.log"
} finally {
if ($worktreePath -and (Test-Path -LiteralPath $worktreePath -PathType Container) -and (Test-Path -LiteralPath $sourceRepo -PathType Container)) {
& git -C $sourceRepo worktree remove $worktreePath --force 2>$null
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
