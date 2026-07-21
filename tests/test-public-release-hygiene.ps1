$ErrorActionPreference = "Stop"

function Assert {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$requiredFiles = @(
  "README.md",
  "LICENSE",
  "CONTRIBUTING.md",
  "SECURITY.md",
  "CHANGELOG.md",
  "BUG_LOG.md",
  "AUTHORS.md",
  ".gitignore",
  ".github\workflows\ci.yml"
)

foreach ($relativePath in $requiredFiles) {
  Assert (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath) -PathType Leaf) "Missing public release file: $relativePath"
}

$scanRoots = @(
  (Join-Path $repoRoot "scripts"),
  (Join-Path $repoRoot "skills"),
  (Join-Path $repoRoot "docs"),
  (Join-Path $repoRoot "examples"),
  (Join-Path $repoRoot ".github"),
  (Join-Path $repoRoot "README.md"),
  (Join-Path $repoRoot "CONTRIBUTING.md"),
  (Join-Path $repoRoot "SECURITY.md"),
  (Join-Path $repoRoot "CHANGELOG.md"),
  (Join-Path $repoRoot "AUTHORS.md")
)

$forbiddenPatterns = @(
  ("J:" + "\Codex\workspaces"),
  ("G:" + "\github-repos"),
  ("C:" + "\Users\"),
  ("D:" + "\Users\"),
  ("Q" + "Claw")
)

$files = foreach ($scanRoot in $scanRoots) {
  if (Test-Path -LiteralPath $scanRoot -PathType Container) {
    Get-ChildItem -LiteralPath $scanRoot -Recurse -File
  } elseif (Test-Path -LiteralPath $scanRoot -PathType Leaf) {
    Get-Item -LiteralPath $scanRoot
  }
}

foreach ($file in $files) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  foreach ($pattern in $forbiddenPatterns) {
    Assert (-not $content.Contains($pattern)) "Forbidden private-path marker in $($file.FullName)"
  }
}

$allowedPublicEmails = @(
"agentworkbench@proton.me",
"leviuszen@users.noreply.github.com"
)
$emailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
$allPublicFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force |
  Where-Object { $_.FullName -notlike "$repoRoot\.git\*" }
foreach ($file in $allPublicFiles) {
$content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
foreach ($match in [regex]::Matches($content, $emailPattern)) {
    $address = $match.Value
    $isSynthetic = $address.EndsWith("@example.invalid", [System.StringComparison]::OrdinalIgnoreCase)
    $isApproved = $address -in $allowedPublicEmails
    Assert ($isSynthetic -or $isApproved) "Unapproved public email in $($file.FullName)"
}
}

$historyOutput = & git -C $repoRoot log --all --format=fuller -p --no-color 2>&1
Assert ($LASTEXITCODE -eq 0) "Unable to inspect complete Git history."
$historyContent = [string]::Join([Environment]::NewLine, @($historyOutput))
$allowedHistoryEmails = @(
"agentworkbench@proton.me",
"leviuszen@users.noreply.github.com"
)
$unexpectedHistoryEmailCount = 0
foreach ($match in [regex]::Matches($historyContent, $emailPattern)) {
$address = $match.Value
$isSynthetic = $address.EndsWith("@example.invalid", [System.StringComparison]::OrdinalIgnoreCase)
$isApproved = $address -in $allowedHistoryEmails
if (-not ($isSynthetic -or $isApproved)) {
$unexpectedHistoryEmailCount += 1
}
}
Assert ($unexpectedHistoryEmailCount -eq 0) "Git history contains unexpected email address occurrences. Run the local privacy audit before publishing."

$forbiddenHistoryMarkers = @(
  ("J:" + "\Codex\workspaces"),
  ("G:" + "\github-repos"),
  ("D:" + "\Users\"),
  ("Q" + "Claw")
)
foreach ($marker in $forbiddenHistoryMarkers) {
  Assert (-not $historyContent.Contains($marker)) "Git history contains a forbidden private marker."
}

$allowedSyntheticUserSegments = @("Alice", '$unicodeUser')
$unexpectedUserPathCount = 0
foreach ($match in [regex]::Matches($historyContent, 'C:\\Users\\([^\\\s"]+)')) {
  if ($match.Groups[1].Value -notin $allowedSyntheticUserSegments) {
    $unexpectedUserPathCount += 1
  }
}
Assert ($unexpectedUserPathCount -eq 0) "Git history contains unexpected Windows user-profile path occurrences."

$installer = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\Install-AgentWorkbench.ps1") -Raw -Encoding UTF8
Assert ($installer.Contains("AGENT_WORKBENCH_HOME")) "Installer must support AGENT_WORKBENCH_HOME."

$hardCodedWindowsPowerShellHost = 'Join-Path $PSHOME "powershell.exe"'
foreach ($scriptFile in Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts") -Filter "*.ps1" -File) {
  $scriptSource = Get-Content -LiteralPath $scriptFile.FullName -Raw -Encoding UTF8
  Assert (-not $scriptSource.Contains($hardCodedWindowsPowerShellHost)) "Script hard-codes the Windows PowerShell host: $($scriptFile.Name)"
}

$legacyRootExpression = 'Join-Path $PSScriptRoot "..' + '\.."'
$siblingScriptsMarker = 'agent-workbench' + '\scripts'
$thisTest = $MyInvocation.MyCommand.Path
foreach ($testFile in Get-ChildItem -LiteralPath (Join-Path $repoRoot "tests") -Filter "test-*.ps1" -File) {
  if ($testFile.FullName -eq $thisTest) {
    continue
  }
  $testSource = Get-Content -LiteralPath $testFile.FullName -Raw -Encoding UTF8
  Assert (-not $testSource.Contains($legacyRootExpression)) "Test escapes the public repository root: $($testFile.Name)"
  Assert (-not $testSource.Contains($siblingScriptsMarker)) "Test targets a sibling Agent Workbench runtime: $($testFile.Name)"
}

Write-Output "PASS public release hygiene"
