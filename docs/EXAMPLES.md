# Synthetic Examples

These examples use invented project names and content. Do not publish a real task folder, discussion folder, source snapshot, prompt, path, diff, or agent transcript without reviewing and redacting it first.

## Before You Start

Install Agent Workbench and configure at least one supported CLI agent:

```powershell
$env:AGENT_WORKBENCH_HOME = Join-Path $env:LOCALAPPDATA "AgentWorkbench"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AgentWorkbench.ps1
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
```

Claude Code can be resolved from `CLAUDE_CODE_EXE`, npm, `PATH`, or `-ClaudeExe`. Reasonix can be resolved from `REASONIX_COMMAND`, `PATH`, or `-ReasonixCommand`. Close Reasonix Desktop before a non-interactive Reasonix CLI run so the Desktop does not retain a session lock.

## Example 1: Dual Review Of A Design Note

This example asks two reviewers to inspect the same frozen evidence independently. It does not grant either reviewer authority to accept the proposal.

### 1. Create The Discussion

```powershell
$ReferenceFile = (Resolve-Path ".\examples\sample-design-note.md").Path
$params = @{
  WorkbenchRoot = $WorkbenchRoot
  Slug = "cache-policy-review"
  Topic = "Review a cache invalidation proposal"
  Question = "Which assumptions could make this proposal fail in production?"
  Context = "Use only the frozen reference snapshot. Do not edit source files."
  Mode = "strategy-review"
  Protocol = "adversarial-discussion"
  AuditProfile = "scientific"
  MaxRounds = 2
  Agents = @("claude-code", "reasonix")
  ReferencePaths = @($ReferenceFile)
  ReviewerLenses = @{
    "claude-code" = "implementation feasibility and hidden coupling"
    "reasonix" = "evidence quality and falsification"
  }
}

$DiscussionFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentDiscussion.ps1") @params
```

The discussion now contains `brief.md`, `status.json`, two empty round folders, moderator files, and a frozen reference manifest. If the source note changes, create a new discussion; Round 2 intentionally keeps the original evidence snapshot.

### 2. Run Blind Round 1

```powershell
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect

& (Join-Path $WorkbenchRoot "scripts\Invoke-ReasonixFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect

& (Join-Path $WorkbenchRoot "scripts\Collect-AgentDiscussion.ps1") `
  -DiscussionFolder $DiscussionFolder
```

Completion evidence is limited to the expected canonical files:

```text
round1/claude-code.md
round1/reasonix.md
```

Instructions, retry notes, Desktop windows, and arbitrary Markdown files do not count as reviewer completion.

### 3. Write Moderator Synthesis

The controller reads both reviews and writes `codex-synthesis.md`. A useful synthesis contains:

```markdown
# Moderator Synthesis

## Confirmed Common Ground

## Disputed Findings

## Suspected Misreadings

## Evidence Still Needed

## Round 2 Questions
```

Round 2 questions should target blocking, disputed, or weak-evidence findings. They should not ask reviewers to repeat Round 1.

### 4. Run Targeted Round 2

```powershell
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 2 -Collect

& (Join-Path $WorkbenchRoot "scripts\Invoke-ReasonixFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 2 -Collect

& (Join-Path $WorkbenchRoot "scripts\Collect-AgentDiscussion.ps1") `
  -DiscussionFolder $DiscussionFolder
```

After all required Round 2 files exist, an empty `decision.md` remains unfinished. The expected state is `needs_codex_decision`, not success.

### 5. Verify And Close

For a scientific audit, inspect `findings.json` and `disagreement-matrix.md`. Verify each material claim against the frozen evidence or a separate controlled check, then record outcomes with `Record-AgentAuditOutcome.ps1`.

Write one of:

- `decision.md` when the evidence supports a bounded decision;
- `user-decision-needed.md` when a material disagreement still requires human judgment.

Run `Collect-AgentDiscussion.ps1` again. A completed moderator decision should produce `decision_ready`.

## Example 2: Isolated Implementation Worker

This example delegates a small code change to Claude Code. Replace `claude-code` with `reasonix` to use the same formal worker route with Reasonix.

### 1. Create A Task Packet

```powershell
$Repository = (Resolve-Path ".\sample-repository").Path

$TaskFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentTask.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -Slug "validate-config" `
  -TargetAgent claude-code `
  -Mode implementation `
  -WorkspaceRoot $Repository `
  -Task "Add a focused configuration validation check and its tests." `
  -Context "Allowed: src/config.ps1 and tests/config.tests.ps1. Forbidden: dependency changes, release files, network calls, commits, and merges."
```

The task packet records scope, context, target agent, expected outputs, and state. It does not launch the worker.

### 2. Create An Isolated Worktree

```powershell
& (Join-Path $WorkbenchRoot "scripts\New-AgentWorktree.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -TaskFolder $TaskFolder `
  -WorkspaceRoot $Repository `
  -Slug "validate-config"
```

The source workspace is not the worker workspace. A Git worktree limits where repository edits are expected, but it does not restrict process, network, or operating-system access.

### 3. Run And Collect

```powershell
& (Join-Path $WorkbenchRoot "scripts\Invoke-AgentTask.ps1") `
  -TaskFolder $TaskFolder -Collect
```

Review at least:

```text
agent-result.md
result.md
patch.diff
status.json
run.log
isolated worktree git status and diff
```

The result is a proposal. Run the relevant tests yourself, inspect every changed file, and decide whether to reproduce, cherry-pick, rewrite, or reject the work. Agent Workbench does not merge it.

## Failure And Retry Notes

- If the caller times out, inspect the invocation lease and canonical output before retrying. The worker may still be running.
- Do not start a duplicate reviewer while the lease PID is active.
- Use explicit stale or failed invocation retry switches only after inspecting the existing evidence.
- If Claude feedback is malformed but potentially recoverable, use `Invoke-ClaudeFeedback.ps1 -RawReadOnlyRecovery` in the same discussion.
- If source files changed after a discussion was created, create a fresh discussion instead of using Round 2 as a re-review of new evidence.
- If a required reviewer is unavailable, keep the discussion incomplete or explicitly recreate it with that reviewer declared optional. Do not describe a single-reviewer result as a dual audit.
