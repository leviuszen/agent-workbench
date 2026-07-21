param(
  [Parameter(Mandatory = $true)][string]$ClaudeExe,
  [Parameter(Mandatory = $true)][string]$WorkingDirectory,
  [Parameter(Mandatory = $true)][string]$PromptFile,
  [Parameter(Mandatory = $true)][string]$StdoutFile,
  [Parameter(Mandatory = $true)][string]$StderrFile,
  [Parameter(Mandatory = $true)][string]$CompletionFile
)

$ErrorActionPreference = "Stop"

function ConvertTo-ProcessArgument {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Protect-InvocationText {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return "" }
  $safe = $Value -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED_SECRET]'
  $safe = $safe -replace '(?i)\b[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY)\b\s*[:=]\s*\S+', '[REDACTED_SECRET]'
  return $safe
}

$completion = [ordered]@{
  state = "failed"
  exit_code = -1
  started_at = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  completed_at = ""
  error = ""
}

try {
  $prompt = Get-Content -LiteralPath $PromptFile -Raw -Encoding UTF8
  $arguments = @("--bare", "--print", $prompt, "--allowedTools", "Read", "--permission-mode", "dontAsk", "--no-session-persistence")
  $processFile = $ClaudeExe
  $processArguments = [System.Collections.Generic.List[string]]::new()
  if ([System.IO.Path]::GetExtension($ClaudeExe) -match '(?i)^\.ps1$') {
    $processFile = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    foreach ($argument in @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ClaudeExe) + $arguments) {
      $processArguments.Add($argument)
    }
  } elseif ([System.IO.Path]::GetExtension($ClaudeExe) -match '(?i)^\.(cmd|bat)$') {
    $processFile = $env:ComSpec
    $commandLine = ((@($ClaudeExe) + $arguments | ForEach-Object { ConvertTo-ProcessArgument -Value $_ }) -join " ")
    foreach ($argument in @("/d", "/s", "/c", $commandLine)) { $processArguments.Add($argument) }
  } else {
    foreach ($argument in $arguments) { $processArguments.Add($argument) }
  }

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $processFile
  $startInfo.Arguments = (($processArguments | ForEach-Object { ConvertTo-ProcessArgument -Value $_ }) -join " ")
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw "Claude process did not start." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $completion.exit_code = [int]$process.ExitCode
  } finally {
    $process.Dispose()
  }

  [System.IO.File]::WriteAllText($StdoutFile, (Protect-InvocationText -Value $stdout), [System.Text.UTF8Encoding]::new($false))
  [System.IO.File]::WriteAllText($StderrFile, (Protect-InvocationText -Value $stderr), [System.Text.UTF8Encoding]::new($false))
  $completion.state = if ($completion.exit_code -eq 0) { "completed" } else { "failed" }
} catch {
  $completion.error = Protect-InvocationText -Value $_.Exception.Message
} finally {
  $completion.completed_at = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
  $temporaryCompletion = "$CompletionFile.tmp"
  $completion | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryCompletion -Encoding UTF8
  Move-Item -LiteralPath $temporaryCompletion -Destination $CompletionFile -Force
}
