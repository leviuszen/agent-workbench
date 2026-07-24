# README Strategy Discussion and Read-Only Audit

## README 战略讨论与只读审计

> **Internal dogfooding / 内部 dogfooding**
>
> This case shows Meaning Assurance reviewing its own public README. It is not
> a third-party audit, independent validation, certification, or evidence of
> product effectiveness.
>
> 本案例展示 Meaning Assurance 如何审视自己的公开 README。它不是第三方审计、
> 独立验证、认证，也不是产品有效性证据。

## Case at a Glance / 案例概览

| Item / 项目 | Record / 记录 |
|---|---|
| Subject / 对象 | The public README communication strategy / 公开 README 传播策略 |
| Date / 日期 | 2026-07-25 |
| Mode / 模式 | `strategy-review` |
| Protocol / 协议 | `adversarial-discussion` |
| Audit profile / 审计配置 | `scientific` |
| External reviewer / 外部 Reviewer | Claude Code |
| Moderator / 裁决者 | Codex |
| Human authority / 人类权力 | The user authorized the work and retains final acceptance / 用户授权工作并保留最终接受权 |
| Evidence / 证据 | 9 frozen public files with SHA-256 hashes / 9 个带 SHA-256 的冻结公开文件 |
| Final state / 最终状态 | `decision_ready` |
| Outcomes / 结果 | 5 confirmed · 2 rejected · 2 duplicate · 1 not testable |

## Read the Record / 阅读记录

- [Strategy discussion / 战略讨论](strategy-discussion.md) — the initial
  strategic challenge, Codex's counter-challenge, and the Round 2 response.
- [Read-only audit / 只读审计](read-only-audit.md) — frozen evidence,
  finding-by-finding moderation, evidence boundaries, and artifact digests.

## What Happened / 发生了什么

1. Codex froze nine public repository files. Claude Code received the copies,
   not mutable source paths.
2. Claude Code produced a blind Round 1 strategy review with adversarial
   questions, evidence, counter-evidence, falsifiers, and recommendations.
3. Codex accepted some concerns, rejected unsupported claims, and issued eight
   targeted Round 2 questions.
4. Claude Code withdrew two findings, narrowed several claims, and supplied
   stable finding IDs.
5. Codex recorded every material outcome as `confirmed`, `rejected`,
   `duplicate`, or `not-testable`.

1. Codex 冻结了 9 个公开仓库文件。Claude Code 读取的是副本，而不是可变的源路径。
2. Claude Code 在 blind Round 1 中给出战略审视，包括对抗性问题、证据、反证、
   可证伪条件和建议。
3. Codex 接受部分问题，驳回缺乏证据的判断，并提出 8 个针对性 Round 2 追问。
4. Claude Code 撤回 2 项 finding，收窄多项判断，并补充稳定 finding ID。
5. Codex 将每项重要结果记录为 `confirmed`、`rejected`、`duplicate` 或
   `not-testable`。

## Publication Boundary / 公开边界

The repository publishes a curated, bilingual decision record. Local absolute
paths, process IDs, launcher details, invocation logs, credentials, and other
machine-specific runtime metadata are intentionally omitted. The record keeps
the questions, evidence identifiers, challenged conclusions, final outcomes,
and SHA-256 provenance needed to inspect the reasoning.

仓库公开的是经过整理的双语决策记录。本机绝对路径、进程 ID、启动器细节、调用
日志、凭据和其他机器特定运行元数据被有意省略；记录保留了检查推理所需的问题、
证据标识、受挑战结论、最终结果和 SHA-256 来源信息。
