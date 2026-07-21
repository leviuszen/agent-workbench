# Agent Workbench

Agent Workbench is a local-first, file-backed harness for delegating bounded work to CLI coding agents and reviewing their output before any change is accepted.

**Release:** [v0.1.0 Public Preview](https://github.com/leviuszen/agent-workbench/releases/tag/v0.1.0) | [简体中文发布说明](.github/RELEASE_v0.1.0.zh-CN.md)

The project is a public preview. Its current implementation is Windows-first and PowerShell-based. It requires no server, database, message broker, separate UI, or hosted control plane.

The mechanism is role-based rather than tied to a fixed agent trio: a controller creates packets and moderates evidence, workers implement bounded tasks, reviewers challenge results, and the human retains final authority. The current release packages Claude Code and Reasonix adapters and keeps some Codex-oriented filenames, but another controller can drive the protocol and additional agent runtimes can be added through new adapters.

## Why It Exists

Running a second coding agent is easy. Keeping delegation bounded, evidence inspectable, retries deterministic, and final decisions under human control is harder.

Agent Workbench provides:

- task packets with explicit scope and expected outputs;
- isolated Git worktrees for implementation workers;
- frozen, hashed reference snapshots for read-only review;
- required and optional reviewer gates;
- blind Round 1 review and targeted Round 2 challenge;
- canonical result files and invalid-output quarantine;
- PID-backed invocation leases to avoid duplicate workers after caller timeouts;
- evidence-based moderation instead of model voting;
- no automatic merge or patch application.

Codex is the default moderator in the current file protocol, but the PowerShell entrypoints can be called by a human or another controller that honors the same artifacts and gates.

## Requirements

- Windows 10 or later
- Windows PowerShell 5.1 or PowerShell 7
- Git 2.20 or later
- At least one supported CLI agent:
  - Claude Code available on `PATH`, through `CLAUDE_CODE_EXE`, or with `-ClaudeExe`
  - Reasonix available on `PATH`, through `REASONIX_COMMAND`, or with `-ReasonixCommand`

Live agent credentials remain managed by the agent CLI. Agent Workbench does not store provider API keys.

## Install

From a local clone:

```powershell
$env:AGENT_WORKBENCH_HOME = Join-Path $env:LOCALAPPDATA "AgentWorkbench"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AgentWorkbench.ps1
```

Without `AGENT_WORKBENCH_HOME`, the installer defaults to `%LOCALAPPDATA%\AgentWorkbench`, then falls back to `$HOME\.agent-workbench`.

The installer preserves existing runtime folders when upgrading:

```text
tasks/
bugs/
worktrees/
discussions/
```

## Quick Start: Read-Only Review

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
$params = @{
  WorkbenchRoot = $WorkbenchRoot
  Slug = "sample-review"
  Topic = "Review a bounded design note"
  Question = "What assumptions are unsupported?"
  Context = "Use only the supplied reference snapshot."
  Mode = "strategy-review"
  Protocol = "adversarial-discussion"
  AuditProfile = "scientific"
  Agents = @("claude-code")
  ReferencePaths = @("C:\path\to\sample-design.md")
}

$DiscussionFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentDiscussion.ps1") @params
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect
```

Reference files are copied into the discussion as frozen evidence. If the source changes, create a fresh discussion instead of reusing an old snapshot.

## Quick Start: Isolated Implementation Worker

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
$TaskFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentTask.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -Slug "sample-change" `
  -Task "Implement the requested check and add focused tests." `
  -Context "Do not change unrelated files." `
  -Mode implementation `
  -TargetAgent claude-code `
  -WorkspaceRoot "C:\path\to\git-repository"

& (Join-Path $WorkbenchRoot "scripts\New-AgentWorktree.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -TaskFolder $TaskFolder `
  -WorkspaceRoot "C:\path\to\git-repository" `
  -Slug "sample-change"

& (Join-Path $WorkbenchRoot "scripts\Invoke-AgentTask.ps1") `
  -TaskFolder $TaskFolder -Collect
```

The worker edits only the isolated worktree. The collector exposes the result and Git status for review; it does not merge the branch.

## Review Protocol

For consequential code or strategy review, `-AuditProfile scientific` adds structured findings, disagreement tracking, and explicit moderation outcomes.

Important rules:

- Round 1 reviewers work independently.
- Round 2 addresses disputed, blocking, or weak-evidence findings only.
- Missing required reviewer files block final moderation.
- Reviewer agreement is not proof.
- The moderator verifies evidence and records confirmed, rejected, duplicate, or not-testable outcomes.
- Material unresolved disagreement is escalated to the user.

See [Protocol](docs/PROTOCOL.md) and [Architecture](docs/ARCHITECTURE.md).

Complete synthetic walkthroughs are available in [Examples](docs/EXAMPLES.md).

## Privacy Model

Runtime data can contain source snapshots, prompts, paths, and agent output. Keep the runtime outside the source checkout and do not commit it.

Agent Workbench redacts common secrets and local paths from selected logs, but redaction is defense in depth, not a guarantee. Review all artifacts before sharing them. See [Privacy](docs/PRIVACY.md).

## Test

The test suite uses temporary repositories and fake agent executables. It does not require live Claude Code or Reasonix sessions.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

## Current Limitations

- Windows and PowerShell are the only tested host environment.
- Claude Code and Reasonix are the only formal non-interactive adapters.
- The current canonical moderation filenames retain Codex-oriented naming.
- A Git worktree is an isolation boundary for files, not a complete OS sandbox.
- External CLI behavior and permissions remain subject to each CLI's configuration.
- No UI is included.
- No automatic merge is provided.

## Project Status

The public API is not yet stable. Breaking changes may occur before `1.0.0`.

See [CHANGELOG.md](CHANGELOG.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [SECURITY.md](SECURITY.md).

## Author And Contact

- Author ID: **LEVIUS**
- Public contact: [agentworkbench@proton.me](mailto:agentworkbench@proton.me)

See [AUTHORS.md](AUTHORS.md) for the public maintainer record.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).

---

**Meaning** — *Living-Seeking-Meaning.* 追寻意义的过程即使没有结果，其本身也足够有意义。

> “Dedicated to all the pioneers.”——《Macross Plus》
