$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\New-AgentTask.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-test-" + [guid]::NewGuid().ToString("N"))
$providerKeyName = ("ANTHROPIC" + "_API_KEY")
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function New-TestAgentTask {
  param(
    [string]$Slug = "hello-world",
    [string]$TargetAgent = "claude-code",
    [string]$Mode = "implementation",
    [string]$Task = "Implement a tiny hello-world change.",
    [string]$Context = "Allowed paths: none. This is a test."
  )

  & $scriptPath `
    -WorkbenchRoot $tempRoot `
    -Slug $Slug `
    -TargetAgent $TargetAgent `
    -Mode $Mode `
    -WorkspaceRoot $repoRoot `
    -Task $Task `
    -Context $Context
}

function Get-TaskFolders {
  $tasksRoot = Join-Path $tempRoot "tasks"
  Get-ChildItem -LiteralPath $tasksRoot -Directory | Sort-Object Name
}

function Read-Status {
  param([string]$TaskFolder)

  Get-Content -LiteralPath (Join-Path $TaskFolder "status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-ExpectedOutputs {
  param(
    [string]$TaskFolder,
    [string[]]$Expected
  )

  $statusJson = Get-Content -LiteralPath (Join-Path $TaskFolder "status.json") -Raw -Encoding UTF8
  Assert ($statusJson -match '"expected_outputs"\s*:\s*\[') "expected_outputs must be a JSON array."
  $Status = $statusJson | ConvertFrom-Json
  Assert ($Status.expected_outputs.Count -eq $Expected.Count) "Unexpected expected_outputs count."
  foreach ($name in $Expected) {
    Assert ($Status.expected_outputs -contains $name) "Missing expected output $name."
  }
}

function Assert-NoSecretLikeContent {
  param([string]$TaskFolder)

  foreach ($name in @("task.md", "context.md", "status.json", "run.log")) {
    $content = Get-Content -LiteralPath (Join-Path $TaskFolder $name) -Raw -Encoding UTF8
    Assert ($content -notmatch "sk-") "$name contains sk- secret-like content."
    Assert (-not $content.Contains($providerKeyName)) "$name contains provider env var name."
    Assert ($content -notmatch "api\.deepseek") "$name contains api.deepseek secret-like content."
  }
}

try {
  New-TestAgentTask | Out-Null

  $taskFolders = Get-TaskFolders
  Assert ($taskFolders.Count -eq 1) "Expected exactly one task folder."

  $taskFolder = $taskFolders[0].FullName
  foreach ($name in @("task.md", "context.md", "status.json", "run.log")) {
    Assert (Test-Path -LiteralPath (Join-Path $taskFolder $name)) "Missing $name."
  }

  $status = Read-Status -TaskFolder $taskFolder
  Assert ($status.target_agent -eq "claude-code") "Unexpected target_agent."
  Assert ($status.mode -eq "implementation") "Unexpected mode."
  Assert ($status.state -eq "created") "Unexpected state."
Assert-ExpectedOutputs -TaskFolder $taskFolder -Expected @("agent-result.md", "result.md", "patch.diff")

$reasonixTaskFolder = New-TestAgentTask -Slug "reasonix-worker" -TargetAgent "reasonix"
$reasonixStatus = Read-Status -TaskFolder $reasonixTaskFolder
Assert ($reasonixStatus.target_agent -eq "reasonix") "Reasonix should be accepted as a target_agent."
Assert-ExpectedOutputs -TaskFolder $reasonixTaskFolder -Expected @("agent-result.md", "result.md", "patch.diff")

  $reviewTaskFolder = New-TestAgentTask -Slug "review-mode" -Mode "review" -Task "Review only." -Context "Read-only review."
  $reviewStatus = Read-Status -TaskFolder $reviewTaskFolder
  Assert ($reviewStatus.mode -eq "review") "Unexpected review mode."
  Assert-ExpectedOutputs -TaskFolder $reviewTaskFolder -Expected @("review.md")

  $compareTaskFolder = New-TestAgentTask -Slug "compare-mode" -Mode "compare" -Task "Compare outputs." -Context "Use evidence."
  $compareStatus = Read-Status -TaskFolder $compareTaskFolder
  Assert ($compareStatus.mode -eq "compare") "Unexpected compare mode."
  Assert-ExpectedOutputs -TaskFolder $compareTaskFolder -Expected @("codex-final.md")

  New-TestAgentTask -Slug "rapid-same-slug" | Out-Null
  New-TestAgentTask -Slug "rapid-same-slug" | Out-Null
  $rapidFolders = Get-TaskFolders | Where-Object { $_.Name -match "rapid-same-slug$" }
  Assert ($rapidFolders.Count -eq 2) "Expected rapid same-slug tasks to create two distinct folders."
  Assert (($rapidFolders | Select-Object -ExpandProperty FullName -Unique).Count -eq 2) "Rapid same-slug task folders must be distinct."

  $secretSlugTaskFolder = New-TestAgentTask -Slug "sk-slugSecret1234567890"
  Assert ((Split-Path -Leaf $secretSlugTaskFolder) -notmatch "sk-") "Task folder name contains sk- from slug."
  Assert ($secretSlugTaskFolder -notmatch "sk-") "Task folder path contains sk- from slug."
  Assert-NoSecretLikeContent -TaskFolder $secretSlugTaskFolder

  $secretTaskFolder = New-TestAgentTask `
    -Slug "secret-redaction" `
    -Task "Token sk-testSecret1234567890 should not persist. $providerKeyName=abc123 and endpoint api.deepseek.com." `
    -Context "$providerKeyName`: xyz789 plus sk-anotherSecret123456 and api.deepseek.com."
  Assert-NoSecretLikeContent -TaskFolder $secretTaskFolder
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
