function Resolve-ClaudeCodeExecutable {
  param(
    [AllowEmptyString()][string]$ExplicitPath = ""
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
      throw "Explicit ClaudeExe does not exist: $ExplicitPath"
    }

    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

  $candidates = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CODE_EXE)) {
    $candidates.Add($env:CLAUDE_CODE_EXE)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
    $candidates.Add((Join-Path $env:APPDATA "npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe"))
  }

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  foreach ($commandName in @("claude.exe", "claude.cmd", "claude.ps1", "claude")) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source)) {
      return $command.Source
    }
  }

  throw "Claude Code executable was not found. Install @anthropic-ai/claude-code, add claude to PATH, set CLAUDE_CODE_EXE, or pass -ClaudeExe explicitly."
}
