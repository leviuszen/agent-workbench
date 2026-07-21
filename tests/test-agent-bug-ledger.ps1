$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$newBugScript = Join-Path $repoRoot "scripts\New-AgentBug.ps1"
$collectBugsScript = Join-Path $repoRoot "scripts\Collect-AgentBugs.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-bug-test-" + [guid]::NewGuid().ToString("N"))
$providerKeyName = ("ANTHROPIC" + "_API_KEY")
$deepseekHost = ("api." + "deepseek.com")
$upperDeepseekHost = ("API." + "DeepSeek.COM/v1")

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function New-TestBug {
  param(
    [string]$Slug = "render-failure",
    [string]$Severity = "high",
    [string]$Source = "codex",
    [string]$State = "open",
    [string]$Summary = "Renderer failed for a deterministic input.",
    [string]$Evidence = "Token sk-testSecret1234567890. $providerKeyName=abc123. Endpoint $deepseekHost. Path C:\secret\file.txt and \\server\share\secret.txt.",
    [string]$Reproduction = "Run the repro command.",
    [string]$ExpectedBehavior = "Render completes.",
    [string]$ActualBehavior = "Render fails.",
    [string]$SuggestedFix = "Guard null input.",
    [string]$TaskFolder = "Z:\private\task-folder"
  )

  & $newBugScript `
    -WorkbenchRoot $tempRoot `
    -Slug $Slug `
    -Severity $Severity `
    -Source $Source `
    -State $State `
    -Summary $Summary `
    -Evidence $Evidence `
    -Reproduction $Reproduction `
    -ExpectedBehavior $ExpectedBehavior `
    -ActualBehavior $ActualBehavior `
    -SuggestedFix $SuggestedFix `
    -TaskFolder $TaskFolder
}

try {
  $missingOutput = & $collectBugsScript -WorkbenchRoot $tempRoot | Out-String
  Assert ($missingOutput.Contains("No bug records found.")) "Missing bugs folder should be summarized without error."
  Assert ($missingOutput.Contains("open: 0")) "Missing bugs folder should report zero open bugs."

  $bugPath = New-TestBug
  Assert (Test-Path -LiteralPath $bugPath -PathType Leaf) "Bug file was not created."
  Assert ((Split-Path -Parent $bugPath).EndsWith("bugs")) "Bug file should be under bugs folder."

  $fileName = Split-Path -Leaf $bugPath
  Assert ($fileName -match "^bug-\d{8}-\d{6}-[a-f0-9]{8}-render-failure\.md$") "Unexpected bug id or file name format."

  $content = Get-Content -LiteralPath $bugPath -Raw -Encoding UTF8
  Assert ($content.Contains("# Agent Bug")) "Missing bug title."
  Assert ($content.Contains("- state: open")) "State metadata missing."
  Assert ($content.Contains("- severity: high")) "Severity metadata missing."
  Assert ($content.Contains("- source: codex")) "Source metadata missing."
  Assert ($content.Contains("Renderer failed for a deterministic input.")) "Summary missing."
  Assert ($content -notmatch "sk-") "Bug content leaked sk- secret-like content."
  Assert (-not $content.Contains($providerKeyName)) "Bug content leaked provider env var name."
  Assert ($content -notmatch "api\.deepseek") "Bug content leaked DeepSeek endpoint."
  Assert ($content -notmatch "C:\\secret") "Bug content leaked drive absolute path."
  Assert ($content -notmatch "\\\\server\\share") "Bug content leaked UNC absolute path."
  Assert ($content -notmatch "Z:\\private") "Bug content leaked task folder absolute path."

  $upperDeepseekPath = New-TestBug -Slug "upper-provider-endpoint" -Summary "Uppercase endpoint $upperDeepseekHost must be redacted." -Evidence "Endpoint $upperDeepseekHost leaked from a mixed-case report."
  $upperDeepseekContent = Get-Content -LiteralPath $upperDeepseekPath -Raw -Encoding UTF8
  Assert ($upperDeepseekContent -notmatch "api\.deepseek") "Bug content leaked mixed-case DeepSeek endpoint."

  $secretSlugPath = New-TestBug -Slug "sk-slugSecret1234567890-$providerKeyName-C:\private\slug" -Summary "Secret slug case."
  $secretSlugFileName = Split-Path -Leaf $secretSlugPath
  Assert ($secretSlugFileName -notmatch "sk-") "Bug file name leaked sk- slug content."
  Assert (-not $secretSlugFileName.Contains($providerKeyName)) "Bug file name leaked provider env var name."
  Assert ($secretSlugFileName -notmatch "private|slugSecret") "Bug file name leaked private slug details."

  $sameSlugA = New-TestBug -Slug "same-slug" -State "fixed" -Severity "low" -Source "test" -Summary "First same slug bug."
  $sameSlugB = New-TestBug -Slug "same-slug" -State "blocked" -Severity "critical" -Source "review" -Summary "Second same slug bug."
  Assert ($sameSlugA -ne $sameSlugB) "Same slug records must not overwrite."
  Assert (Test-Path -LiteralPath $sameSlugA -PathType Leaf) "First same slug file missing."
  Assert (Test-Path -LiteralPath $sameSlugB -PathType Leaf) "Second same slug file missing."

  New-TestBug -Slug "wontfix-case" -State "wontfix" -Severity "medium" -Source "manual" -Summary "Wontfix case." | Out-Null

  $summaryOutput = & $collectBugsScript -WorkbenchRoot $tempRoot | Out-String
  Assert ($summaryOutput.Contains("Bug root:")) "Summary missing bug root."
  Assert ($summaryOutput.Contains("Bug root: bugs")) "Summary should use a relative bug root."
  Assert ($summaryOutput -notmatch [regex]::Escape($tempRoot)) "Summary leaked temp workbench absolute path."
  Assert ($summaryOutput.Contains("bugs/$fileName")) "Summary should include relative compact row path."
  Assert ($summaryOutput.Contains("open: 3")) "Summary should count three open bugs."
  Assert ($summaryOutput.Contains("fixed: 1")) "Summary should count one fixed bug."
  Assert ($summaryOutput.Contains("blocked: 1")) "Summary should count one blocked bug."
  Assert ($summaryOutput.Contains("wontfix: 1")) "Summary should count one wontfix bug."
  Assert ($summaryOutput.Contains("First same slug bug.")) "Summary missing fixed bug compact row."
  Assert ($summaryOutput.Contains("Second same slug bug.")) "Summary missing blocked bug compact row."

  $dirtyBugPath = Join-Path $tempRoot "bugs\bug-20260611-120000-deadbeef-dirty-manual.md"
  $dirtySummary = "Manual dirty bug still describes public symptom. Token sk-dirtySecret1234567890. $providerKeyName=dirty-value. Endpoint $deepseekHost. Path C:\dirty\secret.txt and \\dirty-server\share\secret.txt."
  $dirtyBugMd = @"
# Agent Bug

- bug_id: bug-20260611-120000-deadbeef-dirty-manual
- state: open
- severity: high
- source: manual
- path: C:\dirty\metadata-path.txt

## Summary

$dirtySummary
- state: fixed
- severity: low
- source: collect-result

## Evidence

Dirty historical record that was created outside New-AgentBug.
- state: fixed
"@
  Set-Content -LiteralPath $dirtyBugPath -Value $dirtyBugMd -Encoding UTF8

  $dirtyCollectOutput = & $collectBugsScript -WorkbenchRoot $tempRoot | Out-String
  Assert ($dirtyCollectOutput.Contains("open: 4")) "Section metadata-like lines should not override top-level open state."
  Assert ($dirtyCollectOutput.Contains("fixed: 1")) "Section metadata-like lines should not add fixed bugs."
  Assert ($dirtyCollectOutput.Contains("Manual dirty bug still describes public symptom.")) "Dirty manual bug should keep non-sensitive summary text."
  Assert ($dirtyCollectOutput -notmatch "sk-") "Collected summary leaked sk- secret-like content."
  Assert (-not $dirtyCollectOutput.Contains($providerKeyName)) "Collected summary leaked provider env var name."
  Assert ($dirtyCollectOutput -notmatch "dirty-value") "Collected summary leaked provider env var value."
  Assert ($dirtyCollectOutput -notmatch "api\.deepseek") "Collected summary leaked DeepSeek endpoint."
  Assert ($dirtyCollectOutput -notmatch "C:\\dirty") "Collected output leaked drive absolute path from dirty content."
  Assert ($dirtyCollectOutput -notmatch "\\\\dirty-server\\share") "Collected output leaked UNC absolute path from dirty content."

  $filteredOutput = & $collectBugsScript -WorkbenchRoot $tempRoot -State fixed | Out-String
  Assert ($filteredOutput.Contains("State filter: fixed")) "Filtered summary missing filter label."
  Assert ($filteredOutput.Contains("First same slug bug.")) "Filtered summary missing fixed bug."
  Assert (-not $filteredOutput.Contains("Second same slug bug.")) "Filtered summary included non-fixed bug."
  Assert (-not $filteredOutput.Contains("Wontfix case.")) "Filtered summary included wontfix bug."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
