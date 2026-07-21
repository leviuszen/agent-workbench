# Agent Workbench v0.1.0 - Public Preview

> A lightweight local control layer for strategy, adversarial review, read-only analysis, and bounded external work, with every handoff kept controllable, inspectable, and traceable.

Agent Workbench v0.1.0 is the first public preview of a local-first, file-backed harness for delegating bounded work to CLI coding agents and reviewing their output before any change is accepted.

简体中文发布说明：[Agent Workbench v0.1.0 - 公开预览版](https://github.com/leviuszen/agent-workbench/blob/v0.1.0/.github/RELEASE_v0.1.0.zh-CN.md)

## Why This Release Exists

Launching another coding agent is easy. The difficult part begins when that agent becomes part of real engineering work:

- How do you delegate implementation without letting a worker edit the source workspace directly?
- How do you know which files a reviewer actually saw?
- How do two reviewers stay independent in Round 1 and focus on real disagreements in Round 2?
- How do you avoid launching a duplicate worker when the caller times out but the original process is still running?
- How do you force a multi-agent discussion to end with an evidence-based moderator decision instead of another pile of feedback?

Agent Workbench addresses these situations with inspectable task packets, isolated Git worktrees, frozen review evidence, explicit reviewer gates, and human-controlled final decisions. It is designed for developers who need a governed handoff between a controller, implementation workers, reviewers, and the human decision maker.

## A Role Protocol, Not A Fixed Agent Trio

Agent Workbench does not require one permanent combination of agent brands. Its mechanism separates four roles:

- **Controller:** owns the main conversation, creates task or discussion packets, and moderates results.
- **Worker:** performs a bounded implementation task in an isolated workspace.
- **Reviewer:** challenges code, plans, or evidence without accepting its own output.
- **Human decision maker:** authorizes scope and retains the final decision.

One setup may use Codex as the controller with Claude Code and Reasonix as external workers or reviewers. Another controller could drive the same file and state protocol and dispatch different agents after suitable adapters are implemented.

The v0.1.0 package includes formal non-interactive adapters for Claude Code and Reasonix, and some canonical moderator filenames remain Codex-oriented. OpenHands and other agent runtimes are architectural extension points, not supported built-in adapters in this release.

## Lightweight And Fast To Adopt

Agent Workbench is designed for users who want to govern the agents they already have instead of standing up another multi-agent platform.

- No server, database, message broker, separate UI, or hosted control plane is required.
- Installation copies local PowerShell scripts and skill files into a runtime folder.
- Existing CLI agent credentials and provider configuration remain with those CLIs.
- Workflow state is ordinary Markdown, JSON, JSONL, logs, and Git diffs that can be inspected with familiar tools.
- A controller can call the script entrypoints directly; a new agent runtime can join by implementing the required adapter and artifact contracts.

"Fast" here means faster to install, understand, and introduce into an existing CLI-agent workflow. It is not a claim that model inference or task execution is faster than another product.

## One Mechanism, Multiple Collaboration Modes

- **Strategy and decision support:** structure a question, freeze relevant evidence, compare recommendations, and preserve the final decision.
- **Adversarial discussion:** run blind Round 1 review, moderator synthesis, and targeted Round 2 challenge.
- **Read-only review:** ask external reviewers to inspect code, plans, articles, or bounded evidence without editing the source workspace.
- **Bounded external work:** dispatch implementation, research, comparison, or review tasks to an isolated worker path.
- **Human escalation:** stop after unresolved material disagreement and ask the user to choose the direction.

## Controllable, Inspectable, Traceable

- **Controllable:** explicit task scope, declared roles, required reviewer gates, isolated worktrees, and no automatic merge.
- **Inspectable:** canonical outputs, `status.json`, reviewer findings, Git status, diffs, and visible unfinished states.
- **Traceable:** frozen reference snapshots, inventories, hashes, run logs, invocation leases, moderator synthesis, and final decision files.

## Where It Helps

- **Bounded implementation:** send a focused code task to an external worker while keeping the source branch untouched.
- **Independent review:** give multiple reviewers the same frozen evidence bundle and preserve separate canonical findings.
- **Disagreement resolution:** use blind Round 1 review, targeted Round 2 challenge, moderator synthesis, and user escalation when the evidence does not converge.
- **Timeout recovery:** inspect process leases and canonical outputs before deciding whether a retry is safe.
- **Durable handoff:** keep tasks, review evidence, diffs, status, and decisions in local files instead of relying on chat memory.

The project is Windows-first and PowerShell-based. It intentionally does not merge or apply agent changes automatically.

## Highlights

- **Bounded task packets:** assignments, context, expected outputs, state, and logs live in one inspectable folder.
- **Isolated implementation workers:** Claude Code and Reasonix edit a dedicated Git worktree rather than the source workspace.
- **Frozen review evidence:** reference files are copied, inventoried, size-checked, and hashed when a discussion is created.
- **Structured adversarial review:** blind Round 1 review can be followed by a targeted Round 2 challenge instead of a repeated review.
- **Explicit completion gates:** missing canonical reviewer files, missing moderator synthesis, and unresolved disagreement remain unfinished states.
- **Evidence-based moderation:** reviewer agreement is not treated as proof; findings are confirmed, rejected, deduplicated, or marked not testable.
- **Duplicate-run protection:** PID-backed invocation leases distinguish an active worker from a failed or stale invocation.
- **No automatic merge:** workers produce code and evidence, but the controller and human retain the acceptance decision.

## Quick Example: Dual Read-Only Review

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
$ReferenceFile = (Resolve-Path ".\examples\sample-design-note.md").Path

$params = @{
  WorkbenchRoot = $WorkbenchRoot
  Slug = "cache-policy-review"
  Topic = "Review a cache invalidation proposal"
  Question = "Which assumptions could make this proposal fail?"
  Context = "Use only the frozen reference snapshot. Do not edit source files."
  Mode = "strategy-review"
  Protocol = "adversarial-discussion"
  AuditProfile = "scientific"
  Agents = @("claude-code", "reasonix")
  ReferencePaths = @($ReferenceFile)
  ReviewerLenses = @{
    "claude-code" = "implementation feasibility and hidden coupling"
    "reasonix" = "evidence quality and falsification"
  }
}

$DiscussionFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentDiscussion.ps1") @params
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect
& (Join-Path $WorkbenchRoot "scripts\Invoke-ReasonixFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect
```

The controller then checks the canonical feedback files, writes `codex-synthesis.md`, asks only targeted Round 2 questions when needed, verifies the findings, and writes `decision.md` or `user-decision-needed.md`.

## Quick Example: Isolated Implementation Worker

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
$Repository = (Resolve-Path ".\sample-repository").Path

$TaskFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentTask.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -Slug "validate-config" `
  -TargetAgent claude-code `
  -Mode implementation `
  -WorkspaceRoot $Repository `
  -Task "Add a focused configuration validation check and its tests." `
  -Context "Change only the configuration module and its focused tests."

& (Join-Path $WorkbenchRoot "scripts\New-AgentWorktree.ps1") `
  -WorkbenchRoot $WorkbenchRoot `
  -TaskFolder $TaskFolder `
  -WorkspaceRoot $Repository `
  -Slug "validate-config"

& (Join-Path $WorkbenchRoot "scripts\Invoke-AgentTask.ps1") `
  -TaskFolder $TaskFolder -Collect
```

The collector exposes the canonical result and isolated worktree diff for review. It does not merge the worker branch.

See `docs/EXAMPLES.md` for complete synthetic walkthroughs, expected artifacts, Round 2 moderation, retry behavior, and cleanup guidance.

## Safety And Privacy Model

- Agent output is treated as untrusted evidence, not an accepted decision.
- A Git worktree isolates repository changes; it is not an operating-system sandbox.
- Agent Workbench does not add telemetry or a hosted control plane.
- Configured CLI agents may communicate with their own providers under their own settings and terms.
- Runtime folders can contain prompts, source snapshots, paths, diffs, and model output. Keep them outside the source checkout and review artifacts before sharing.
- Secret and path redaction is defense in depth, not a guarantee.

## Install

```powershell
$env:AGENT_WORKBENCH_HOME = Join-Path $env:LOCALAPPDATA "AgentWorkbench"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AgentWorkbench.ps1
```

The installer preserves existing `tasks`, `bugs`, `worktrees`, and `discussions` folders during upgrades.

## Verified In This Release

- All 15 repository tests pass locally under Windows PowerShell 5.1.
- GitHub Actions passed all 15 repository tests under both Windows PowerShell 5.1 and PowerShell 7 on the release commit.
- Tests use temporary repositories and fake agent executables; live provider credentials are not required.
- Public-release hygiene checks cover required files and known private path markers.
- The release candidate was built as a clean repository without private runtime folders or private Git history.

## Known Limitations

- Windows is the only tested host environment.
- Claude Code and Reasonix are the only formal non-interactive adapters.
- External CLI permissions remain subject to each CLI's configuration.
- The public API may change before `1.0.0`.
- The current moderation filenames retain Codex-oriented naming.
- There is no UI and no automatic merge path.

## Feedback

Reproducible bug reports and focused design feedback are welcome. Use synthetic examples and remove credentials, personal information, private source code, local absolute paths, and unredacted runtime artifacts before opening an issue.

- Author: **LEVIUS**
- Contact: [agentworkbench@proton.me](mailto:agentworkbench@proton.me)

---

**Meaning** — *Living-Seeking-Meaning.* The pursuit of meaning remains meaningful in itself, even when it reaches no final answer.

> “Dedicated to all the pioneers.” — *Macross Plus*
