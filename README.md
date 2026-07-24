# Meaning Assurance

**by LEVIUS**

**Release / 版本：** [v0.1.0 Public Preview](https://github.com/leviuszen/agent-workbench/releases/tag/v0.1.0) · [简体中文发布说明](.github/RELEASE_v0.1.0.zh-CN.md)

## Your coding agent says: “Done.”

**Do you believe it?**

What evidence do you check before accepting it?

Without an independent review path, the fallback can become you—arguing with the
same terminal until the answer feels safer.

When another agent agrees:

**Is that evidence—or synchronized confidence?**

## 你的 Coding Agent 说：“完成了。”

**你真的相信吗？**

在接受它之前，你会检查什么证据？

如果没有独立复审路径，最后可能还是你亲自和同一个终端争论，直到答案听起来
更让人安心。

当另一个 Agent 也表示同意：

**那是证据，还是同步的自信？**

## Agents are good at producing answers.

## They should not have the authority to approve themselves.

## Agent 擅长生产答案，

## 但不应该拥有批准自己的权力。

**Meaning Assurance is a local, file-backed assurance protocol for coding agents.**

It delegates bounded execution, preserves review evidence, exposes material
disagreement, and keeps final acceptance under human control.

**Meaning Assurance 是一套本地、文件化的 Coding Agent assurance 协议。**

它让有边界的执行可以被委托，保留可复查证据，让重要分歧显性化，并把最终
接受权留给人类。

> **Agents propose. Evidence is verified. Humans decide what to accept.**
>
> **Agent 提出结果，证据接受核验，人类决定是否采纳。**

[See how it works](#how-it-works) · [Read a real strategy audit](#a-real-strategy-discussion-and-read-only-audit) · [Inspect the evidence trail](#review-protocol) · [Install](#install)

[了解工作机制](#how-it-works) · [阅读真实战略审计](#a-real-strategy-discussion-and-read-only-audit) · [检查证据链](#review-protocol) · [安装](#install)

**No hosted control plane · No stored provider API keys · No automatic merge · Human final authority**

**无托管控制面 · 不保存供应商 API Key · 不自动合并 · 人类保留最终决定权**

## What Is Meaning Assurance?

Meaning Assurance is not a new coding agent or a model-voting system. It is an
assurance layer around coding-agent delegation: the work is bounded, the material
reviewers inspect can be frozen, disagreement remains visible, and no agent can
accept its own output.

Meaning Assurance 不是新的 Coding Agent，也不是模型投票系统。它是在 Coding
Agent 委托周围增加的 assurance layer：工作范围受到约束，Reviewer 检查的
材料可以被冻结，分歧保持可见，并且任何 Agent 都不能接受自己的输出。

| Question / 问题 | Answer / 回答 |
|---|---|
| What is it? / 它是什么？ | A local, file-backed assurance protocol for coding agents. / 一套本地、文件化的 Coding Agent assurance 协议。 |
| Why does it exist? / 为什么存在？ | Agent output and agent agreement are not by themselves verified evidence. / Agent 输出和 Agent 一致意见本身都不是经过核验的证据。 |
| How does it work? / 如何工作？ | Bounded tasks, isolated worktrees, frozen evidence, independent challenge, visible disagreement, and human acceptance. / 有边界任务、隔离 worktree、冻结证据、独立挑战、显性分歧和人工接受。 |
| What are the boundaries? / 边界是什么？ | No self-approval, no automatic merge, no OS-sandbox claim, and no guarantee of correctness. / 不允许自我批准、不自动合并、不声称 OS 级沙箱，也不保证正确。 |
| What is the brand relationship? / 品牌关系是什么？ | Meaning is the parent brand, Meaning Assurance is the product, and LEVIUS is the public author identity. / Meaning 是品牌母层，Meaning Assurance 是产品，LEVIUS 是公开作者身份。 |

The project is a public preview. Its current implementation is Windows-first and
PowerShell-based. It requires no server, database, message broker, separate UI,
or hosted control plane.

项目当前处于 Public Preview，现有实现以 Windows 和 PowerShell 为主，不需要
服务器、数据库、消息代理、独立 UI 或托管控制面。

The mechanism is role-based rather than tied to a fixed agent trio: a controller
creates packets and moderates evidence, workers implement bounded tasks,
reviewers challenge results, and the human retains final authority. The current
release packages Claude Code and Reasonix adapters and keeps some Codex-oriented
filenames, but another controller can drive the protocol and additional agent
runtimes can be added through new adapters.

该机制按角色组织，不绑定固定 Agent 三件套：controller 创建任务包并裁决
证据，worker 执行有边界任务，reviewer 挑战结果，人类保留最终决定权。当前
版本提供 Claude Code 和 Reasonix adapter，并保留部分 Codex 取向文件名；
其他 controller 也可以驱动同一协议，新的 Agent runtime 可通过 adapter 接入。

## Why It Exists

Running a second coding agent is easy. Keeping delegation bounded, evidence
inspectable, retries deterministic, and final decisions under human control is
harder.

再启动一个 Coding Agent 很容易。难的是让委托保持边界、证据可以检查、重试
状态确定，并把最终决定权留给人类。

`Synchronized confidence` means agents agree without demonstrating independent
verification. Agreement can be useful, but it is not proof by itself.

“同步的自信”是指 Agent 意见一致，却没有展示独立核验。一致意见可以提供
参考，但本身不是证明。

## How It Works

Meaning Assurance provides:

- task packets with explicit scope and expected outputs;
- isolated Git worktrees for implementation workers;
- frozen, hashed reference snapshots for read-only review;
- required and optional reviewer gates;
- blind Round 1 review and targeted Round 2 challenge;
- canonical result files and invalid-output quarantine;
- PID-backed invocation leases to avoid duplicate workers after caller timeouts;
- evidence-based moderation instead of model voting;
- no automatic merge or patch application.

对应机制包括：

- 明确任务范围和预期输出的 task packet；
- 为 implementation worker 创建隔离 Git worktree；
- 为只读复审创建冻结并哈希化的 reference snapshot；
- required 与 optional reviewer gate；
- blind Round 1 和 targeted Round 2；
- 规范结果文件和无效输出隔离；
- 用 PID-backed invocation lease 防止调用方超时后重复启动 worker；
- 基于证据的 moderation，而不是模型投票；
- 不自动 merge 或应用 patch。

Codex is the default moderator in the current file protocol, but the PowerShell
entrypoints can be called by a human or another controller that honors the same
artifacts and gates.

## A Real Strategy Discussion and Read-Only Audit

Meaning Assurance is not limited to implementation tasks. In `strategy-review`
mode, a reviewer interrogates positioning, scope, hidden assumptions,
counter-evidence, and falsifiers against a frozen reference set. The reviewer
cannot edit the source material or accept its own conclusions.

Meaning Assurance 不只用于实现任务。在 `strategy-review` 模式中，Reviewer 会基于
冻结参考集追问定位、范围、隐藏假设、反证和可证伪条件；Reviewer 不能修改源材料，
也不能批准自己的结论。

This README became the subject of a real internal-dogfooding case. Claude Code
first challenged the bilingual hero, the `Meaning Assurance` promise, the
`synchronized confidence` concept, failure communication, and the credibility
of publishing a self-referential case. Codex then challenged the review itself:
unsupported search-ranking claims were rejected, a conclusion inferred from
missing test files was marked not testable, and two low-value findings were
withdrawn in Round 2.

这份 README 本身成为了一次真实的内部 dogfooding 案例。Claude Code 先质疑双语
首屏、`Meaning Assurance` 的承诺边界、`同步的自信` 概念、失败沟通，以及公开
“自我审视案例”的可信度；随后 Codex 反过来审视这份审计：没有证据的搜索排序判断
被驳回，因参考包未包含测试目录而产生的结论被标记为不可检验，两项低价值 finding
在 Round 2 被撤回。

The final record contains 10 moderated outcomes: **5 confirmed, 2 rejected,
2 duplicate, and 1 not testable**. That distribution is the point. The case
does not show agents agreeing; it shows disagreement being preserved and weak
reviewer claims being constrained.

最终记录包含 10 项经过裁决的结果：**5 项确认、2 项驳回、2 项重复、1 项不可
检验**。这组分布本身就是案例重点：它展示的不是 Agent 达成一致，而是分歧被保留，
Reviewer 过度延伸的判断受到约束。

> **Case boundary:** this is an internal protocol demonstration, not a
> third-party audit, independent validation, or evidence of product
> effectiveness.
>
> **案例边界：**这是内部协议演示，不是第三方审计、独立验证，也不是产品有效性
> 证据。

[Open the case index](docs/cases/2026-07-25-readme-strategy-review/README.md) ·
[Read the strategy discussion](docs/cases/2026-07-25-readme-strategy-review/strategy-discussion.md) ·
[Inspect the read-only audit](docs/cases/2026-07-25-readme-strategy-review/read-only-audit.md)

[打开案例索引](docs/cases/2026-07-25-readme-strategy-review/README.md) ·
[阅读战略讨论](docs/cases/2026-07-25-readme-strategy-review/strategy-discussion.md) ·
[检查只读审计](docs/cases/2026-07-25-readme-strategy-review/read-only-audit.md)

## Requirements

- Windows 10 or later
- Windows PowerShell 5.1 or PowerShell 7
- Git 2.20 or later
- At least one supported CLI agent:
  - Claude Code available on `PATH`, through `CLAUDE_CODE_EXE`, or with `-ClaudeExe`
  - Reasonix available on `PATH`, through `REASONIX_COMMAND`, or with `-ReasonixCommand`

Live agent credentials remain managed by the agent CLI. Meaning Assurance does not store provider API keys.

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

Meaning Assurance redacts common secrets and local paths from selected logs, but redaction is defense in depth, not a guarantee. Review all artifacts before sharing them. See [Privacy](docs/PRIVACY.md).

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
