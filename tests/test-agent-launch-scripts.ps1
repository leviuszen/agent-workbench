$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

function Get-ParsedScript {
  param([string]$Path)

  $tokens = $null
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
  Assert ($parseErrors.Count -eq 0) "PowerShell parser errors in $Path`: $($parseErrors -join '; ')"
  return $ast
}

function Get-RedactFunctionText {
  param([string]$Path)

  $ast = Get-ParsedScript -Path $Path
  $functions = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -eq "Redact-LaunchMetadata"
  }, $true)

  Assert ($functions.Count -eq 1) "Expected exactly one Redact-LaunchMetadata function in $Path."
  return $functions[0].Extent.Text
}

function Invoke-RedactFunction {
  param(
    [string]$Path,
    [string]$Value
  )

  $functionText = Get-RedactFunctionText -Path $Path
  $script = @"
$functionText
Redact-LaunchMetadata -Value @'
$Value
'@
"@
  return ([scriptblock]::Create($script).Invoke() | Out-String).Trim()
}

function Assert-MissingTaskFolderRedaction {
  param(
    [string]$Path,
    [string]$MissingPath,
    [hashtable]$ExtraArgs
  )

  $message = $null
  try {
    & $Path -TaskFolder $MissingPath @ExtraArgs | Out-Null
    throw "Expected $Path to fail for missing TaskFolder."
  } catch {
    $message = $_.Exception.Message
  }

  Assert ($message.Contains("[REDACTED_PATH]")) "Missing TaskFolder error must contain [REDACTED_PATH]. Message: $message"
  Assert (-not $message.Contains($MissingPath)) "Missing TaskFolder error leaked raw path."
  Assert ($message -notmatch "sk-secretLikeSlug1234567890") "Missing TaskFolder error leaked secret-like slug."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$providerKeyName = ("ANTHROPIC" + "_API_KEY")
$scripts = @(
@{
    Path = Join-Path $repoRoot "scripts\Start-ClaudeTask.ps1"
    Launcher = "claude-launcher.bat"
    ExtraArgs = @{ ClaudeLauncher = "Z:\missing\claude-launcher.bat" }
  },
  @{
    Path = Join-Path $repoRoot "scripts\Open-ReasonixDiscussion.ps1"
    Launcher = "reasonix-desktop.exe"
    ExtraArgs = @{ ReasonixExe = "Z:\missing\reasonix-desktop.exe" }
  }
)

foreach ($scriptInfo in $scripts) {
  Get-ParsedScript -Path $scriptInfo.Path | Out-Null

  if ($scriptInfo.Path.EndsWith("Open-ReasonixDiscussion.ps1")) {
    $missingDiscussionFolder = Join-Path ([System.IO.Path]::GetTempPath()) "不存在 discussion sk-secretLikeSlug1234567890"
    $message = $null
    try {
      $extraArgs = $scriptInfo.ExtraArgs
      & $scriptInfo.Path -DiscussionFolder $missingDiscussionFolder @extraArgs | Out-Null
      throw "Expected $($scriptInfo.Path) to fail for missing DiscussionFolder."
    } catch {
      $message = $_.Exception.Message
    }

    Assert ($message.Contains("[REDACTED_PATH]")) "Missing DiscussionFolder error must contain [REDACTED_PATH]. Message: $message"
    Assert (-not $message.Contains($missingDiscussionFolder)) "Missing DiscussionFolder error leaked raw path."
    Assert ($message -notmatch "sk-secretLikeSlug1234567890") "Missing DiscussionFolder error leaked secret-like slug."
  } else {
    $missingTaskFolder = Join-Path ([System.IO.Path]::GetTempPath()) "不存在 folder sk-secretLikeSlug1234567890"
    Assert-MissingTaskFolderRedaction -Path $scriptInfo.Path -MissingPath $missingTaskFolder -ExtraArgs $scriptInfo.ExtraArgs
  }

  $unicodeUser = -join @([char]0x6D4B, [char]0x8BD5, " ", [char]0x7528, [char]0x6237)
  $metadata = "task_folder=C:\Users\$unicodeUser\agent tasks\sk-secretLikeSlug1234567890 launcher=$($scriptInfo.Launcher)"
  $redacted = Invoke-RedactFunction -Path $scriptInfo.Path -Value $metadata
  Assert ($redacted.Contains("task_folder=[REDACTED_PATH]")) "Expected task_folder path redaction. Got: $redacted"
  Assert ($redacted.Contains("launcher=$($scriptInfo.Launcher)")) "Path redaction swallowed launcher field. Got: $redacted"
  Assert ($redacted -notmatch "C:\\Users") "Redaction leaked drive path. Got: $redacted"
  Assert ($redacted -notmatch "sk-secretLikeSlug1234567890") "Redaction leaked secret-like slug. Got: $redacted"

  $secretMetadata = "token sk-secretLikeValue1234567890 $providerKeyName=abc123 endpoint api.deepseek.com"
  $secretRedacted = Invoke-RedactFunction -Path $scriptInfo.Path -Value $secretMetadata
  Assert ($secretRedacted -notmatch "sk-") "Redaction leaked sk- secret-like content. Got: $secretRedacted"
  Assert (-not $secretRedacted.Contains($providerKeyName)) "Redaction leaked provider env var name. Got: $secretRedacted"
  Assert ($secretRedacted -notmatch "api\.deepseek") "Redaction leaked DeepSeek endpoint. Got: $secretRedacted"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-reasonix-launch-test-" + [guid]::NewGuid().ToString("N"))
try {
  $discussionFolder = Join-Path $tempRoot "discussion"
  New-Item -ItemType Directory -Force -Path (Join-Path $discussionFolder "round1") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $discussionFolder "round2") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $discussionFolder "references\files") | Out-Null
  Set-Content -LiteralPath (Join-Path $discussionFolder "brief.md") -Encoding UTF8 -Value "# Agent Discussion Brief"
  Set-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Encoding UTF8 -Value "{}"
  Set-Content -LiteralPath (Join-Path $discussionFolder "run.log") -Encoding UTF8 -Value ""
  Set-Content -LiteralPath (Join-Path $discussionFolder "codex-synthesis.md") -Encoding UTF8 -Value "# Codex Synthesis"
  Set-Content -LiteralPath (Join-Path $discussionFolder "references\manifest.md") -Encoding UTF8 -Value "# Agent Discussion Reference Manifest`n- snapshot_semantics: frozen_copy"

  $reasonixScript = Join-Path $repoRoot "scripts\Open-ReasonixDiscussion.ps1"
  & $reasonixScript -DiscussionFolder $discussionFolder -Round 2 -AgentName "reasonix" -PrepareOnly | Out-Null

  $instructionsPath = Join-Path $discussionFolder "round2\reasonix-instructions.md"
  Assert (Test-Path -LiteralPath $instructionsPath -PathType Leaf) "Reasonix instructions should be written in the round folder."
  $instructions = Get-Content -LiteralPath $instructionsPath -Raw -Encoding UTF8
  Assert ($instructions.Contains("round2/reasonix.md")) "Reasonix instructions should name the expected feedback file."
  Assert ($instructions.Contains("codex-synthesis.md")) "Round 2 Reasonix instructions should require codex-synthesis.md."
  Assert ($instructions.Contains("references/manifest.md")) "Reasonix instructions should include reference manifest guidance."
  Assert ($instructions.Contains("frozen snapshots")) "Reasonix instructions should preserve frozen snapshot semantics."
  Assert ($instructions.Contains("second independent reviewer")) "Reasonix instructions should define the second-reviewer role."

  $runLog = Get-Content -LiteralPath (Join-Path $discussionFolder "run.log") -Raw -Encoding UTF8
  Assert ($runLog.Contains("prepared agent=reasonix round=2")) "Reasonix PrepareOnly should be logged."
  Assert ($runLog.Contains("target=round2/reasonix.md")) "Reasonix run.log should record the expected feedback target."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
