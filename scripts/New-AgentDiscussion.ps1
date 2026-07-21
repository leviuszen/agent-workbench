[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)][string]$WorkbenchRoot,
  [Parameter(Mandatory = $true)][string]$Slug,
  [Parameter(Mandatory = $true)][string]$Topic,
  [Parameter(Mandatory = $true)][string]$Question,
  [Parameter(Mandatory = $true)][string]$Context,
  [ValidateRange(1, 2)][int]$MaxRounds = 2,
  [string]$Mode = "general",
  [string]$Protocol = "feedback",
  [string]$ExpectedOutputFormat = "",
  [string[]]$ExpectedSections = @(),
  [string[]]$ReferencePaths = @(),
  [ValidateRange(1, 200)][int]$MaxReferenceFiles = 40,
  [ValidateRange(1024, 1048576)][int]$MaxReferenceFileBytes = 262144,
  [string[]]$Agents = @(),
  [string[]]$OptionalAgents = @(),
  [string]$AuditProfile = "standard",
  [hashtable]$ReviewerLenses = @{},
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$RemainingArguments = @()
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$validModes = @("general", "article-review", "strategy-review", "code-review", "decision")
$validProtocols = @("feedback", "adversarial-discussion")
$validAuditProfiles = @("standard", "scientific")
if ($Mode -notin $validModes) {
  if ($Mode -eq "review") {
    throw "Mode 'review' is ambiguous. Use -Mode code-review for repository/code review or -Mode strategy-review for plans and strategy."
  }
  throw "Invalid Mode '$Mode'. Valid values: $($validModes -join ', ')."
}
if ($Protocol -notin $validProtocols) {
  if ($Protocol -eq "scientific") {
    throw "Protocol 'scientific' is invalid. Use -AuditProfile scientific with -Protocol adversarial-discussion."
  }
  throw "Invalid Protocol '$Protocol'. Valid values: $($validProtocols -join ', ')."
}
if ($AuditProfile -notin $validAuditProfiles) {
  throw "Invalid AuditProfile '$AuditProfile'. Valid values: $($validAuditProfiles -join ', ')."
}

$duplicateAgentRoles = @($Agents | Where-Object { $_ -in $OptionalAgents } | Select-Object -Unique)
if ($duplicateAgentRoles.Count -gt 0) {
  throw "Reviewer(s) cannot be both required and optional: $($duplicateAgentRoles -join ', ')."
}
$allAgents = @($Agents + $OptionalAgents | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

function Redact-DiscussionText {
  param([string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  $providerEnvPattern = "\b(?:OPENAI|ANTHROPIC|DEEPSEEK|GOOGLE|GEMINI|DASHSCOPE|QWEN|AZURE_OPENAI|OPENROUTER|XAI|MISTRAL|GROQ|COHERE|PERPLEXITY)[A-Z0-9_]*(?:API_KEY|TOKEN|KEY)\b(?:\s*[:=]\s*[^\s,;]+)?"
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerEnvPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)api\.deepseek\S*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\b[A-Z]:\\[^\r\n\t<>|`"]+", "[REDACTED_LOCAL_PATH]"
  $redacted = $redacted -replace "(?i)(?:/Users|/home|/mnt|/Volumes)/[^\r\n\t<>|`"]+", "[REDACTED_LOCAL_PATH]"
  return $redacted
}

function Redact-DiscussionSlug {
  param([string]$Value)

  $redacted = Redact-DiscussionText -Value $Value
  return $redacted -replace "\[REDACTED_SECRET\]", "redacted-secret" -replace "\[REDACTED_LOCAL_PATH\]", "redacted-path"
}

function New-SafeSlug {
  param([string]$Value)

  $safe = $Value.ToLowerInvariant() -replace "[^a-z0-9_-]+", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "discussion"
  }

  return $safe
}

function New-SafeFileStem {
  param([string]$Value)

  $stem = New-SafeSlug -Value (Redact-DiscussionSlug -Value $Value)
  if ([string]::IsNullOrWhiteSpace($stem)) {
    return "agent"
  }

  return $stem
}

function New-UnicodeText {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Get-DefaultOutputFormat {
  return @"
# Agent Discussion Feedback

## Recommendation

## Reasoning

## Risks

## Disagreements Or Unknowns

## Questions For Codex Or User
"@
}

function Get-ArticleReviewOutputFormat {
  $overall = New-UnicodeText -CodePoints @(0x603b, 0x4f53, 0x5224, 0x65ad)
  $valuablePoints = New-UnicodeText -CodePoints @(0x6700, 0x6709, 0x4ef7, 0x503c, 0x89c2, 0x70b9)
  $mainIssues = New-UnicodeText -CodePoints @(0x4e3b, 0x8981, 0x95ee, 0x9898)
  $structureSuggestions = New-UnicodeText -CodePoints @(0x7ed3, 0x6784, 0x5efa, 0x8bae)
  $directEdits = New-UnicodeText -CodePoints @(0x53ef, 0x76f4, 0x63a5, 0x4fee, 0x6539, 0x7684, 0x5efa, 0x8bae)
  $need = New-UnicodeText -CodePoints @(0x9700, 0x8981)
  $judgeDisagreement = New-UnicodeText -CodePoints @(0x5224, 0x65ad, 0x7684, 0x5206, 0x6b67)

  return @"
# Article Review Feedback

## $overall

## $valuablePoints

## $mainIssues

## $structureSuggestions

## $directEdits

## $need Codex $judgeDisagreement
"@
}

function Get-ModeOutputFormat {
  param([string]$SelectedMode)

  switch ($SelectedMode) {
    "article-review" { return Get-ArticleReviewOutputFormat }
    "strategy-review" {
      return @"
# Strategy Review Feedback

## Recommendation

## Core Assumptions

## Strongest Arguments

## Weak Points Or Missing Evidence

## Risks

## Questions For Codex Or User
"@
    }
    "code-review" {
      return @"
# Code Review Feedback

## Findings

## Risk Assessment

## Test Gaps

## Recommended Changes

## Questions For Codex Or User
"@
    }
    "decision" {
      return @"
# Decision Feedback

## Preferred Option

## Reasoning

## Tradeoffs

## Conditions That Would Change This View

## Questions For Codex Or User
"@
    }
    default { return Get-DefaultOutputFormat }
  }
}

function Get-ScientificAuditContract {
  param([string]$SelectedMode)

  if ($SelectedMode -notin @("code-review", "strategy-review")) {
    return ""
  }

  $strategyFields = if ($SelectedMode -eq "strategy-review") {
    @"
- Claim type: fact | inference | assumption
- Falsifier:
- Minimum validation:
"@
  } else {
    ""
  }

  return @"
## Scientific Audit Contract

Repeat this finding block for every finding:

### Finding <reviewer-local-id>
- Area:
- Claim:
- Severity: critical | high | medium | low | info
- Evidence:
- Confidence: high | medium | low
- Counter-evidence:
- Recommended action:
- Blocking: yes | no
$strategyFields
"@
}

function New-FeedbackFormatFromSections {
  param(
    [string[]]$Sections,
    [string]$Instructions = ""
  )

  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add("# Agent Discussion Feedback")
  $lines.Add("")
  foreach ($section in @($Sections)) {
    $cleanSection = $section.Trim()
    if ([string]::IsNullOrWhiteSpace($cleanSection)) {
      continue
    }

    if ($cleanSection.StartsWith("## ")) {
      $lines.Add($cleanSection)
    } else {
      $lines.Add("## $cleanSection")
    }
    $lines.Add("")
  }

  if (-not [string]::IsNullOrWhiteSpace($Instructions)) {
    $lines.Add("## Output Instructions")
    $lines.Add("")
    $lines.Add($Instructions.Trim())
  }

  return ($lines -join [Environment]::NewLine).TrimEnd()
}

function Get-FeedbackSectionsFromFormat {
  param([string]$Format)

  $sections = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($Format -split '\r?\n')) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("## ")) {
      $sections.Add($trimmed.Substring(3).Trim())
    }
  }

  return @($sections)
}

function ConvertFrom-ProseExpectedFormat {
  param([string]$Format)

  $trimmed = $Format.Trim()
  $match = [regex]::Match($trimmed, '(?is)\bsections\s*:\s*(.+?)(?:\.|$)(.*)$')
  if (-not $match.Success) {
    return $null
  }

  $sectionText = $match.Groups[1].Value.Trim()
  $instructions = $match.Groups[2].Value.Trim()
  if ([string]::IsNullOrWhiteSpace($sectionText)) {
    return $null
  }

  $sectionText = $sectionText -replace '\s+and\s+', ', '
  $sections = @(
    $sectionText -split '\s*,\s*' |
      ForEach-Object { $_.Trim() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )

  if ($sections.Count -eq 0) {
    return $null
  }

  return [pscustomobject]@{
    Format = New-FeedbackFormatFromSections -Sections $sections -Instructions $instructions
    Sections = @($sections)
    Instructions = $instructions
  }
}

function Get-DiscussionProtocolText {
  param(
    [string]$SelectedProtocol,
    [int]$SelectedMaxRounds,
    [string]$SelectedMode,
    [string]$SelectedAuditProfile
  )

  $scientificRules = if ($SelectedAuditProfile -eq "scientific" -and $SelectedMode -in @("code-review", "strategy-review")) {
    @"
## Scientific Dual Audit Rules

- Round 1 is blind and independent; do not read another reviewer's output.
- Round 2 addresses only disputed, blocking, or weak-evidence findings from codex-synthesis.md.
- Mark each Round 2 addressed position as maintained, revised, or withdrawn.
"@
  } else {
    ""
  }

  if ($SelectedProtocol -eq "adversarial-discussion") {
    $round2Text = if ($SelectedMaxRounds -eq 2) {
      @"
- Round 2: after Codex writes codex-synthesis.md, read both brief.md and codex-synthesis.md, then either converge, revise your position, or preserve a disagreement with specific reasons.
"@
    } else {
      @"
- This discussion is limited to one external round. Codex will synthesize disagreements after Round 1.
"@
    }

    $protocolText = @"
## Discussion Protocol

- Codex is the moderator and final decision writer.
- Round 1: give an independent critique, identify risks, and name any disagreement with the framing or likely conclusion.
- Codex synthesis: Codex writes codex-synthesis.md with consensus, disagreements, and questions.
$round2Text
- Closure: Codex writes decision.md when the issue converges, or user-decision-needed.md when a material disagreement remains unresolved after two rounds.
- Do not behave as a one-way answer generator in adversarial-discussion mode. Make your position explicit and respond to Codex synthesis when Round 2 is requested.
"@
    return ($protocolText + $scientificRules)
  }

  $protocolText = @"
## Discussion Protocol

- This is a one-way structured feedback request unless Codex explicitly asks for another round.
- Codex remains the moderator and final decision writer.
- Focus on the requested output format and surface uncertainties clearly.
"@
  return ($protocolText + $scientificRules)
}

function Test-SkippedReferencePath {
  param([string]$Path)

  $parts = @($Path -split '[\\/]')
  foreach ($part in $parts) {
    if ($part -in @(".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".cache")) {
      return $true
    }
  }

  return $false
}

function Get-ReferenceCandidates {
  param([string[]]$Paths)

  $candidates = [System.Collections.Generic.List[object]]::new()
  foreach ($path in @($Paths)) {
    if ([string]::IsNullOrWhiteSpace($path)) {
      continue
    }

    if (-not (Test-Path -LiteralPath $path)) {
      throw "Reference path does not exist: $(Redact-DiscussionText -Value $path)"
    }

    $resolved = (Resolve-Path -LiteralPath $path).Path
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
      if (-not (Test-SkippedReferencePath -Path $resolved)) {
        $candidates.Add([pscustomobject]@{ FullName = $resolved; SourceRoot = (Split-Path -Parent $resolved) })
      }
      continue
    }

    if (Test-Path -LiteralPath $resolved -PathType Container) {
      $files = Get-ChildItem -LiteralPath $resolved -File -Recurse -ErrorAction Stop |
        Where-Object { -not (Test-SkippedReferencePath -Path $_.FullName) } |
        Sort-Object FullName

      foreach ($file in $files) {
        $candidates.Add([pscustomobject]@{ FullName = $file.FullName; SourceRoot = $resolved })
      }
      continue
    }
  }

  return @($candidates)
}

function New-ReferenceSnapshot {
  param(
    [string]$DiscussionFolder,
    [string[]]$Paths,
    [int]$MaxFiles,
    [int]$MaxBytes,
    [string]$SnapshotCreatedAt
  )

  $candidates = @(Get-ReferenceCandidates -Paths $Paths)
  $referenceRecords = [System.Collections.Generic.List[object]]::new()
  if ($candidates.Count -eq 0) {
    return @()
  }
  if ($candidates.Count -gt $MaxFiles) {
    throw "Reference package contains $($candidates.Count) files, exceeding MaxReferenceFiles=$MaxFiles. Narrow ReferencePaths or raise the limit; Agent Workbench will not create a partial snapshot."
  }

  $referencesRoot = Join-Path $DiscussionFolder "references"
  $filesRoot = Join-Path $referencesRoot "files"
  New-Item -ItemType Directory -Force -Path $filesRoot | Out-Null

  $index = 0
  foreach ($candidate in $candidates) {
    $item = Get-Item -LiteralPath $candidate.FullName
    if ($item.Length -gt $MaxBytes) {
      throw "Reference file exceeds MaxReferenceFileBytes=$MaxBytes and would be omitted: $(Redact-DiscussionText -Value $item.Name)"
    }

    $index += 1
    $safeName = New-SafeFileStem -Value $item.BaseName
    $extension = $item.Extension
    if ([string]::IsNullOrWhiteSpace($extension)) {
      $extension = ".txt"
    }

    $snapshotName = ("ref-{0:D3}-{1}{2}" -f $index, $safeName, $extension.ToLowerInvariant())
    $snapshotRelativePath = "references/files/$snapshotName"
    $snapshotPath = Join-Path $filesRoot $snapshotName
    Copy-Item -LiteralPath $item.FullName -Destination $snapshotPath -Force
    $snapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
    $sourceLastWriteUtc = $item.LastWriteTimeUtc.ToString("o")

    $relativeSource = $item.Name
    try {
      $rootPath = [System.IO.Path]::GetFullPath($candidate.SourceRoot)
      $filePath = [System.IO.Path]::GetFullPath($item.FullName)
      if ($filePath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativeSource = $filePath.Substring($rootPath.Length).TrimStart("\", "/")
      }
    } catch {
      $relativeSource = $item.Name
    }

    $referenceRecords.Add([pscustomobject]@{
      id = ("ref-{0:D3}" -f $index)
      snapshot = $snapshotRelativePath
      source_name = (Redact-DiscussionText -Value $relativeSource)
      bytes = $item.Length
      sha256 = $snapshotHash
      source_last_write_utc = $sourceLastWriteUtc
    })
  }

  if ($referenceRecords.Count -eq 0) {
    Remove-Item -LiteralPath $referencesRoot -Recurse -Force -ErrorAction SilentlyContinue
    return @()
  }

  $manifestLines = [System.Collections.Generic.List[string]]::new()
  $manifestLines.Add("# Agent Discussion Reference Manifest")
  $manifestLines.Add("")
  $manifestLines.Add("Codex copied these user-authorized read-only snapshots into this discussion folder.")
  $manifestLines.Add("External agents should read the snapshot paths below instead of requesting original absolute paths.")
  $manifestLines.Add("")
  $manifestLines.Add("- snapshot_created_at: $SnapshotCreatedAt")
  $manifestLines.Add("- snapshot_semantics: frozen_copy")
  $manifestLines.Add("- freshness_rule: If source files changed after this snapshot was created, create a fresh Agent Workbench discussion with new ReferencePaths. Round 2 and RawReadOnlyRecovery stay on this frozen evidence package.")
  $manifestLines.Add("")
  $manifestLines.Add("| ID | Snapshot | Source Name | Bytes | SHA-256 | Source Last Write UTC |")
  $manifestLines.Add("|---|---|---|---|---|---|")
  foreach ($record in $referenceRecords) {
    $manifestLines.Add("| $($record.id) | $($record.snapshot) | $($record.source_name) | $($record.bytes) | $($record.sha256) | $($record.source_last_write_utc) |")
  }

  Set-Content -LiteralPath (Join-Path $referencesRoot "manifest.md") -Value ($manifestLines -join [Environment]::NewLine) -Encoding UTF8
  return @($referenceRecords)
}

function Get-EvidenceBundleId {
  param([object[]]$ReferenceRecords)

  if ($ReferenceRecords.Count -eq 0) {
    return ""
  }

  $orderedHashes = @($ReferenceRecords | ForEach-Object { $_.sha256 }) -join "`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($orderedHashes)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    return -join ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
  } finally {
    $sha256.Dispose()
  }
}

if ($RemainingArguments.Count -gt 0) {
  if ($ReferencePaths.Count -eq 0) {
    throw "Unexpected extra arguments: $($RemainingArguments -join ', '). Use named parameters or hashtable splatting."
  }

  foreach ($argument in $RemainingArguments) {
    if ($argument.StartsWith("-")) {
      throw "Unexpected extra named argument: $argument. Check parameter spelling."
    }
  }

  $ReferencePaths = @($ReferencePaths) + @($RemainingArguments)
}

$unknownReviewerLenses = @(
  $ReviewerLenses.Keys |
    ForEach-Object {
      $reviewerName = [string]$_
      if ($allAgents -notcontains $reviewerName) {
        Redact-DiscussionText -Value $reviewerName
      }
    } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object
)
if ($unknownReviewerLenses.Count -gt 0) {
  throw "ReviewerLenses contains reviewer(s) not present in Agents or OptionalAgents: $($unknownReviewerLenses -join ', ')."
}

$safeSlug = New-SafeSlug -Value (Redact-DiscussionSlug -Value $Slug)
$discussionsRoot = Join-Path $WorkbenchRoot "discussions"
New-Item -ItemType Directory -Force -Path $discussionsRoot | Out-Null

for ($attempt = 0; $attempt -lt 10; $attempt += 1) {
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $discussionId = "$timestamp-$suffix-$safeSlug"
  $discussionFolder = Join-Path $discussionsRoot $discussionId
  if (-not (Test-Path -LiteralPath $discussionFolder)) {
    New-Item -ItemType Directory -Path $discussionFolder | Out-Null
    break
  }
}

if (-not (Test-Path -LiteralPath $discussionFolder -PathType Container)) {
  throw "Could not create a unique discussion folder."
}

New-Item -ItemType Directory -Force -Path (Join-Path $discussionFolder "round1") | Out-Null
if ($MaxRounds -eq 2) {
  New-Item -ItemType Directory -Force -Path (Join-Path $discussionFolder "round2") | Out-Null
}

$createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$referenceRecords = @(New-ReferenceSnapshot -DiscussionFolder $discussionFolder -Paths $ReferencePaths -MaxFiles $MaxReferenceFiles -MaxBytes $MaxReferenceFileBytes -SnapshotCreatedAt $createdAt)
$evidenceBundleId = Get-EvidenceBundleId -ReferenceRecords $referenceRecords

$safeTopic = Redact-DiscussionText -Value $Topic
$safeQuestion = Redact-DiscussionText -Value $Question
$safeContext = Redact-DiscussionText -Value $Context
$safeMode = Redact-DiscussionText -Value $Mode
$safeProtocol = Redact-DiscussionText -Value $Protocol
$safeRequiredAgents = @($Agents | ForEach-Object { Redact-DiscussionText -Value $_ })
$safeOptionalAgents = @($OptionalAgents | ForEach-Object { Redact-DiscussionText -Value $_ })
$safeAgents = @($allAgents | ForEach-Object { Redact-DiscussionText -Value $_ })
$agentFileStems = @($allAgents | ForEach-Object { New-SafeFileStem -Value $_ })
$safeReviewerLenses = [ordered]@{}
foreach ($agent in $allAgents) {
  if ($ReviewerLenses.ContainsKey($agent)) {
    $safeReviewerLenses[(Redact-DiscussionText -Value $agent)] = Redact-DiscussionText -Value ([string]$ReviewerLenses[$agent])
  }
}

if ($ExpectedSections.Count -gt 0) {
  $normalizedSections = @($ExpectedSections | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $safeExpectedOutputFormat = Redact-DiscussionText -Value (New-FeedbackFormatFromSections -Sections $normalizedSections)
  $expectedOutputSource = "sections"
  $expectedOutputSections = @($normalizedSections)
  $expectedOutputInstructions = ""
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedOutputFormat)) {
  $proseFormat = ConvertFrom-ProseExpectedFormat -Format $ExpectedOutputFormat
  if ($null -ne $proseFormat) {
    $safeExpectedOutputFormat = Redact-DiscussionText -Value $proseFormat.Format
    $expectedOutputSource = "custom_normalized"
    $expectedOutputSections = @($proseFormat.Sections)
    $expectedOutputInstructions = Redact-DiscussionText -Value $proseFormat.Instructions
  } else {
    $safeExpectedOutputFormat = Redact-DiscussionText -Value $ExpectedOutputFormat
    $expectedOutputSource = "custom"
    $expectedOutputSections = @(Get-FeedbackSectionsFromFormat -Format $safeExpectedOutputFormat)
    $expectedOutputInstructions = ""
  }
} else {
  $safeExpectedOutputFormat = Redact-DiscussionText -Value (Get-ModeOutputFormat -SelectedMode $Mode)
  if ($Mode -eq "general") {
    $expectedOutputSource = "default"
  } else {
    $expectedOutputSource = "mode"
  }
  $expectedOutputSections = @(Get-FeedbackSectionsFromFormat -Format $safeExpectedOutputFormat)
  $expectedOutputInstructions = ""
}

$discussionProtocolText = Get-DiscussionProtocolText -SelectedProtocol $Protocol -SelectedMaxRounds $MaxRounds -SelectedMode $Mode -SelectedAuditProfile $AuditProfile
$scientificAuditContract = if ($AuditProfile -eq "scientific") { Get-ScientificAuditContract -SelectedMode $Mode } else { "" }

if ($referenceRecords.Count -gt 0) {
  $referenceManifest = "references/manifest.md"
  $referenceSection = @"
## Reference Snapshots

Codex copied user-authorized read-only snapshots into this discussion folder at $createdAt.

Read references/manifest.md first, then read the listed snapshot files under references/files/.
Use these snapshots instead of original absolute paths or repository access.
These snapshots are frozen evidence for this discussion. Round 2 and RawReadOnlyRecovery continue to use the same frozen snapshots.
If the original source files changed after this discussion was created, Codex must create a fresh discussion with new ReferencePaths instead of treating this folder as a current-source re-review.
"@
} else {
  $referenceManifest = ""
  $referenceSection = @"
## Reference Snapshots

No reference snapshots were provided.
"@
}

if ($safeAgents.Count -gt 0) {
  $agentLines = [System.Collections.Generic.List[string]]::new()
  foreach ($agent in $safeRequiredAgents) { $agentLines.Add("- required: $agent") }
  foreach ($agent in $safeOptionalAgents) { $agentLines.Add("- optional: $agent") }
  $agentsMarkdown = $agentLines -join [Environment]::NewLine
} else {
  $agentsMarkdown = "- none specified"
}

if ($safeReviewerLenses.Count -gt 0) {
  $reviewerLensMarkdown = ($safeReviewerLenses.GetEnumerator() | ForEach-Object { "- $($_.Key): $($_.Value)" }) -join [Environment]::NewLine
  $reviewerLensSection = @"
## Reviewer Lenses

$reviewerLensMarkdown
"@
} else {
  $reviewerLensSection = ""
}

$auditProfileMetadata = if ($AuditProfile -eq "scientific") { "- audit_profile: scientific" } else { "" }

$expectedOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($agentStem in $agentFileStems) {
  $expectedOutputs.Add("round1/$agentStem.md")
}
$expectedOutputs.Add("codex-synthesis.md")
if ($MaxRounds -eq 2) {
  foreach ($agentStem in $agentFileStems) {
    $expectedOutputs.Add("round2/$agentStem.md")
  }
}
$expectedOutputs.Add("decision.md")

$briefMd = @"
# Agent Discussion Brief

- discussion_id: $discussionId
- created_at: $createdAt
- max_rounds: $MaxRounds
- mode: $safeMode
- protocol: $safeProtocol
$auditProfileMetadata

## Topic

$safeTopic

## Question

$safeQuestion

## Context

$safeContext

## Agents

$agentsMarkdown

$reviewerLensSection

$referenceSection

$discussionProtocolText

$scientificAuditContract

## Expected Output Format

External agents should write Markdown feedback to their assigned round file:

~~~markdown
$safeExpectedOutputFormat
~~~

## Safety Rules

- Do not print API keys, provider configuration, or local absolute paths.
- Do not launch external agents from this discussion folder.
- Do not create worktrees.
- Do not edit repository files during discussion mode.
- Codex remains the moderator and final decision writer.
"@

$status = [ordered]@{
  discussion_id = $discussionId
  state = "created"
  topic = $safeTopic
  max_rounds = $MaxRounds
  current_round = 1
  mode = $safeMode
  protocol = $safeProtocol
  audit_profile = $AuditProfile
  reviewer_lenses = $safeReviewerLenses
  expected_output_source = $expectedOutputSource
  expected_output_format = $safeExpectedOutputFormat
  expected_output_sections = @($expectedOutputSections)
  expected_output_instructions = $expectedOutputInstructions
  reference_manifest = $referenceManifest
  reference_count = $referenceRecords.Count
  reference_snapshot_created_at = $(if ($referenceRecords.Count -gt 0) { $createdAt } else { "" })
  reference_snapshot_semantics = $(if ($referenceRecords.Count -gt 0) { "frozen_copy" } else { "none" })
  reference_freshness_rule = $(if ($referenceRecords.Count -gt 0) { "Source changes after discussion creation require a fresh discussion with new ReferencePaths. Round 2 and RawReadOnlyRecovery stay on frozen snapshots." } else { "" })
  reference_files = @($referenceRecords | ForEach-Object { $_.snapshot })
  reference_records = @($referenceRecords)
  evidence_bundle_id = $evidenceBundleId
  agents = @($safeAgents)
  required_agents = @($safeRequiredAgents)
  optional_agents = @($safeOptionalAgents)
  expected_outputs = @($expectedOutputs)
  flags = @()
}

Set-Content -LiteralPath (Join-Path $discussionFolder "brief.md") -Value $briefMd -Encoding UTF8
ConvertTo-Json -InputObject $status -Depth 5 | Set-Content -LiteralPath (Join-Path $discussionFolder "status.json") -Encoding UTF8

$runLog = "[$createdAt] created discussion_id=$discussionId topic=""$safeTopic"" max_rounds=$MaxRounds agents=$($safeAgents -join ',')"
Set-Content -LiteralPath (Join-Path $discussionFolder "run.log") -Value (Redact-DiscussionText -Value $runLog) -Encoding UTF8

foreach ($name in @("codex-synthesis.md", "user-decision-needed.md", "decision.md")) {
  Set-Content -LiteralPath (Join-Path $discussionFolder $name) -Value "" -Encoding UTF8
}

Write-Output $discussionFolder
