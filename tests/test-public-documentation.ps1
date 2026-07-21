$ErrorActionPreference = "Stop"

function Assert {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$readmePath = Join-Path $repoRoot "README.md"
$releasePath = Join-Path $repoRoot ".github\RELEASE_v0.1.0.md"
$releaseZhPath = Join-Path $repoRoot ".github\RELEASE_v0.1.0.zh-CN.md"
$examplesPath = Join-Path $repoRoot "docs\EXAMPLES.md"
$messagingPath = Join-Path $repoRoot "docs\RELEASE_MESSAGING.md"
$publishingPath = Join-Path $repoRoot "docs\PUBLICATION_READINESS.md"
$samplePath = Join-Path $repoRoot "examples\sample-design-note.md"
$authorsPath = Join-Path $repoRoot "AUTHORS.md"
$securityPath = Join-Path $repoRoot "SECURITY.md"

foreach ($path in @($readmePath, $releasePath, $releaseZhPath, $examplesPath, $messagingPath, $publishingPath, $samplePath, $authorsPath, $securityPath)) {
  Assert (Test-Path -LiteralPath $path -PathType Leaf) "Missing public documentation artifact: $path"
}

$readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
$release = Get-Content -LiteralPath $releasePath -Raw -Encoding UTF8
$releaseZh = Get-Content -LiteralPath $releaseZhPath -Raw -Encoding UTF8
$examples = Get-Content -LiteralPath $examplesPath -Raw -Encoding UTF8
$messaging = Get-Content -LiteralPath $messagingPath -Raw -Encoding UTF8
$publishing = Get-Content -LiteralPath $publishingPath -Raw -Encoding UTF8
$authors = Get-Content -LiteralPath $authorsPath -Raw -Encoding UTF8
$security = Get-Content -LiteralPath $securityPath -Raw -Encoding UTF8

Assert (-not $readme.Contains('-Title "Add a bounded validation check"')) "README uses an unsupported New-AgentTask -Title parameter."
Assert ($release.Contains("Public Preview")) "Release draft must identify the release as a public preview."
Assert ($release.Contains("not an operating-system sandbox")) "Release draft must preserve the worktree safety boundary."
Assert ($release.Contains("does not merge")) "Release draft must state the no-auto-merge boundary."
Assert ($release.Contains("A Role Protocol, Not A Fixed Agent Trio")) "English release must present replaceable protocol roles."
Assert ($release.Contains("not supported built-in adapters")) "English release must distinguish extension targets from built-in adapters."
Assert ($release.Contains("Lightweight And Fast To Adopt")) "English release must explain lightweight adoption."
Assert ($release.Contains("One Mechanism, Multiple Collaboration Modes")) "English release must explain interaction coverage."
Assert ($release.Contains("Controllable, Inspectable, Traceable")) "English release must explain operational differentiators."
Assert ($release.Contains("No server, database, message broker")) "English release must ground the lightweight claim in architecture."
$nonAsciiCount = [regex]::Matches($releaseZh, '[^\x00-\x7F]').Count
Assert ($nonAsciiCount -gt 1000) "Chinese release does not contain enough Chinese-language content."
Assert ($releaseZh.Contains("OpenHands")) "Chinese release must discuss extension targets."
Assert ($releaseZh.Contains("adapter")) "Chinese release must preserve adapter boundaries."
Assert ($releaseZh.Contains("Git worktree")) "Chinese release must preserve the worktree boundary."
Assert ($releaseZh.Contains("status.json")) "Chinese release must explain inspectable state."
Assert ($releaseZh.Contains("JSONL")) "Chinese release must ground lightweight state in ordinary files."
Assert ($messaging.Contains("govern multi-agent handoffs in real work")) "Messaging strategy must lead with the governed handoff problem."
Assert ($messaging.Contains("two formal non-interactive adapters")) "Messaging strategy must preserve current adapter boundaries."
Assert ($messaging.Contains("Faster to adopt")) "Messaging strategy must define the speed claim."
Assert ($messaging.Contains("Comparative Framing")) "Messaging strategy must include honest comparative framing."
foreach ($documentContent in @($readme, $release, $releaseZh, $authors)) {
  Assert ($documentContent.Contains("LEVIUS")) "Public identity document is missing the author ID."
  Assert ($documentContent.Contains("agentworkbench@proton.me")) "Public identity document is missing the contact email."
}
Assert ($security.Contains("agentworkbench@proton.me")) "Security policy is missing the fallback contact email."
Assert ($publishing.Contains("Gitleaks")) "Publication readiness must retain the full-history secret-scan gate."
Assert ($publishing.Contains("PowerShell 7")) "Publication readiness must retain the PowerShell 7 CI gate."
Assert ($publishing.Contains("explicit publication approval")) "Publication readiness must preserve the external publication gate."
Assert ($examples.Contains("needs_codex_decision")) "Examples must preserve the final moderator decision gate."
Assert ($examples.Contains("create a fresh discussion")) "Examples must explain frozen snapshot freshness."

$testCount = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "tests") -Filter "test-*.ps1" -File).Count
Assert ($release.Contains("All $testCount repository tests pass locally")) "Release test count does not match the repository suite."
$zhTestLines = @($releaseZh -split '\r?\n' | Where-Object { $_ -match 'Windows PowerShell 5\.1' })
Assert ($zhTestLines.Count -ge 1) "Chinese release does not contain a Windows PowerShell 5.1 verification line."
Assert (($zhTestLines -join "`n").Contains($testCount.ToString())) "Chinese release test count does not match the repository suite."

foreach ($document in @($releasePath, $releaseZhPath, $examplesPath)) {
  $content = Get-Content -LiteralPath $document -Raw -Encoding UTF8
  $blocks = [regex]::Matches($content, '(?ms)```powershell\s*(.*?)\s*```')
  Assert ($blocks.Count -gt 0) "Expected at least one PowerShell example in $document"
  foreach ($block in $blocks) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($block.Groups[1].Value, [ref]$tokens, [ref]$errors) | Out-Null
    Assert ($errors.Count -eq 0) "Invalid PowerShell example in ${document}: $($errors[0].Message)"
  }
}

Write-Output "PASS public documentation contract"
