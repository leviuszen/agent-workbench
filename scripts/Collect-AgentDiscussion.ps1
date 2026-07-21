param(
  [Parameter(Mandatory = $true)][string]$DiscussionFolder
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Redact-DiscussionCollectionText {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  $providerKeyPattern = "\b(?:ANTHROPIC_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|QWEN_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|AZURE_OPENAI_API_KEY|OPENROUTER_API_KEY|XAI_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|COHERE_API_KEY|PERPLEXITY_API_KEY|[A-Z][A-Z0-9_]*(?:API_KEY|API_TOKEN|ACCESS_TOKEN|SECRET_KEY))\b(?:\s*[:=]\s*|\s+)?[^\s`"'<>()\[\]]*"
  $redacted = $Value -replace "sk-[A-Za-z0-9_-]{8,}", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)$providerKeyPattern", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "(?i)\bapi\.deepseek[^\s`"'<>()\[\]]*", "[REDACTED_SECRET]"
  $redacted = $redacted -replace "[A-Za-z]:[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "\\\\[^\\/\s]+[\\/][^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  $redacted = $redacted -replace "(?:/Users|/home|/mnt|/Volumes)/[^\s`"'<>()\[\]]+", "[REDACTED_PATH]"
  return $redacted
}

function Get-DiscussionSignalNames {
  param([AllowNull()][string]$Content)

  $signals = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Content) {
    return @()
  }

  if ($Content -match '(?i)(disagree|conflict|\u5206\u6b67|\u4e0d\u540c\u610f|\u4e89\u8bae)') {
    $signals.Add("disagreement")
  }
  if ($Content -match '(?i)(blocked|blocker|\u65e0\u6cd5\u7ee7\u7eed|\u963b\u585e)') {
    $signals.Add("blocker")
  }
  if ($Content -match '(?i)(critical|major risk|\u9ad8\u98ce\u9669|\u91cd\u5927\u98ce\u9669)') {
    $signals.Add("risk")
  }

  return @($signals)
}

function ConvertTo-SafeAgentFileStem {
  param([string]$Value)

  $safe = $Value.ToLowerInvariant() -replace "[^a-z0-9_-]+", "-"
  $safe = $safe.Trim("-")
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "discussion"
  }

  return $safe
}

function Get-ExpectedReviewerFeedback {
  param(
    [string]$Folder,
    [string]$RoundName,
    [object[]]$ExpectedReviewers
  )

  $roundPath = Join-Path $Folder $RoundName
  if (-not (Test-Path -LiteralPath $roundPath -PathType Container)) {
    return @()
  }

  return @($ExpectedReviewers | ForEach-Object {
    $feedbackPath = Join-Path $roundPath $_.FileName
    if (Test-Path -LiteralPath $feedbackPath -PathType Leaf) {
      [pscustomobject]@{
        Agent = $_.Agent
        FileName = $_.FileName
        FullName = $feedbackPath
      }
    }
  })
}

function Get-ContentExcerpt {
  param([string]$Content)

  $singleLine = ($Content -replace "\s+", " ").Trim()
  if ($singleLine.Length -le 500) {
    return $singleLine
  }

  return $singleLine.Substring(0, 500) + "..."
}

function Get-ScientificDiscussionFindings {
  param(
    [string]$DiscussionId,
    [object[]]$RoundFiles
  )

  $findings = [System.Collections.Generic.List[object]]::new()
  $fieldNames = [ordered]@{
    "Area" = "area"
    "Claim" = "claim"
    "Severity" = "severity"
    "Evidence" = "evidence"
    "Confidence" = "confidence"
    "Counter-evidence" = "counter_evidence"
    "Recommended action" = "recommended_action"
    "Blocking" = "blocking"
    "Claim type" = "claim_type"
    "Falsifier" = "falsifier"
    "Minimum validation" = "minimum_validation"
  }
  $fieldPattern = "^\s*-\s*(" + (($fieldNames.Keys | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")\s*:\s*(.*)$"

  foreach ($file in $RoundFiles) {
    $seenFindingIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $currentFindingId = ""
    $currentFields = $null
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($line in ($content -split "`r?`n")) {
      if ($line -match "^### Finding\s+(.+?)\s*$") {
        $nextFindingId = $Matches[1].Trim()
        if (-not $seenFindingIds.Add($nextFindingId)) {
          throw "Duplicate scientific finding id '$nextFindingId' for reviewer '$($file.Agent)' in $($file.Round)/$($file.FileName)."
        }
        if (-not [string]::IsNullOrWhiteSpace($currentFindingId)) {
          $record = [ordered]@{
            discussion_id = $DiscussionId
            round = $file.Round
            reviewer = $file.Agent
            finding_id = $currentFindingId
            source_file = ($file.Round + "/" + $file.FileName)
          }
          foreach ($fieldName in $fieldNames.Values) {
            $record[$fieldName] = [string]$currentFields[$fieldName]
          }
          $findings.Add([pscustomobject]$record)
        }
        $currentFindingId = $nextFindingId
        $currentFields = @{}
        foreach ($fieldName in $fieldNames.Values) {
          $currentFields[$fieldName] = ""
        }
        continue
      }

      if (($null -ne $currentFields) -and ($line -match $fieldPattern)) {
        $normalizedFieldName = $fieldNames[$Matches[1]]
        $currentFields[$normalizedFieldName] = $Matches[2].Trim()
      }
    }

    if (-not [string]::IsNullOrWhiteSpace($currentFindingId)) {
      $record = [ordered]@{
        discussion_id = $DiscussionId
        round = $file.Round
        reviewer = $file.Agent
        finding_id = $currentFindingId
        source_file = ($file.Round + "/" + $file.FileName)
      }
      foreach ($fieldName in $fieldNames.Values) {
        $record[$fieldName] = [string]$currentFields[$fieldName]
      }
      $findings.Add([pscustomobject]$record)
    }
  }

  return @($findings)
}

function Write-ScientificDiscussionArtifacts {
  param(
    [string]$DiscussionFolder,
    [object]$Status,
    [object[]]$RoundFiles
  )

  if (-not (($Status.PSObject.Properties.Name -contains "audit_profile") -and ([string]$Status.audit_profile -eq "scientific"))) {
    return
  }

  $discussionId = Split-Path -Leaf $DiscussionFolder
  $findings = @(Get-ScientificDiscussionFindings -DiscussionId $discussionId -RoundFiles $RoundFiles)
  $serializedFindings = @($findings | ForEach-Object { $_ | ConvertTo-Json -Depth 4 -Compress })
  $findingsJson = "[" + ($serializedFindings -join ",") + "]"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText((Join-Path $DiscussionFolder "findings.json"), $findingsJson + [Environment]::NewLine, $utf8NoBom)

  $matrix = [System.Collections.Generic.List[string]]::new()
  $matrix.Add("# Scientific Finding Disagreement Matrix")
  $matrix.Add("")
  $matrix.Add("| Discussion | Round | Reviewer | Finding | Severity | Disposition |")
  $matrix.Add("| --- | --- | --- | --- | --- | --- |")
  foreach ($finding in $findings) {
    $matrix.Add("| $($finding.discussion_id) | $($finding.round) | $($finding.reviewer) | $($finding.finding_id) | $($finding.severity) | pending_codex |")
  }
  [System.IO.File]::WriteAllText((Join-Path $DiscussionFolder "disagreement-matrix.md"), ($matrix -join [Environment]::NewLine) + [Environment]::NewLine, $utf8NoBom)
}

if ([string]::IsNullOrWhiteSpace($DiscussionFolder)) {
  throw "DiscussionFolder is required."
}

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) {
  throw "DiscussionFolder does not exist: $DiscussionFolder"
}

$resolvedDiscussionFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$statusPath = Join-Path $resolvedDiscussionFolder "status.json"
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw "status.json does not exist: $statusPath"
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
$requiredAgentNames = @()
$optionalAgentNames = @()
if ($status.PSObject.Properties.Name -contains "required_agents") {
  $requiredAgentNames = @($status.required_agents)
} elseif ($status.PSObject.Properties.Name -contains "agents") {
  $requiredAgentNames = @($status.agents)
}
if ($status.PSObject.Properties.Name -contains "optional_agents") {
  $optionalAgentNames = @($status.optional_agents)
}
$allAgentNames = @($requiredAgentNames + $optionalAgentNames | Select-Object -Unique)
$expectedReviewers = @()
if ($allAgentNames.Count -gt 0) {
  $expectedReviewers = @($allAgentNames | ForEach-Object {
    $agent = [string]$_
    [pscustomobject]@{
      Agent = $agent
      FileName = (ConvertTo-SafeAgentFileStem -Value $agent) + ".md"
    }
  })
}
$coreFiles = @(
  "brief.md",
  "status.json",
  "run.log",
  "codex-synthesis.md",
  "user-decision-needed.md",
  "decision.md"
)
$round1Files = @(Get-ExpectedReviewerFeedback -Folder $resolvedDiscussionFolder -RoundName "round1" -ExpectedReviewers $expectedReviewers | ForEach-Object { $_ | Add-Member -NotePropertyName "Round" -NotePropertyValue "round1" -PassThru })
$round2Files = @(Get-ExpectedReviewerFeedback -Folder $resolvedDiscussionFolder -RoundName "round2" -ExpectedReviewers $expectedReviewers | ForEach-Object { $_ | Add-Member -NotePropertyName "Round" -NotePropertyValue "round2" -PassThru })
$round1CompletedAgents = @($round1Files | ForEach-Object { $_.Agent })
$round2CompletedAgents = @($round2Files | ForEach-Object { $_.Agent })
$round1MissingAgents = @($requiredAgentNames | Where-Object { $_ -notin $round1CompletedAgents })
$round2MissingAgents = @($requiredAgentNames | Where-Object { $_ -notin $round2CompletedAgents })
$round1MissingOptionalAgents = @($optionalAgentNames | Where-Object { $_ -notin $round1CompletedAgents })
$round2MissingOptionalAgents = @($optionalAgentNames | Where-Object { $_ -notin $round2CompletedAgents })
$signals = [System.Collections.Generic.List[string]]::new()

Write-Output "# Agent Discussion Collection"
Write-Output ""
Write-Output ("Discussion folder: " + (Redact-DiscussionCollectionText -Value $resolvedDiscussionFolder))
Write-Output ""
Write-Output "## File Status"

foreach ($fileName in $coreFiles) {
  $path = Join-Path $resolvedDiscussionFolder $fileName
  $state = if (Test-Path -LiteralPath $path -PathType Leaf) { "present" } else { "missing" }
  Write-Output "${fileName}: $state"
}

foreach ($roundName in @("round1", "round2")) {
  $path = Join-Path $resolvedDiscussionFolder $roundName
  $state = if (Test-Path -LiteralPath $path -PathType Container) { "present" } else { "missing" }
  Write-Output "${roundName}/: $state"
}

Write-Output ""
Write-Output "## Counts"
Write-Output "round1_count: $($round1Files.Count)"
Write-Output "round2_count: $($round2Files.Count)"

foreach ($roundInfo in @(
  [pscustomobject]@{ Name = "round1"; Files = $round1Files },
  [pscustomobject]@{ Name = "round2"; Files = $round2Files }
)) {
  Write-Output ""
  Write-Output "## $($roundInfo.Name) Feedback"

  if ($roundInfo.Files.Count -eq 0) {
    Write-Output "No feedback files found."
    continue
  }

  foreach ($file in $roundInfo.Files) {
    $rawContent = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($signal in (Get-DiscussionSignalNames -Content $rawContent)) {
      if (-not $signals.Contains($signal)) {
        $signals.Add($signal)
      }
    }

    Write-Output ""
    $safeFileName = Redact-DiscussionCollectionText -Value $file.FileName
    Write-Output "### $($roundInfo.Name)/$safeFileName"
    Write-Output (Redact-DiscussionCollectionText -Value (Get-ContentExcerpt -Content $rawContent))
  }
}

$escalationPath = Join-Path $resolvedDiscussionFolder "user-decision-needed.md"
$decisionPath = Join-Path $resolvedDiscussionFolder "decision.md"
$synthesisPath = Join-Path $resolvedDiscussionFolder "codex-synthesis.md"
$needsUserDecision = $false
if (Test-Path -LiteralPath $escalationPath -PathType Leaf) {
  $needsUserDecision = -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $escalationPath -Raw -Encoding UTF8))
}

$hasDecision = $false
if (Test-Path -LiteralPath $decisionPath -PathType Leaf) {
  $hasDecision = -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $decisionPath -Raw -Encoding UTF8))
}

$hasSynthesis = $false
if (Test-Path -LiteralPath $synthesisPath -PathType Leaf) {
  $hasSynthesis = -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $synthesisPath -Raw -Encoding UTF8))
}

$protocol = ""
if ($status.PSObject.Properties.Name -contains "protocol") {
  $protocol = [string]$status.protocol
}

$maxRounds = 2
if ($status.PSObject.Properties.Name -contains "max_rounds") {
  $maxRounds = [int]$status.max_rounds
}

if ($hasDecision) {
  $statusState = "decision_ready"
} elseif ($needsUserDecision) {
  $statusState = "needs_user_decision"
} elseif ($round1MissingAgents.Count -gt 0) {
  $statusState = "awaiting_round1_reviewers"
} elseif ($protocol -eq "adversarial-discussion" -and $maxRounds -eq 2) {
  if ($round2Files.Count -eq 0) {
    $statusState = "feedback_collected"
  } elseif ($round2MissingAgents.Count -gt 0) {
    $statusState = "awaiting_round2_reviewers"
  } elseif (-not $hasSynthesis) {
    $statusState = "awaiting_codex_synthesis"
  } else {
    $statusState = "needs_codex_decision"
  }
} elseif (($round1Files.Count + $round2Files.Count) -gt 0) {
  $statusState = "feedback_collected"
} else {
  $statusState = $status.state
}

if ($round2Files.Count -gt 0) {
  $currentRound = 2
} elseif ($round1Files.Count -gt 0) {
  $currentRound = 1
} elseif ($status.PSObject.Properties.Name -contains "current_round") {
  $currentRound = $status.current_round
} else {
  $currentRound = 1
}

$updatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$status | Add-Member -NotePropertyName "state" -NotePropertyValue $statusState -Force
$status | Add-Member -NotePropertyName "current_round" -NotePropertyValue $currentRound -Force
$status | Add-Member -NotePropertyName "round1_count" -NotePropertyValue $round1Files.Count -Force
$status | Add-Member -NotePropertyName "round2_count" -NotePropertyValue $round2Files.Count -Force
$status | Add-Member -NotePropertyName "round1_completed_agents" -NotePropertyValue @($round1CompletedAgents) -Force
$status | Add-Member -NotePropertyName "round1_missing_agents" -NotePropertyValue @($round1MissingAgents) -Force
$status | Add-Member -NotePropertyName "round2_completed_agents" -NotePropertyValue @($round2CompletedAgents) -Force
$status | Add-Member -NotePropertyName "round2_missing_agents" -NotePropertyValue @($round2MissingAgents) -Force
$status | Add-Member -NotePropertyName "round1_missing_optional_agents" -NotePropertyValue @($round1MissingOptionalAgents) -Force
$status | Add-Member -NotePropertyName "round2_missing_optional_agents" -NotePropertyValue @($round2MissingOptionalAgents) -Force
$status | Add-Member -NotePropertyName "signals" -NotePropertyValue @($signals) -Force
$status | Add-Member -NotePropertyName "updated_at" -NotePropertyValue $updatedAt -Force
$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statusPath -Encoding UTF8
Write-ScientificDiscussionArtifacts -DiscussionFolder $resolvedDiscussionFolder -Status $status -RoundFiles @($round1Files + $round2Files)

Write-Output ""
Write-Output "## Signals"
if ($signals.Count -eq 0) {
  Write-Output "none"
} else {
  foreach ($signal in $signals) {
    Write-Output $signal
  }
}

Write-Output ""
Write-Output "state: $statusState"
Write-Output "current_round: $currentRound"
Write-Output "updated_at: $updatedAt"
