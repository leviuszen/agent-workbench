$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert($Condition, $Message) {
  if (-not $Condition) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\Collect-AgentResult.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-workbench-collect-test-" + [guid]::NewGuid().ToString("N"))
$providerKeyName = ("ANTHROPIC" + "_API_KEY")
$deepseekHost = ("api." + "deepseek.com")
$openAiKeyName = ("OPENAI" + "_API_KEY")
$deepSeekKeyName = ("DEEPSEEK" + "_API_KEY")
$genericTokenName = ("MY_VENDOR" + "_ACCESS_TOKEN")
$genericSecretName = ("SOME" + "_SECRET_KEY")
$mixedCaseDeepseekHost = ("API." + "DeepSeek.COM/v1")

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

  Set-Content -LiteralPath (Join-Path $tempRoot "result.md") -Value "# Result`n`nDone but failed during validation. Token sk-testSecret1234567890. $providerKeyName=abc123. $openAiKeyName=op-test-secret-123. $deepSeekKeyName=deepseek-secret-456. Endpoint $deepseekHost. Mixed endpoint $mixedCaseDeepseekHost. Path Z:\collector-secret\secret.txt" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $tempRoot "review.md") -Value "# Review`n`nLooks bounded. $providerKeyName xyz789. $genericTokenName=vendor-token-789. UNC \\server\share\secret.txt" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $tempRoot "codex-final.md") -Value "# Final`n`nSafe summary remains. Token sk-finalSecret1234567890. $genericSecretName secret-value-abc." -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $tempRoot "patch.diff") -Value "diff --git a/a b/a" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $tempRoot "status.json") -Value '{ "state": "result_available" }' -Encoding UTF8

  $patchPath = Join-Path $tempRoot "patch.diff"
  $bugsPath = Join-Path $tempRoot "bugs"
  $output = & $scriptPath -TaskFolder $tempRoot | Out-String

  Assert ($output.Contains("result.md: present")) "Expected result.md status."
  Assert ($output.Contains("review.md: present")) "Expected review.md status."
  Assert ($output.Contains("patch.diff: present")) "Expected patch.diff status."
  Assert ($output.Contains("Done but failed during validation.")) "Expected result content."
  Assert ($output.Contains("Looks bounded.")) "Expected review content."
  Assert ($output.Contains("Safe summary remains.")) "Expected codex-final content."
  Assert ($output.Contains($patchPath)) "Expected patch.diff path."
  Assert ($output.Contains("Potential bug signal detected. Register with New-AgentBug.ps1 if this is a concrete defect.")) "Expected bug signal note."
  Assert (-not (Test-Path -LiteralPath $bugsPath)) "Collect-AgentResult.ps1 should not create a bugs folder."
  Assert ($output -notmatch "sk-") "Collector output leaked sk- secret-like content."
  Assert (-not $output.Contains($providerKeyName)) "Collector output leaked provider env var name."
  Assert (-not $output.Contains($openAiKeyName)) "Collector output leaked OpenAI env var name."
  Assert (-not $output.Contains("op-test-secret-123")) "Collector output leaked OpenAI env var value."
  Assert (-not $output.Contains($deepSeekKeyName)) "Collector output leaked DeepSeek env var name."
  Assert (-not $output.Contains("deepseek-secret-456")) "Collector output leaked DeepSeek env var value."
  Assert (-not $output.Contains($genericTokenName)) "Collector output leaked generic access token name."
  Assert (-not $output.Contains("vendor-token-789")) "Collector output leaked generic access token value."
  Assert (-not $output.Contains($genericSecretName)) "Collector output leaked generic secret key name."
  Assert (-not $output.Contains("secret-value-abc")) "Collector output leaked generic secret key value."
  Assert ($output -notmatch "(?i)api\.deepseek") "Collector output leaked DeepSeek endpoint."
  Assert ($output -notmatch "Z:\\collector-secret") "Collector output leaked drive absolute path from collected content."
  Assert ($output -notmatch "\\\\server\\share") "Collector output leaked UNC absolute path."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
