[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$DiscussionFolder,
  [string[]]$RequiredBasenames = @(),
  [switch]$PassThru
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $DiscussionFolder -PathType Container)) {
  throw "DiscussionFolder does not exist: $DiscussionFolder"
}

$resolvedFolder = (Resolve-Path -LiteralPath $DiscussionFolder).Path
$statusPath = Join-Path $resolvedFolder "status.json"
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw "Reference completeness gate requires status.json."
}

$status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
$referenceCount = if ($status.PSObject.Properties.Name -contains "reference_count") { [int]$status.reference_count } else { 0 }
if ($referenceCount -eq 0) {
  if ($RequiredBasenames.Count -gt 0) {
    throw "Reference completeness gate failed: required references were requested but this discussion has no frozen snapshots."
  }
  if ($PassThru) { Write-Output ([pscustomobject]@{ Valid = $true; Count = 0; EvidenceBundleId = "" }) }
  return
}

$manifestPath = Join-Path $resolvedFolder "references\manifest.md"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Reference completeness gate failed: references/manifest.md is missing."
}

$records = @()
if ($status.PSObject.Properties.Name -contains "reference_records") {
  $records = @($status.reference_records)
}

if ($records.Count -eq 0) {
  foreach ($line in (Get-Content -LiteralPath $manifestPath -Encoding UTF8)) {
    if ($line -match '^\|\s*(ref-\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*([A-Fa-f0-9]{64})\s*\|') {
      $records += [pscustomobject]@{
        id = $Matches[1]
        snapshot = $Matches[2].Trim()
        source_name = $Matches[3].Trim()
        bytes = [int64]$Matches[4]
        sha256 = $Matches[5].ToUpperInvariant()
      }
    }
  }
}

if ($records.Count -ne $referenceCount) {
  throw "Reference completeness gate failed: status expects $referenceCount snapshot(s), manifest describes $($records.Count)."
}

$listedRelativePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$sourceBasenames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$orderedHashes = [System.Collections.Generic.List[string]]::new()
foreach ($record in $records) {
  $relativePath = ([string]$record.snapshot).Replace("/", "\")
  if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath.Contains("..") -or [System.IO.Path]::IsPathRooted($relativePath)) {
    throw "Reference completeness gate failed: unsafe snapshot path in manifest."
  }
  if (-not $listedRelativePaths.Add($relativePath)) {
    throw "Reference completeness gate failed: duplicate snapshot path '$relativePath'."
  }

  $snapshotPath = Join-Path $resolvedFolder $relativePath
  if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
    throw "Reference completeness gate failed: snapshot file is missing: $relativePath"
  }

  $item = Get-Item -LiteralPath $snapshotPath
  if ([int64]$record.bytes -ne $item.Length) {
    throw "Reference completeness gate failed: byte count changed for $relativePath"
  }
  $actualHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
  if (-not $actualHash.Equals([string]$record.sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Reference completeness gate failed: SHA-256 changed for $relativePath"
  }
  $orderedHashes.Add($actualHash)
  [void]$sourceBasenames.Add((Split-Path -Leaf ([string]$record.source_name)))
}

$filesRoot = Join-Path $resolvedFolder "references\files"
$actualRelativePaths = @()
if (Test-Path -LiteralPath $filesRoot -PathType Container) {
  $actualRelativePaths = @(Get-ChildItem -LiteralPath $filesRoot -File | ForEach-Object { "references\files\$($_.Name)" })
}
if ($actualRelativePaths.Count -ne $records.Count) {
  throw "Reference completeness gate failed: references/files contains $($actualRelativePaths.Count) file(s), expected $($records.Count)."
}
foreach ($relativePath in $actualRelativePaths) {
  if (-not $listedRelativePaths.Contains($relativePath)) {
    throw "Reference completeness gate failed: unlisted snapshot file '$relativePath'."
  }
}

foreach ($required in @($RequiredBasenames)) {
  $basename = Split-Path -Leaf $required
  if (-not $sourceBasenames.Contains($basename)) {
    throw "Reference completeness gate failed: required source basename '$basename' is absent from the frozen package."
  }
}

$bundleInput = $orderedHashes -join "`n"
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $bundleId = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($bundleInput)) | ForEach-Object { $_.ToString("x2") })
} finally {
  $sha.Dispose()
}
if (($status.PSObject.Properties.Name -contains "evidence_bundle_id") -and
    -not [string]::IsNullOrWhiteSpace([string]$status.evidence_bundle_id) -and
    -not $bundleId.Equals([string]$status.evidence_bundle_id, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Reference completeness gate failed: evidence_bundle_id does not match the frozen snapshot hashes."
}

if ($PassThru) {
  Write-Output ([pscustomobject]@{ Valid = $true; Count = $records.Count; EvidenceBundleId = $bundleId })
}
