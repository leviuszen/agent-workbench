# Agent Workbench v0.1.0 - 公开预览版

> 一套轻量、快速接入的本地 Agent 协作层：覆盖战略讨论、对抗复审、只读分析和外部工作，并让每次交接都可控、可查、可溯源。

Agent Workbench v0.1.0 是首个公开预览版。它是一套本地优先、以文件为协议载体的 Agent 协作工作机制，用于把有明确边界的工作交给外部 CLI Agent，并在任何修改被接受前保留可检查的结果和证据。

## 它解决的不是“如何再启动一个 Agent”

启动另一个编码 Agent 并不难。真正进入工程工作后，困难通常出现在这些场景：

- 想把一段实现工作交给外部 Agent，但不希望它直接修改当前源码工作区。
- 想让两个 Agent 独立审查同一份方案，却无法确认它们分别看到了哪些材料，也无法避免相互影响。
- 外层调用已经超时，但 Agent 进程可能仍在运行；贸然重试会产生重复 worker 和相互竞争的结果。
- 第一轮反馈很多，第二轮仍在重复观点，却没有主持人综合、证据核验和最终决策。
- 讨论散落在聊天记录里，过几天无法还原任务边界、证据版本、执行状态和采纳理由。

Agent Workbench 将这些问题变成可检查的本地文件、状态门和执行记录，让多 Agent 协作不再只依赖提示词和聊天记忆。

## 这是一套角色协议，不是固定的 Agent 三件套

Agent Workbench 的核心不是绑定 Codex、Claude Code 和 Reasonix，而是分离四种职责：

- **主工作台或控制者：**与用户沟通，创建任务包或讨论包，组织复审并汇总结果。
- **Worker：**在受约束的独立工作区内执行实现任务。
- **Reviewer：**只读检查代码、方案和证据，不能自行接受自己的结论。
- **人工决策者：**授权范围，判断重大分歧，并保留最终采纳权。

一种部署方式可以是 Codex 作为主工作台，调用 Claude Code 和 Reasonix；另一种方式也可以由 Claude Code 或其他控制器主持，再调用 OpenHands 或其他 Agent。前提是控制器和适配器遵守同一套任务包、状态、证据和裁决协议。

当前 v0.1.0 只正式内置 Claude Code 和 Reasonix 的非交互适配器，部分主持人文件名仍保留 Codex 取向。OpenHands 等其他 Agent 是可扩展方向，目前需要新增 adapter，不能视为开箱即用。

## 为什么它更轻、更快接入

Agent Workbench 适合已经拥有多个 CLI Agent、但不想再搭建一套重型多 Agent 平台的用户。

- 不需要服务端、数据库、消息队列、独立 UI 或托管控制平面。
- 安装过程只是把本地 PowerShell 脚本和 skill 文件复制到 runtime 目录。
- 继续使用现有 CLI Agent 的账号、凭据和模型配置，不再建立一套供应商管理层。
- 工作状态就是普通的 Markdown、JSON、JSONL、日志和 Git diff，可以用现有工具直接查看。
- 主工作台可以直接调用脚本入口；其他 Agent runtime 只需实现对应 adapter 和产物合同即可加入。

这里的“更快”是指安装更快、理解成本更低、进入现有 CLI Agent 工作流的路径更短，不表示模型推理或任务执行速度必然快于其他产品。

## 一套机制覆盖多种协作方式

- **战略与决策讨论：**组织问题、冻结相关证据、比较建议并保存最终决定。
- **对抗式复审：**第一轮独立盲审，主持人综合，第二轮只挑战争议项和弱证据项。
- **只读外部审查：**让 reviewer 检查代码、方案、文章或限定证据，不编辑源工作区。
- **外部工作委派：**把实现、研究、比较或审查任务交给隔离路径中的 worker。
- **人工介入收口：**重大分歧两轮后仍无法收敛时暂停，由用户决定方向。

## 可控、可查、可溯源

- **可控：**任务范围明确、角色声明清楚、required reviewer 门存在、worker 使用隔离 worktree，并且不自动合并。
- **可查：**规范输出、`status.json`、reviewer findings、Git 状态、diff 和未完成状态都可以直接检查。
- **可溯源：**冻结引用快照、文件清单、哈希、运行日志、调用租约、主持人综合和最终决定形成完整证据链。

## 适合哪些工作场景

- **受控代码委派：**把一项小而明确的代码任务交给外部 worker，同时保持源分支不被直接修改。
- **独立双重审查：**让多个 reviewer 基于同一份冻结证据独立给出发现，并保留各自的规范结果文件。
- **重大分歧收敛：**第一轮盲审，第二轮只回应争议点，之后由主持人核验证据；两轮仍无法收敛时暂停并交给用户判断。
- **超时后的可靠恢复：**先检查进程租约和规范输出，再判断是否需要重试，避免重复启动外部 Agent。
- **长期工程交接：**把任务、引用材料、diff、状态、反馈和最终决定保存在本地文件中，而不是只留在某个对话窗口里。

## 本版本的主要能力

- **有边界的任务包：**任务、上下文、预期输出、状态和日志保存在同一目录。
- **隔离实现工作区：**implementation worker 在独立 Git worktree 中修改代码，不直接编辑源工作区。
- **冻结审查证据：**创建 discussion 时复制、清点、限额并哈希引用文件。
- **结构化对抗审查：**第一轮独立审查，第二轮只针对阻断项、争议项和弱证据项。
- **明确的完成状态：**缺少 reviewer 文件、主持人综合或最终决定时，流程保持未完成。
- **证据裁决而不是模型投票：**多个 Agent 同意不等于正确，主持人仍需核验证据并记录结果。
- **重复调用保护：**通过带 PID 的调用租约区分仍在运行、已失败和已经过期的调用。
- **不自动合并：**Agent 只产生代码、发现和证据，控制者与用户决定是否接受。

## 快速示例：双 Reviewer 只读审查

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
}

$DiscussionFolder = & (Join-Path $WorkbenchRoot "scripts\New-AgentDiscussion.ps1") @params
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect
& (Join-Path $WorkbenchRoot "scripts\Invoke-ReasonixFeedback.ps1") `
  -DiscussionFolder $DiscussionFolder -Round 1 -Collect
```

这只是当前内置 adapter 的示例，不代表角色必须由这两个 Agent 承担。控制者随后检查规范反馈文件，写入 `codex-synthesis.md`，必要时发起定向第二轮，核验 findings，并写入 `decision.md` 或 `user-decision-needed.md`。

## 快速示例：隔离 Implementation Worker

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

collector 会暴露规范结果和隔离 worktree 的 diff，供控制者复核，但不会合并 worker 分支。

完整的合成示例、第二轮主持流程、重试规则和清理说明见 `docs/EXAMPLES.md`。

## 安全与隐私边界

- Agent 输出是待验证证据，不是已经接受的决定。
- Git worktree 只隔离仓库修改位置，不是操作系统级沙箱。
- Agent Workbench 不增加遥测或托管控制平面。
- 外部 CLI Agent 仍可能按照各自设置和条款与模型服务商通信。
- runtime 目录可能包含提示词、源码快照、路径、diff 和模型输出，应放在源码仓库之外并在分享前检查。
- secret 和路径脱敏属于纵深防御，不构成绝对保证。

## 安装

```powershell
$env:AGENT_WORKBENCH_HOME = Join-Path $env:LOCALAPPDATA "AgentWorkbench"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AgentWorkbench.ps1
```

升级时，安装脚本会保留已有的 `tasks`、`bugs`、`worktrees` 和 `discussions` 目录。

## 本版本验证情况

- 15 项仓库测试已在 Windows PowerShell 5.1 下通过。
- 正式发布提交已通过 GitHub Actions 的 Windows PowerShell 5.1 与 PowerShell 7 双环境验证，两种环境下 15 项测试均通过。
- 测试使用临时仓库和虚构 Agent 可执行文件，不需要真实模型凭据。
- 公开候选仓库不包含私人 runtime 目录和私人 Git 历史。

## 当前限制

- 目前只验证了 Windows 主机环境。
- 当前正式内置的非交互 adapter 只有 Claude Code 和 Reasonix。
- 其他控制器可以调用文件协议和 PowerShell 入口，但新增 worker/reviewer runtime 仍需实现 adapter。
- 外部 CLI 的网络、进程和文件权限仍受各自配置影响。
- `1.0.0` 之前公共 API 可能发生破坏性变化。
- 部分规范主持人文件名仍带有 Codex 取向。
- 当前没有 UI，也没有自动合并路径。

## 反馈

欢迎提交可复现的问题和聚焦的机制建议。请使用虚构示例，并在提交 Issue 前删除凭据、个人信息、私人源码、本机绝对路径和未经脱敏的 runtime 记录。

- 作者 ID：**LEVIUS**
- 联系邮箱：[agentworkbench@proton.me](mailto:agentworkbench@proton.me)

---

**Meaning** — *Living-Seeking-Meaning.* 追寻意义的过程即使没有结果，其本身也足够有意义。

> “Dedicated to all the pioneers.”——《Macross Plus》
