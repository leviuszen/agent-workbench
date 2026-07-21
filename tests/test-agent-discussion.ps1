$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

function New-UnicodeText {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\New-AgentDiscussion.ps1"
$collectScriptPath = Join-Path $repoRoot "scripts\Collect-AgentDiscussion.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-discussion-test-" + [guid]::NewGuid().ToString("N"))
$openAiKeyName = ("OPENAI" + "_API_KEY")
$deepseekKeyName = ("DEEPSEEK" + "_API_KEY")
$xAiKeyName = ("XAI" + "_API_KEY")
$unicodeDisagreementA = New-UnicodeText -CodePoints @(0x5206, 0x6b67)
$unicodeDisagreementB = New-UnicodeText -CodePoints @(0x4e0d, 0x540c, 0x610f)
$unicodeDisagreementC = New-UnicodeText -CodePoints @(0x4e89, 0x8bae)
$unicodeBlockerA = New-UnicodeText -CodePoints @(0x65e0, 0x6cd5, 0x7ee7, 0x7eed)
$unicodeBlockerB = New-UnicodeText -CodePoints @(0x963b, 0x585e)
$unicodeRiskA = New-UnicodeText -CodePoints @(0x9ad8, 0x98ce, 0x9669)
$unicodeRiskB = New-UnicodeText -CodePoints @(0x91cd, 0x5927, 0x98ce, 0x9669)
$articleOverallHeading = "## " + (New-UnicodeText -CodePoints @(0x603b, 0x4f53, 0x5224, 0x65ad))
$articleValueHeading = "## " + (New-UnicodeText -CodePoints @(0x6700, 0x6709, 0x4ef7, 0x503c, 0x89c2, 0x70b9))
$articleDisagreementHeading = "## " + (New-UnicodeText -CodePoints @(0x9700, 0x8981)) + " Codex " + (New-UnicodeText -CodePoints @(0x5224, 0x65ad, 0x7684, 0x5206, 0x6b67))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function New-TestDiscussion {
  param(
    [int]$MaxRounds = 2,
    [string[]]$Agents = @("claude-code", "reasonix"),
    [string]$Mode = "general",
    [string]$Protocol = "feedback",
    [string]$ExpectedOutputFormat = "",
    [string[]]$ExpectedSections = @(),
    [string[]]$ReferencePaths = @(),
    [string]$AuditProfile = "standard",
    [hashtable]$ReviewerLenses = @{}
  )

  $arguments = @{
    WorkbenchRoot = $tempRoot
    Slug = "Strategy Review: sk-slugSecret1234567890"
    Topic = "Discussion setup with sk-topicSecret1234567890"
    Question = "Should this redact $openAiKeyName and api.deepseek.com before writing files?"
    Context = "Context has $deepseekKeyName=abc123, $xAiKeyName=xai123, local path C:\Users\Alice\secret.txt, and sk-contextSecret1234567890."
    MaxRounds = $MaxRounds
    Mode = $Mode
    Protocol = $Protocol
    Agents = $Agents
  }

  if (-not [string]::IsNullOrWhiteSpace($ExpectedOutputFormat)) {
    $arguments.ExpectedOutputFormat = $ExpectedOutputFormat
  }
  if ($ExpectedSections.Count -gt 0) {
    $arguments.ExpectedSections = $ExpectedSections
  }
  if ($ReferencePaths.Count -gt 0) {
    $arguments.ReferencePaths = $ReferencePaths
  }
  if ($AuditProfile -ne "standard") {
    $arguments.AuditProfile = $AuditProfile
  }
  if ($ReviewerLenses.Count -gt 0) {
    $arguments.ReviewerLenses = $ReviewerLenses
  }

  & $scriptPath @arguments
}

function Assert-FileExists {
  param(
    [string]$Folder,
    [string]$Name
  )

  Assert (Test-Path -LiteralPath (Join-Path $Folder $Name)) "Missing $Name."
}

function Assert-NoSecretLikeContent {
  param(
    [string]$Content,
    [string]$Name
  )

  Assert ($Content -notmatch "sk-") "$Name contains sk- secret-like content."
  Assert (-not $Content.Contains($openAiKeyName)) "$Name contains provider env var name."
  Assert (-not $Content.Contains($deepseekKeyName)) "$Name contains DeepSeek env var name."
  Assert (-not $Content.Contains($xAiKeyName)) "$Name contains XAI env var name."
  Assert ($Content -notmatch "api\.deepseek") "$Name contains api.deepseek secret-like content."
  Assert ($Content -notmatch "C:\\Users\\Alice\\secret\.txt") "$Name contains local absolute path."
}

function Assert-SafeExpectedOutputs {
  param([object[]]$ExpectedOutputs)

  foreach ($output in $ExpectedOutputs) {
    if ($output -in @("codex-synthesis.md", "decision.md")) {
      continue
    }

    Assert ($output -match "^round[12]/[a-z0-9_-]+\.md$") "Unsafe expected output format: $output"
    Assert ($output -notmatch "\.\.") "Expected output contains path traversal: $output"
    Assert ($output -notmatch "\\") "Expected output contains backslash: $output"
    Assert ($output -notmatch "^[A-Za-z]:") "Expected output contains absolute drive path: $output"
    Assert ($output -notmatch "^/") "Expected output contains absolute POSIX path: $output"
  }
}

try {
  $collectScriptSource = Get-Content -LiteralPath $collectScriptPath -Raw -Encoding UTF8
  foreach ($sourceForbiddenSignal in @(
    $unicodeDisagreementA,
    $unicodeDisagreementB,
    $unicodeDisagreementC,
    $unicodeBlockerA,
    $unicodeBlockerB,
    $unicodeRiskA,
    $unicodeRiskB
  )) {
    Assert (-not $collectScriptSource.Contains($sourceForbiddenSignal)) "Collect script should use ASCII-only Unicode regex escapes for non-ASCII signal: $sourceForbiddenSignal"
  }

  $discussionFolder = New-TestDiscussion
  Assert (Test-Path -LiteralPath $discussionFolder -PathType Container) "Discussion folder does not exist."
  Assert ((Split-Path -Parent $discussionFolder) -eq (Join-Path $tempRoot "discussions")) "Discussion folder must be under WorkbenchRoot\discussions."
  Assert ((Split-Path -Leaf $discussionFolder) -notmatch "sk-") "Discussion folder name contains sk- from slug."

  Assert (Test-Path -LiteralPath (Join-Path $discussionFolder "round1") -PathType Container) "Missing round1 folder."
  Assert (Test-Path -LiteralPath (Join-Path $discussionFolder "round2") -PathType Container) "Missing round2 folder."

  foreach ($name in @("brief.md", "status.json", "run.log", "codex-synthesis.md", "user-decision-needed.md", "decision.md")) {
    Assert-FileExists -Folder $discussionFolder -Name $name
  }

  $statusJson = Get-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Raw -Encoding UTF8
  $status = $statusJson | ConvertFrom-Json
  Assert ($status.state -eq "created") "Unexpected status state."
  Assert ($status.max_rounds -eq 2) "Unexpected max_rounds."
  Assert ($status.current_round -eq 1) "Unexpected current_round."
  Assert ($status.agents -contains "claude-code") "Missing claude-code in agents."
  Assert ($status.agents -contains "reasonix") "Missing reasonix in agents."
  Assert ($status.expected_outputs -contains "round1/claude-code.md") "Missing claude-code round1 output."
  Assert ($status.expected_outputs -contains "round1/reasonix.md") "Missing reasonix round1 output."
  Assert ($status.expected_outputs -contains "round2/claude-code.md") "Missing claude-code round2 output."
  Assert ($status.expected_outputs -contains "round2/reasonix.md") "Missing reasonix round2 output."
  Assert ($status.expected_outputs -contains "codex-synthesis.md") "Missing codex synthesis output."
  Assert ($status.expected_outputs -contains "decision.md") "Missing decision output."
  Assert-SafeExpectedOutputs -ExpectedOutputs $status.expected_outputs

  $status | Add-Member -NotePropertyName "reviewer_preserved_field" -NotePropertyValue "keep-me" -Force
  $status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Encoding UTF8

  $brief = Get-Content -LiteralPath (Join-Path $discussionFolder "brief.md") -Raw -Encoding UTF8
  foreach ($heading in @(
    "# Agent Discussion Brief",
    "## Topic",
    "## Question",
    "## Context",
    "## Agents",
    "## Expected Output Format",
    "# Agent Discussion Feedback",
    "## Recommendation",
    "## Reasoning",
    "## Risks",
    "## Disagreements Or Unknowns",
    "## Questions For Codex Or User"
  )) {
    Assert ($brief.Contains($heading)) "brief.md missing heading $heading."
  }

  $log = Get-Content -LiteralPath (Join-Path $discussionFolder "run.log") -Raw -Encoding UTF8
  Assert-NoSecretLikeContent -Content $brief -Name "brief.md"
  Assert-NoSecretLikeContent -Content $log -Name "run.log"

  $referenceSourceFolder = Join-Path $tempRoot "source-repo"
  New-Item -ItemType Directory -Force -Path $referenceSourceFolder | Out-Null
  $referenceSourcePath = Join-Path $referenceSourceFolder "design-note.md"
  Set-Content -LiteralPath $referenceSourcePath -Encoding UTF8 -Value @"
# Design Note

REFERENCE_SNAPSHOT_MARKER: external agents must read this copied snapshot.
"@

  $referenceDiscussionFolder = New-TestDiscussion -Mode "article-review" -Protocol "feedback" -Agents @("claude-code") -ReferencePaths @($referenceSourcePath)
  $referenceBrief = Get-Content -LiteralPath (Join-Path $referenceDiscussionFolder "brief.md") -Raw -Encoding UTF8
  $referenceStatus = Get-Content -LiteralPath (Join-Path $referenceDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $referenceManifestPath = Join-Path $referenceDiscussionFolder "references\manifest.md"
  Assert (Test-Path -LiteralPath $referenceManifestPath -PathType Leaf) "Reference manifest should be created."
  Assert ($referenceBrief.Contains("references/manifest.md")) "Brief should instruct agents to read the reference manifest."
  Assert ($referenceStatus.reference_count -eq 1) "Status should record one reference snapshot."
  Assert ($referenceStatus.reference_manifest -eq "references/manifest.md") "Status should record the relative reference manifest path."
  Assert ($referenceStatus.reference_snapshot_semantics -eq "frozen_copy") "Status should record frozen snapshot semantics."
  Assert (-not [string]::IsNullOrWhiteSpace([string]$referenceStatus.reference_snapshot_created_at)) "Status should record reference snapshot creation time."
  Assert ($referenceStatus.reference_freshness_rule.Contains("fresh discussion")) "Status should explain that source changes require a fresh discussion."
  Assert (-not $referenceBrief.Contains($referenceSourcePath)) "Brief should not expose source absolute reference paths."
  Assert ($referenceBrief.Contains("frozen evidence")) "Brief should describe reference snapshots as frozen evidence."
  Assert ($referenceBrief.Contains("fresh discussion")) "Brief should tell Codex to create a fresh discussion when source files changed."
  Assert ($referenceBrief.Contains("Round 2 and RawReadOnlyRecovery continue to use the same frozen snapshots")) "Brief should prevent treating round2/recovery as a current-source re-review."
  Assert-NoSecretLikeContent -Content $referenceBrief -Name "reference brief.md"
  $referenceManifest = Get-Content -LiteralPath $referenceManifestPath -Raw -Encoding UTF8
  Assert (-not $referenceManifest.Contains($referenceSourceFolder)) "Reference manifest should not expose source absolute folders."
  Assert ($referenceManifest.Contains("design-note.md")) "Reference manifest should include the source file name."
  Assert ($referenceManifest.Contains("snapshot_semantics: frozen_copy")) "Reference manifest should record frozen copy semantics."
  Assert ($referenceManifest.Contains("fresh Agent Workbench discussion")) "Reference manifest should require a fresh discussion when source files changed."
  $snapshotFiles = @(Get-ChildItem -LiteralPath (Join-Path $referenceDiscussionFolder "references\files") -File)
  Assert ($snapshotFiles.Count -eq 1) "Expected one copied reference snapshot."
  $snapshotContent = Get-Content -LiteralPath $snapshotFiles[0].FullName -Raw -Encoding UTF8
  Assert ($snapshotContent.Contains("REFERENCE_SNAPSHOT_MARKER")) "Copied reference snapshot should contain source material."

  $discussionCountBeforeUnknownLens = @(Get-ChildItem -LiteralPath (Join-Path $tempRoot "discussions") -Directory).Count
  $unknownLensError = $null
  try {
    New-TestDiscussion -Mode "code-review" -Agents @("claude-code") -AuditProfile "scientific" -ReviewerLenses @{ "reasonix" = "evidence skeptic" } | Out-Null
  } catch {
    $unknownLensError = $_
  }
  Assert ($null -ne $unknownLensError) "ReviewerLenses should reject reviewers absent from Agents."
  Assert ($unknownLensError.Exception.Message.Contains("ReviewerLenses contains reviewer(s) not present in Agents or OptionalAgents: reasonix.")) "Unknown ReviewerLenses errors should name the absent reviewer clearly."
  Assert (@(Get-ChildItem -LiteralPath (Join-Path $tempRoot "discussions") -Directory).Count -eq $discussionCountBeforeUnknownLens) "Unknown ReviewerLenses should fail before leaving a usable discussion."

  $scientificSecondSourcePath = Join-Path $referenceSourceFolder "evidence-note.md"
  Set-Content -LiteralPath $scientificSecondSourcePath -Encoding UTF8 -Value "SCIENTIFIC_SECOND_REFERENCE_MARKER"
  $scientificLenses = @{
    "claude-code" = "security boundary"
    "reasonix" = "evidence skeptic"
  }
  $scientificDiscussionFolder = New-TestDiscussion -Mode "code-review" -Protocol "adversarial-discussion" -Agents @("claude-code", "reasonix") -ReferencePaths @($referenceSourcePath, $scientificSecondSourcePath) -AuditProfile "scientific" -ReviewerLenses $scientificLenses
  $scientificBrief = Get-Content -LiteralPath (Join-Path $scientificDiscussionFolder "brief.md") -Raw -Encoding UTF8
  $scientificStatus = Get-Content -LiteralPath (Join-Path $scientificDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $scientificManifest = Get-Content -LiteralPath (Join-Path $scientificDiscussionFolder "references\manifest.md") -Raw -Encoding UTF8
  $scientificSnapshots = @(Get-ChildItem -LiteralPath (Join-Path $scientificDiscussionFolder "references\files") -File | Sort-Object Name)
  $scientificSnapshotHashes = @($scientificSnapshots | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
  $expectedBundleHasher = [System.Security.Cryptography.SHA256]::Create()
  try {
    $expectedEvidenceBundleId = -join ($expectedBundleHasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($scientificSnapshotHashes -join "`n"))) | ForEach-Object { $_.ToString("x2") })
  } finally {
    $expectedBundleHasher.Dispose()
  }
  Assert ($scientificStatus.audit_profile -eq "scientific") "Scientific discussions should persist the scientific audit profile."
  Assert ($scientificStatus.reviewer_lenses.'claude-code' -eq "security boundary") "Scientific status should persist reviewer lenses by reviewer name."
  Assert ($scientificStatus.reviewer_lenses.reasonix -eq "evidence skeptic") "Scientific status should persist every reviewer lens."
  Assert ($scientificStatus.evidence_bundle_id -eq $expectedEvidenceBundleId) "Scientific evidence bundle id should equal SHA-256 of ordered snapshot hashes joined with UTF-8 newlines."
  Assert ($scientificBrief.Contains("- audit_profile: scientific")) "Scientific brief should identify the audit profile."
  Assert ($scientificBrief.Contains("## Reviewer Lenses")) "Scientific brief should show reviewer lenses."
  Assert ($scientificBrief.Contains("- claude-code: security boundary")) "Scientific brief should show the Claude reviewer lens."
  Assert ($scientificBrief.Contains("- reasonix: evidence skeptic")) "Scientific brief should show the Reasonix reviewer lens."
  foreach ($findingField in @("### Finding <reviewer-local-id>", "- Area:", "- Claim:", "- Severity: critical | high | medium | low | info", "- Evidence:", "- Confidence: high | medium | low", "- Counter-evidence:", "- Recommended action:", "- Blocking: yes | no")) {
    Assert ($scientificBrief.Contains($findingField)) "Scientific code review brief should require finding field $findingField."
  }
  Assert ($scientificBrief.Contains("Round 1 is blind and independent; do not read another reviewer's output.")) "Scientific brief should require blind independent Round 1 review."
  Assert ($scientificBrief.Contains("Round 2 addresses only disputed, blocking, or weak-evidence findings from codex-synthesis.md.")) "Scientific brief should limit Round 2 to targeted findings."
  Assert ($scientificBrief.Contains("maintained, revised, or withdrawn")) "Scientific brief should require Round 2 position markers."
  Assert ($scientificManifest.Contains("| ID | Snapshot | Source Name | Bytes | SHA-256 | Source Last Write UTC |")) "Scientific manifest should include provenance columns."
  foreach ($scientificSnapshotHash in $scientificSnapshotHashes) {
    Assert ($scientificManifest.Contains($scientificSnapshotHash)) "Scientific manifest should record each copied snapshot SHA-256 hash."
  }
  Assert ($scientificManifest -match "\| [A-Fa-f0-9]{64} \|") "Scientific manifest should record 64-hex snapshot hashes."
  Assert (-not $scientificManifest.Contains($referenceSourceFolder)) "Scientific manifest should not expose source absolute folders."

  $scientificRepeatFolder = New-TestDiscussion -Mode "code-review" -Protocol "adversarial-discussion" -Agents @("claude-code", "reasonix") -ReferencePaths @($referenceSourcePath, $scientificSecondSourcePath) -AuditProfile "scientific" -ReviewerLenses $scientificLenses
  $scientificRepeatStatus = Get-Content -LiteralPath (Join-Path $scientificRepeatFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($scientificRepeatStatus.evidence_bundle_id -eq $scientificStatus.evidence_bundle_id) "Equivalent ordered snapshot hashes should produce the same evidence bundle id."

  Set-Content -LiteralPath $referenceSourcePath -Encoding UTF8 -Value "REFERENCE_SNAPSHOT_MARKER: source content changed after the original scientific discussion."
  $scientificChangedSourceFolder = New-TestDiscussion -Mode "code-review" -Protocol "adversarial-discussion" -Agents @("claude-code", "reasonix") -ReferencePaths @($referenceSourcePath, $scientificSecondSourcePath) -AuditProfile "scientific" -ReviewerLenses $scientificLenses
  $scientificChangedSourceStatus = Get-Content -LiteralPath (Join-Path $scientificChangedSourceFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($scientificChangedSourceStatus.evidence_bundle_id -ne $scientificStatus.evidence_bundle_id) "Fresh discussions should use a different evidence bundle id when source content changes."

Set-Content -LiteralPath (Join-Path $scientificDiscussionFolder "round1\claude-code.md") -Encoding UTF8 -Value @"
# Scientific Review Feedback

### Finding claude-1
- Area: evidence boundary
- Claim: The source trace lacks a stable reviewer identifier.
- Severity: high
- Evidence: The manifest contains snapshots but no reviewer identity column.
- Confidence: high
- Counter-evidence: The file name identifies the reviewer locally.
- Recommended action: Add a reviewer identifier to the trace record.
- Blocking: yes
- Claim type: traceability
- Falsifier: A persisted reviewer identifier proves this claim false.
- Minimum validation: Parse two independent reviewer findings.
"@
Set-Content -LiteralPath (Join-Path $scientificDiscussionFolder "round1\reasonix.md") -Encoding UTF8 -Value @"
# Scientific Review Feedback

### Finding reasonix-1
- Area: calibration
- Claim: Outcome records need append-only storage.
- Severity: medium
- Evidence: No local calibration history is present.
- Confidence: medium
- Counter-evidence
- Recommended action: Append records to discussion and workbench logs.
- Blocking: no
- Claim type: operational
- Falsifier: Two retained calibration events disprove this claim.
- Minimum validation: Parse the JSONL records after a second append.
"@

& $collectScriptPath -DiscussionFolder $scientificDiscussionFolder | Out-Null
$findingsPath = Join-Path $scientificDiscussionFolder "findings.json"
$matrixPath = Join-Path $scientificDiscussionFolder "disagreement-matrix.md"
Assert (Test-Path -LiteralPath $findingsPath -PathType Leaf) "Scientific collection should write findings.json."
Assert (Test-Path -LiteralPath $matrixPath -PathType Leaf) "Scientific collection should write disagreement-matrix.md."
[object[]]$findings = (Get-Content -LiteralPath $findingsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
Assert ($findings.Count -eq 2) "Scientific collection should parse two reviewers' findings."
$claudeFinding = @($findings | Where-Object { $_.finding_id -eq "claude-1" })[0]
$reasonixFinding = @($findings | Where-Object { $_.finding_id -eq "reasonix-1" })[0]
Assert ($claudeFinding.reviewer -eq "claude-code") "Parsed finding should retain its reviewer."
Assert ($claudeFinding.round -eq "round1") "Parsed finding should retain its round."
Assert ($claudeFinding.source_file -eq "round1/claude-code.md") "Parsed finding should use a relative source file."
Assert ($claudeFinding.claim_type -eq "traceability") "Parsed finding should normalize claim type to snake_case."
Assert ($reasonixFinding.counter_evidence -eq "") "Missing or malformed optional fields should normalize to empty strings."
$matrix = Get-Content -LiteralPath $matrixPath -Raw -Encoding UTF8
$pendingRows = @($matrix -split "`r?`n" | Where-Object { $_ -match "\| pending_codex \|" })
Assert ($pendingRows.Count -eq 2) "Matrix should contain one pending_codex row per parsed finding."
$findingBytes = [System.IO.File]::ReadAllBytes($findingsPath)
$hasUtf8Bom = ($findingBytes.Length -ge 3) -and ($findingBytes[0] -eq 0xEF) -and ($findingBytes[1] -eq 0xBB) -and ($findingBytes[2] -eq 0xBF)
Assert (-not $hasUtf8Bom) "Scientific findings.json should use explicit BOM-free UTF-8."

$duplicateFindingFolder = New-TestDiscussion -Mode "code-review" -Agents @("claude-code") -AuditProfile "scientific"
Set-Content -LiteralPath (Join-Path $duplicateFindingFolder "round1\claude-code.md") -Encoding UTF8 -Value @"
# Code Review Feedback

### Finding duplicate-1
- Claim: First claim.

### Finding duplicate-1
- Claim: Second claim with the same reviewer-local id.
"@
$duplicateFindingError = $null
try {
  & $collectScriptPath -DiscussionFolder $duplicateFindingFolder | Out-Null
} catch {
  $duplicateFindingError = $_
}
Assert ($null -ne $duplicateFindingError) "Scientific collection should reject duplicate reviewer-local finding ids."
Assert ($duplicateFindingError.Exception.Message -match "Duplicate scientific finding id") "Duplicate finding rejection should explain the identity conflict."

$standardNoArtifactsFolder = New-TestDiscussion -Mode "code-review" -Agents @("claude-code")
& $collectScriptPath -DiscussionFolder $standardNoArtifactsFolder | Out-Null
Assert (-not (Test-Path -LiteralPath (Join-Path $standardNoArtifactsFolder "findings.json"))) "Standard collection must not create findings.json."
Assert (-not (Test-Path -LiteralPath (Join-Path $standardNoArtifactsFolder "disagreement-matrix.md"))) "Standard collection must not create disagreement-matrix.md."

  $scientificStrategyFolder = New-TestDiscussion -Mode "strategy-review" -Protocol "adversarial-discussion" -Agents @("claude-code") -AuditProfile "scientific"
  $scientificStrategyBrief = Get-Content -LiteralPath (Join-Path $scientificStrategyFolder "brief.md") -Raw -Encoding UTF8
  foreach ($strategyField in @("- Claim type: fact | inference | assumption", "- Falsifier:", "- Minimum validation:")) {
    Assert ($scientificStrategyBrief.Contains($strategyField)) "Scientific strategy brief should require $strategyField."
  }

  Assert ($status.audit_profile -eq "standard") "Default discussions should persist the standard audit profile."
  Assert ([string]$status.evidence_bundle_id -eq "") "Discussions without snapshots should use an empty evidence bundle id."
  Assert (-not $brief.Contains("### Finding <reviewer-local-id>")) "Standard profile should retain its existing output contract."

  $reasonixSource = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\Open-ReasonixDiscussion.ps1") -Raw -Encoding UTF8
  $claudeSource = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\Invoke-ClaudeFeedback.ps1") -Raw -Encoding UTF8
  foreach ($runnerSource in @($reasonixSource, $claudeSource)) {
    Assert ($runnerSource.Contains("Do not read another reviewer's output during scientific Round 1.")) "Scientific reviewer runners should preserve blind Round 1 behavior."
    Assert ($runnerSource.Contains("Address only disputed, blocking, or weak-evidence findings from codex-synthesis.md.")) "Scientific reviewer runners should preserve targeted Round 2 behavior."
    Assert ($runnerSource.Contains("Mark each addressed position as maintained, revised, or withdrawn.")) "Scientific reviewer runners should require Round 2 position markers."
  }

  $fileBindRoot = Join-Path $tempRoot "file-bind"
  New-Item -ItemType Directory -Force -Path $fileBindRoot | Out-Null
  $fileBindRef1 = Join-Path $fileBindRoot "ref1.md"
  $fileBindRef2 = Join-Path $fileBindRoot "ref2.md"
  Set-Content -LiteralPath $fileBindRef1 -Encoding UTF8 -Value "FILE_BIND_REFERENCE_ONE"
  Set-Content -LiteralPath $fileBindRef2 -Encoding UTF8 -Value "FILE_BIND_REFERENCE_TWO"

  $fileBindOutput = powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -WorkbenchRoot $tempRoot `
    -Slug "file-bind-reference-array" `
    -Topic "PowerShell file binding" `
    -Question "Can multiple ReferencePaths survive powershell -File array expansion?" `
    -Context "This reproduces the MaxRounds misbinding bug." `
    -Mode code-review `
    -Protocol feedback `
    -ReferencePaths @($fileBindRef1, $fileBindRef2) `
    -Agents claude-code
  Assert ($LASTEXITCODE -eq 0) "powershell -File with multiple ReferencePaths should not misbind a path to MaxRounds."
  $fileBindFolder = ($fileBindOutput | Select-Object -Last 1).Trim()
  $fileBindStatus = Get-Content -LiteralPath (Join-Path $fileBindFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($fileBindStatus.reference_count -eq 2) "powershell -File should preserve both ReferencePaths."

  $articleDiscussionFolder = New-TestDiscussion -Mode "article-review" -Protocol "adversarial-discussion" -Agents @("claude-code")
  $articleBrief = Get-Content -LiteralPath (Join-Path $articleDiscussionFolder "brief.md") -Raw -Encoding UTF8
  $articleStatus = Get-Content -LiteralPath (Join-Path $articleDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json

  Assert ($articleBrief.Contains("- mode: article-review")) "Article brief should record article-review mode."
  Assert ($articleBrief.Contains("- protocol: adversarial-discussion")) "Article brief should record adversarial discussion protocol."
  Assert ($articleBrief.Contains("## Discussion Protocol")) "Article brief should include discussion protocol instructions."
  Assert ($articleBrief.Contains("codex-synthesis.md")) "Article adversarial brief should mention codex-synthesis.md."
  Assert ($articleBrief.Contains("Round 2")) "Article adversarial brief should describe round 2."
  Assert ($articleBrief.Contains("# Article Review Feedback")) "Article brief should use the article review feedback heading."
  Assert ($articleBrief.Contains($articleOverallHeading)) "Article brief should include Chinese overall judgment heading."
  Assert ($articleBrief.Contains($articleValueHeading)) "Article brief should include Chinese valuable points heading."
  Assert ($articleBrief.Contains($articleDisagreementHeading)) "Article brief should include Codex disagreement heading."
  Assert (-not $articleBrief.Contains("## Recommendation")) "Article brief should not fall back to default Recommendation format."
  Assert ($articleStatus.mode -eq "article-review") "Article status should persist mode."
  Assert ($articleStatus.protocol -eq "adversarial-discussion") "Article status should persist protocol."
  Assert ($articleStatus.expected_output_source -eq "mode") "Article status should mark mode output format source."
  Assert ($articleStatus.expected_output_format.Contains("# Article Review Feedback")) "Article status should persist the selected format."

  $customFormat = @"
# Custom Review Feedback

## One

## Two
"@
  $customDiscussionFolder = New-TestDiscussion -Mode "article-review" -Protocol "feedback" -ExpectedOutputFormat $customFormat -Agents @("claude-code")
  $customBrief = Get-Content -LiteralPath (Join-Path $customDiscussionFolder "brief.md") -Raw -Encoding UTF8
  $customStatus = Get-Content -LiteralPath (Join-Path $customDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($customBrief.Contains("# Custom Review Feedback")) "Custom brief should use caller-provided format."
  Assert ($customBrief.Contains("## One")) "Custom brief should include custom section."
  Assert (-not $customBrief.Contains("# Article Review Feedback")) "Custom format should override article mode preset."
  Assert (-not $customBrief.Contains("## Recommendation")) "Custom format should not include default Recommendation format."
  Assert ($customStatus.expected_output_source -eq "custom") "Custom status should mark custom output format source."
  Assert ($customStatus.expected_output_format.Contains("# Custom Review Feedback")) "Custom status should persist custom output format."

  $proseFormat = "Markdown with sections: Summary, HIGH findings, MEDIUM findings, LOW findings, STRATEGIC_NOTES, Scope verdict, Required remediation. Include counts for each severity."
  $normalizedDiscussionFolder = New-TestDiscussion -Mode "code-review" -Protocol "feedback" -ExpectedOutputFormat $proseFormat -Agents @("claude-code")
  $normalizedBrief = Get-Content -LiteralPath (Join-Path $normalizedDiscussionFolder "brief.md") -Raw -Encoding UTF8
  $normalizedStatus = Get-Content -LiteralPath (Join-Path $normalizedDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($normalizedStatus.expected_output_source -eq "custom_normalized") "Prose custom output format should be normalized."
  Assert ($normalizedStatus.expected_output_format.Contains("# Agent Discussion Feedback")) "Normalized format should add default Agent Discussion heading."
  foreach ($section in @("## Summary", "## HIGH findings", "## MEDIUM findings", "## LOW findings", "## STRATEGIC_NOTES", "## Scope verdict", "## Required remediation")) {
    Assert ($normalizedStatus.expected_output_format.Contains($section)) "Normalized format should include section $section."
    Assert ($normalizedBrief.Contains($section)) "Brief should include normalized section $section."
  }
  Assert ($normalizedStatus.expected_output_sections -contains "Summary") "Status should persist normalized expected sections."
  Assert ($normalizedStatus.expected_output_instructions.Contains("Include counts for each severity")) "Status should preserve trailing prose instructions."

  $sectionsDiscussionFolder = New-TestDiscussion -Mode "code-review" -Protocol "feedback" -ExpectedSections @("Alpha", "Beta") -Agents @("claude-code")
  $sectionsStatus = Get-Content -LiteralPath (Join-Path $sectionsDiscussionFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($sectionsStatus.expected_output_source -eq "sections") "ExpectedSections should mark sections output source."
  Assert ($sectionsStatus.expected_output_format.Contains("## Alpha")) "ExpectedSections should generate Alpha section."
  Assert ($sectionsStatus.expected_output_format.Contains("## Beta")) "ExpectedSections should generate Beta section."

  $strictReviewerFolder = New-TestDiscussion -Mode "strategy-review" -Protocol "adversarial-discussion" -Agents @("claude-code", "reasonix")
  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "round1\reasonix-instructions.md") -Encoding UTF8 -Value @"
# Reasonix Instructions

Write feedback to round1/reasonix.md.
"@

  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $strictReviewerStatus = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($strictReviewerStatus.round1_count -eq 0) "Reasonix instructions must not count as Round 1 feedback."
  Assert ($strictReviewerStatus.round1_completed_agents.Count -eq 0) "Reasonix instructions must not complete any Round 1 reviewer."
  Assert ($strictReviewerStatus.round1_missing_agents -contains "reasonix") "Reasonix must remain missing when only instructions exist."
  Assert ($strictReviewerStatus.state -eq "awaiting_round1_reviewers") "Instruction-only Round 1 must await expected reviewers."

  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "round1\claude-code.md") -Encoding UTF8 -Value "# Claude Round 1"
  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $round1CompleteStatus = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($round1CompleteStatus.state -eq "awaiting_round1_reviewers") "Round 1 must wait for Reasonix canonical feedback."

  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "round1\reasonix.md") -Encoding UTF8 -Value "# Reasonix Round 1"
  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $round1ReadyStatus = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($round1ReadyStatus.state -eq "feedback_collected") "Complete Round 1 with no Round 2 feedback should be feedback_collected."

  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "round2\claude-code.md") -Encoding UTF8 -Value "# Claude Round 2"
  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $partialRound2Status = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($partialRound2Status.round2_count -eq 1) "Round 2 count should include only Claude canonical feedback."
  Assert ($partialRound2Status.round2_completed_agents -contains "claude-code") "Claude should complete Round 2 with canonical feedback."
  Assert ($partialRound2Status.round2_missing_agents -contains "reasonix") "Reasonix must remain missing in partial Round 2."
  Assert ($partialRound2Status.state -eq "awaiting_round2_reviewers") "Partial Round 2 must await expected reviewers."

  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "round2\reasonix.md") -Encoding UTF8 -Value "# Reasonix Round 2"
  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $completeRound2Status = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($completeRound2Status.round2_count -eq 2) "Round 2 count should include both canonical reviewer feedback files."
  Assert ($completeRound2Status.round2_missing_agents.Count -eq 0) "No expected reviewer should remain missing after Reasonix feedback."
  Assert ($completeRound2Status.state -eq "awaiting_codex_synthesis") "Complete Round 2 with empty codex-synthesis.md should await Codex synthesis."

  Set-Content -LiteralPath (Join-Path $strictReviewerFolder "codex-synthesis.md") -Encoding UTF8 -Value "# Codex Synthesis`n`nResolve the remaining evidence dispute."
  & $collectScriptPath -DiscussionFolder $strictReviewerFolder | Out-Null
  $synthesizedRound2Status = Get-Content -LiteralPath (Join-Path $strictReviewerFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($synthesizedRound2Status.state -eq "needs_codex_decision") "Complete Round 2 with non-empty synthesis should require Codex decision."

  $decisionGateFolder = New-TestDiscussion -Mode "strategy-review" -Protocol "adversarial-discussion" -Agents @("claude-code")
  Set-Content -LiteralPath (Join-Path $decisionGateFolder "round1\claude-code.md") -Encoding UTF8 -Value @"
# Strategy Review Feedback

## Recommendation

Use a two-layer framing.
"@
  Set-Content -LiteralPath (Join-Path $decisionGateFolder "codex-synthesis.md") -Encoding UTF8 -Value @"
# Codex Synthesis

Ask round 2 to resolve the framing dispute.
"@
  Set-Content -LiteralPath (Join-Path $decisionGateFolder "round2\claude-code.md") -Encoding UTF8 -Value @"
# Strategy Review Feedback

## Recommendation

Round 2 converges. Codex should now write the final decision.
"@

  $decisionGateOutput = (& $collectScriptPath -DiscussionFolder $decisionGateFolder) -join [Environment]::NewLine
  $decisionGateStatus = Get-Content -LiteralPath (Join-Path $decisionGateFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($decisionGateStatus.state -eq "needs_codex_decision") "Adversarial discussion with round2 feedback and empty decision.md should require Codex decision."
  Assert ($decisionGateStatus.current_round -eq 2) "Decision gate discussion should remain on current_round 2."
  Assert ($decisionGateOutput.Contains("state: needs_codex_decision")) "Collection output should report needs_codex_decision."

  Set-Content -LiteralPath (Join-Path $decisionGateFolder "decision.md") -Encoding UTF8 -Value @"
# Final Decision

Codex accepts the two-layer framing.
"@

  & $collectScriptPath -DiscussionFolder $decisionGateFolder | Out-Null
  $decisionReadyStatus = Get-Content -LiteralPath (Join-Path $decisionGateFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($decisionReadyStatus.state -eq "decision_ready") "Adversarial discussion with a non-empty decision.md should be decision_ready."

  $secretFeedbackFileName = "claude-sk-fileSecret1234567890.md"
  Set-Content -LiteralPath (Join-Path $discussionFolder "round1\$secretFeedbackFileName") -Encoding UTF8 -Value @"
# Agent Discussion Feedback

## Recommendation

I disagree with the current direction because there is a major risk in the handoff boundary.

## Reasoning

Keep the moderator role explicit.

## Risks

This is a high-risk workflow if collection leaks provider tokens.
"@
  Copy-Item -LiteralPath (Join-Path $discussionFolder "round1\$secretFeedbackFileName") -Destination (Join-Path $discussionFolder "round1\claude-code.md")

  Set-Content -LiteralPath (Join-Path $discussionFolder "round2\reasonix.md") -Encoding UTF8 -Value @"
# Agent Discussion Feedback

## Recommendation

This is blocked until the user chooses a direction.

## Reasoning

The blocker is unresolved, and the note includes sk-round2Secret1234567890 plus $openAiKeyName=abc123.
"@

  Set-Content -LiteralPath (Join-Path $discussionFolder "user-decision-needed.md") -Encoding UTF8 -Value @"
# User Decision Needed

Please choose whether to prioritize speed or stricter review.
"@

  $collectionOutput = (& $collectScriptPath -DiscussionFolder $discussionFolder) -join [Environment]::NewLine
  Assert ($collectionOutput.Contains("## File Status")) "Collection output missing file status section."
  Assert ($collectionOutput.Contains("brief.md: present")) "Collection output missing brief.md status."
  Assert ($collectionOutput.Contains("decision.md: present")) "Collection output missing decision.md status."
  Assert ($collectionOutput.Contains("round1_count: 1")) "Collection output missing round1 count."
  Assert ($collectionOutput.Contains("round2_count: 1")) "Collection output missing round2 count."
  Assert ($collectionOutput.Contains("claude-code.md")) "Collection output missing canonical round1 feedback file name."
  Assert (-not $collectionOutput.Contains($secretFeedbackFileName)) "Collection output leaked secret-like feedback file name."
  Assert ($collectionOutput.Contains("reasonix.md")) "Collection output missing round2 feedback file name."
  Assert ($collectionOutput.Contains("I disagree with the current direction")) "Collection output missing sanitized feedback excerpt."
  Assert ($collectionOutput.Contains("[REDACTED_SECRET]")) "Collection output missing redacted secret marker."
  Assert-NoSecretLikeContent -Content $collectionOutput -Name "collection output"

  $collectedStatusJson = Get-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Raw -Encoding UTF8
  $collectedStatus = $collectedStatusJson | ConvertFrom-Json
  Assert ($collectedStatus.state -eq "needs_user_decision") "Collection should set state to needs_user_decision."
  Assert ($collectedStatus.round1_count -eq 1) "Collection should set round1_count to 1."
  Assert ($collectedStatus.round2_count -eq 1) "Collection should set round2_count to 1."
  Assert ($collectedStatus.current_round -eq 2) "Collection should set current_round to 2 when round2 feedback exists."
  Assert ($collectedStatus.signals -contains "disagreement") "Collection should detect disagreement signal."
  Assert ($collectedStatus.signals -contains "risk") "Collection should detect risk signal."
  Assert ($collectedStatus.signals -contains "blocker") "Collection should detect blocker signal."
  Assert ($collectedStatus.PSObject.Properties.Name -contains "reviewer_preserved_field") "Collection should preserve unknown status fields."
  Assert ($collectedStatus.reviewer_preserved_field -eq "keep-me") "Collection should preserve unknown status field values."

  $unicodeDiscussionFolder = New-TestDiscussion -Agents @("unicode-agent")
  Set-Content -LiteralPath (Join-Path $unicodeDiscussionFolder "round1\unicode-agent.md") -Encoding UTF8 -Value @"
# Agent Discussion Feedback

## Recommendation

$unicodeDisagreementA / $unicodeDisagreementB / $unicodeDisagreementC

## Risks

$unicodeRiskA / $unicodeRiskB
"@

  Set-Content -LiteralPath (Join-Path $unicodeDiscussionFolder "round2\unicode-agent.md") -Encoding UTF8 -Value @"
# Agent Discussion Feedback

## Recommendation

$unicodeBlockerA / $unicodeBlockerB
"@

  & $collectScriptPath -DiscussionFolder $unicodeDiscussionFolder | Out-Null
  $unicodeStatusJson = Get-Content -LiteralPath (Join-Path $unicodeDiscussionFolder "status.json") -Raw -Encoding UTF8
  $unicodeStatus = $unicodeStatusJson | ConvertFrom-Json
  Assert ($unicodeStatus.signals -contains "disagreement") "Collection should detect Unicode-escaped Chinese disagreement signals."
  Assert ($unicodeStatus.signals -contains "risk") "Collection should detect Unicode-escaped Chinese risk signals."
  Assert ($unicodeStatus.signals -contains "blocker") "Collection should detect Unicode-escaped Chinese blocker signals."

  $unsafeAgents = @("claude/../evil", "..\reasonix", "C:\Users\Alice\agent", "agent:name?bad|chars")
  $oneRoundFolder = New-TestDiscussion -MaxRounds 1 -Agents $unsafeAgents
  Assert (Test-Path -LiteralPath (Join-Path $oneRoundFolder "round1") -PathType Container) "MaxRounds=1 missing round1 folder."
  Assert (-not (Test-Path -LiteralPath (Join-Path $oneRoundFolder "round2"))) "MaxRounds=1 should not create round2 folder."

  $oneRoundStatusJson = Get-Content -LiteralPath (Join-Path $oneRoundFolder "status.json") -Raw -Encoding UTF8
  $oneRoundStatus = $oneRoundStatusJson | ConvertFrom-Json
  Assert ($oneRoundStatus.max_rounds -eq 1) "MaxRounds=1 status mismatch."
  Assert ($oneRoundStatus.agents -contains "[REDACTED_LOCAL_PATH]") "Sanitized display agent for absolute path missing."
  Assert (-not ($oneRoundStatus.expected_outputs | Where-Object { $_ -like "round2/*" })) "MaxRounds=1 should not include round2 expected outputs."
  Assert (-not ($oneRoundStatus.expected_outputs | Where-Object { $_ -match "\.\.|\\|^[A-Za-z]:|^/" })) "Expected outputs contain traversal or absolute path."
  Assert-SafeExpectedOutputs -ExpectedOutputs $oneRoundStatus.expected_outputs
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
