---
name: agent-bug
description: Register concrete Agent Workbench bug ledger entries with evidence-first records.
---

# Agent Bug

Use this skill when Codex needs to record a concrete bug found during Agent Workbench work, external-agent review, result collection, dry runs, tests, or manual inspection.

## When To Record

- A test fails and the failure is not immediately fixed in the same step.
- External review reports a concrete defect with evidence.
- `Collect-AgentResult.ps1` shows a blocking issue or bug-like signal that Codex confirms is a real defect.
- A manual dry run reveals a repeatable failure.

## Rules

- Codex remains the primary conversation and final reviewer.
- Prefer evidence over interpretation: include command output, file paths, reproduction steps, and expected versus actual behavior.
- Keep each bug record focused on one defect.
- Do not record vague, duplicate, or secret-containing entries.
- Do not paste API keys, provider config, tokens, private launcher contents, or secret-like text into bug fields.
- Do not treat result collection warnings as automatic bugs; Codex decides whether to register one.

## Create A Bug

Run `New-AgentBug.ps1` from the installed workbench scripts:

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
& (Join-Path $WorkbenchRoot "scripts\New-AgentBug.ps1") `
-WorkbenchRoot $WorkbenchRoot `
  -Slug "short-bug-slug" `
  -Severity medium `
  -Source codex `
  -Summary "Short concrete bug summary." `
  -Evidence "Relevant command output, file reference, or review evidence." `
  -Reproduction "Steps or command that triggers the issue." `
  -ExpectedBehavior "What should have happened." `
  -ActualBehavior "What happened instead." `
  -SuggestedFix "Optional focused fix direction."
```

Use the narrowest accurate `Severity` and `Source` values supported by the script.

## Collect Bugs

Summarize the current ledger:

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
& (Join-Path $WorkbenchRoot "scripts\Collect-AgentBugs.ps1") `
-WorkbenchRoot $WorkbenchRoot
```

Filter by state when needed:

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
& (Join-Path $WorkbenchRoot "scripts\Collect-AgentBugs.ps1") `
-WorkbenchRoot $WorkbenchRoot `
  -State open
```

## Review Contract

Before acting on a bug entry, Codex should review the evidence, decide whether the entry is valid, and choose whether to fix, block, close as `wontfix`, or ask for more information.
