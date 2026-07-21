# Release Messaging Strategy / 发布营销定位

This document explains how to market Agent Workbench without turning current implementation details into the product identity or making claims the release cannot support.

本文用于说明如何宣传 Agent Workbench，同时避免把当前实现中的 Agent 组合误当成产品本体，也避免作出超过现有证据的承诺。

## Positioning Decision / 定位结论

Do not lead with "Codex calls Claude Code and Reasonix." Lead with the governed collaboration mechanism:

不要以“Codex 调用 Claude Code 和 Reasonix”作为核心卖点。应该宣传可治理的协作机制：

> A local, file-backed protocol for assigning bounded work to external agents, preserving review evidence, and keeping final decisions under human control.

> 一套本地、文件化的 Agent 协作协议：把有边界的工作交给外部 Agent，保留可复查证据，并让最终决定继续由人掌握。

The controller, worker, and reviewer roles are replaceable. The current adapters are evidence of one implementation, not the definition of the product.

控制者、worker 和 reviewer 都应当是可替换角色。当前 adapter 只是机制的一种实现证据，不是产品定义。

## The Problem Category / 问题类别

The category is not "run more agents." It is "govern multi-agent handoffs in real work."

它解决的不是“如何运行更多 Agent”，而是“如何治理真实工作中的多 Agent 交接”。

The central tension is:

```text
External agents increase execution and review capacity,
but unmanaged delegation weakens scope, provenance, repeatability, and accountability.
```

```text
外部 Agent 能扩大执行和审查能力，
但缺少治理的委派会削弱范围控制、证据来源、可重复性和责任边界。
```

## Differentiation / 差异化优势

The strongest differentiator is not a larger number of agents. It is a lighter control mechanism that covers several serious collaboration modes while preserving an inspectable evidence chain.

最大的差异不是可以调用更多 Agent，而是用更轻的控制机制覆盖多种严肃协作方式，同时保留可检查的证据链。

### Lightweight by architecture / 架构决定的轻量

- no server, database, message broker, separate UI, or hosted control plane;
- no replacement model gateway or credential store;
- ordinary files and Git remain the state and evidence substrate;
- existing CLI agents remain independently configurable;
- installation and rollback are local file operations.

### Faster to adopt / 更快进入现有工作流

The supported claim is faster setup and integration for users who already have CLI agents. Do not claim faster model inference or universally faster task completion without benchmarks.

可以宣传的是：对于已经拥有 CLI Agent 的用户，安装和接入路径更短。没有基准测试时，不宣传模型推理更快或任务完成速度必然更快。

### Broader interaction coverage / 交互覆盖更完整

One file and state mechanism supports:

- strategy and decision support;
- adversarial two-round discussion;
- read-only code, plan, article, and evidence review;
- bounded external implementation or research work;
- comparison and disagreement tracking;
- moderator synthesis and human escalation.

### Operational qualities / 运行特征

- **Controllable / 可控:** scope, roles, reviewer requirements, state gates, isolated worktrees, no auto-merge.
- **Inspectable / 可查:** canonical files, status, findings, diffs, logs, and missing-step states.
- **Traceable / 可溯源:** frozen evidence, manifests, hashes, process leases, synthesis, and final decisions.

## Comparative Framing / 对比表达

Use architectural comparisons, not unsupported superiority claims:

| Alternative approach | Agent Workbench advantage | Honest tradeoff |
|---|---|---|
| Hosted multi-agent orchestrator | Lighter local setup; no service stack or control plane. | No remote fleet management, hosted dashboard, or broad integration catalog. |
| Shared agent chatroom | Stronger task state, evidence bundles, reviewer gates, and final decision artifacts. | Less suited to free-form real-time social conversation. |
| One-off direct CLI delegation | Better scope, retry state, canonical outputs, worktree isolation, and traceability. | Adds deliberate packet and review steps. |
| General agent framework | Faster to introduce when users already have working CLI agents. | New runtimes still require adapters; v0.1.0 is Windows-first. |

Recommended comparative sentence:

> If you already have capable agents and need a lighter way to govern how they exchange work, evidence, and decisions, Agent Workbench adds the control layer without asking you to adopt another hosted platform.

推荐的中文对比表达：

> 如果你已经拥有能力足够的 Agent，只是缺少一套更轻的工作交接、证据复查和决策控制机制，Agent Workbench 可以补上控制层，而不要求你再部署一套托管式多 Agent 平台。

## Primary Work Scenarios / 核心工作场景

| Work scenario | User pain | Agent Workbench response | Release evidence |
|---|---|---|---|
| Bounded implementation / 受控实现 | A worker may edit the wrong workspace or broaden scope. | Task packet plus isolated Git worktree; no automatic merge. | `New-AgentTask.ps1`, `New-AgentWorktree.ps1`, worker tests |
| Independent review / 独立审查 | Reviewers may see different evidence or converge without proof. | Frozen reference bundle, blind Round 1, separate canonical outputs. | reference manifest, hashes, `roundN/<agent>.md` |
| Disagreement resolution / 分歧收敛 | Feedback accumulates but no decision is made. | Moderator synthesis, targeted Round 2, evidence outcomes, user escalation. | `codex-synthesis.md`, `decision.md`, state-gate tests |
| Timeout recovery / 超时恢复 | A caller retries while the original agent is still running. | PID-backed invocation lease and explicit stale/failed retry paths. | invocation lease tests and canonical result adoption |
| Durable handoff / 长期交接 | Chat history cannot reliably preserve task state and evidence. | Local task/discussion folders with status, logs, references, diffs, and decisions. | file protocol and collection tests |

## Target Audience / 目标用户

Primary audience:

- developers already using more than one coding agent or CLI agent;
- users who want one main workbench but interchangeable external workers and reviewers;
- local-first teams that need inspectable evidence before accepting generated code or strategic recommendations;
- high-consequence workflows where "the model said so" is not an acceptable completion condition.

首要用户：

- 已经同时使用多个编码 Agent 或 CLI Agent 的开发者；
- 希望保留一个主工作台，同时替换外部 worker 和 reviewer 的用户；
- 在接受生成代码或方案建议前，需要本地可检查证据的团队；
- 不能把“模型已经回答”当成完成依据的高后果工作流。

Secondary audience:

- agent-tool authors who need a reference file protocol;
- teams experimenting with their own controller, OpenHands, or future agent adapters;
- maintainers studying evidence-based multi-agent review.

OpenHands and other runtimes should be described as possible adapter targets, not current built-in support.

## Message Hierarchy / 信息优先级

Use this order in release pages, posts, and demos:

1. **Work problem:** delegation becomes unreliable when scope, evidence, retry state, and final authority are unclear.
2. **User outcome:** external agents can contribute without silently becoming the source of truth.
3. **Mechanism:** task packets, isolated worktrees, frozen evidence, reviewer gates, process leases, and moderator decisions.
4. **Replaceable roles:** controller, worker, and reviewer are protocol roles, not permanent brands.
5. **Current implementation:** Windows, PowerShell, Claude Code and Reasonix adapters, Codex-oriented filenames.
6. **Boundary:** no OS sandbox, no automatic merge, no guarantee of privacy or correctness.

不要先讲脚本名称。`task packet`、`worktree` 和 `manifest` 是可信度证明，不是第一句广告。第一句必须让用户认出自己遇到过的工作困境。

## Recommended Claims / 推荐主张

### English

- Put external coding agents to work without giving up scope, evidence, or final control.
- Turn multi-agent delegation from a chat convention into an inspectable local protocol.
- Review agent work before any change is accepted.
- Keep workers and reviewers replaceable while preserving the same task and evidence contract.
- Make timeouts, missing reviewers, unresolved disagreements, and missing decisions visible states.

### 中文

- 让外部编码 Agent 真正进入工作流，同时不交出任务边界、过程证据和最终决定权。
- 把依赖聊天默契的多 Agent 委派，变成可检查的本地协议。
- 在任何修改被接受前，先复核 Agent 的代码、证据和状态。
- worker 和 reviewer 可以替换，任务与证据合同不随 Agent 品牌改变。
- 让超时、缺失 reviewer、未解决分歧和缺少最终决定都成为可见状态。

## Claims To Avoid / 禁止夸大

Do not claim:

- fully autonomous multi-agent engineering;
- a secure operating-system sandbox;
- guaranteed independent or correct reviews;
- guaranteed prevention of data leakage;
- built-in support for OpenHands or another runtime before an adapter exists;
- production-ready, enterprise-grade, or universal cross-platform support;
- that multi-model agreement proves a finding.

不要宣传为：

- 全自动多 Agent 工程平台；
- 操作系统级安全沙箱；
- 保证独立或保证正确的审查；
- 保证数据不会泄露；
- 尚未实现 adapter 的 Agent 已经开箱即用；
- 生产级、企业级或全平台通用；
- 多模型一致就等于事实成立。

## Copy Examples / 营销文案示例

### English one-liner

> Agent Workbench is a local protocol for delegating bounded work to replaceable coding agents while preserving evidence and human control.

### 中文一句话

> Agent Workbench 是一套本地 Agent 协作协议，让可替换的编码 Agent 承担有边界的工作，同时保留证据和人工决定权。

### English short announcement

> Running a second coding agent is easy. Knowing what it saw, preventing duplicate retries, keeping code changes isolated, and forcing review discussions to end in a real decision is harder. Agent Workbench v0.1.0 turns those handoffs into local task packets, frozen evidence, explicit state gates, and reviewable decisions.

### 中文短公告

> 再启动一个编码 Agent 很容易。难的是确认它看过什么、避免超时后重复启动、隔离代码修改，并让多轮审查最终形成真正的决定。Agent Workbench v0.1.0 用本地任务包、冻结证据、明确状态门和可复查裁决，把这些交接变成正式工作流。

### Demo opening / 演示开场

> This demo is not about which model is strongest. It shows how a controller can replace workers and reviewers without losing the task boundary, evidence bundle, or final decision gate.

> 这个演示不比较哪个模型最强，而是展示：当控制者替换 worker 或 reviewer 时，任务边界、证据包和最终决策门仍然保持不变。

## Marketing Validation / 营销验证

For the public preview, measure whether readers understand these points after one pass:

1. Agent Workbench governs handoffs; it does not provide a new model.
2. Agent roles are replaceable, but v0.1.0 has only two formal non-interactive adapters.
3. The strongest value is inspectability and decision control, not maximum autonomy.
4. Worktrees and redaction reduce risk but do not create an OS sandbox or privacy guarantee.
5. The release is useful only for users whose workflow is complex enough to justify durable packets and gates.

If readers mainly describe it as "Codex calling Claude" or "another agent chatroom," the positioning has failed and the release copy should be revised.
