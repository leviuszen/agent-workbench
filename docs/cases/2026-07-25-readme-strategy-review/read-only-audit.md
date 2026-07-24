# Read-Only Audit Record

## 只读审计记录

> **Scope / 范围:** one frozen public snapshot, one bounded external reviewer,
> two review rounds, and Codex moderation. The reviewer had no source-edit,
> merge, publication, or acceptance authority.
>
> 一个冻结公开快照、一个有边界外部 Reviewer、两轮复审和 Codex 裁决。Reviewer
> 没有源文件修改、合并、发布或接受权。

## 1. Audit Method / 审计方法

```text
9 public files
      ↓ frozen copies + SHA-256
blind Round 1: Claude Code
      ↓ findings + evidence + counter-evidence + falsifiers
Codex synthesis
      ↓ accepted, challenged, rejected, not-testable
targeted Round 2: Claude Code
      ↓ revised and withdrawn findings
Codex outcome record
      ↓
human final acceptance
```

The source files were not changed during either reviewer round. Round 2 used
the same frozen evidence package as Round 1. A source change would require a
fresh discussion and new hashes.

两轮 Reviewer 期间源文件没有发生变更。Round 2 与 Round 1 使用同一套冻结证据。
如果源文件发生变化，就必须创建新的讨论和哈希。

## 2. Frozen Evidence / 冻结证据

Snapshot created at `2026-07-25T00:07:46+08:00`.

| ID | Public source / 公开源文件 | Bytes | SHA-256 |
|---|---|---:|---|
| `ref-001` | `README.md` | 11,893 | `EFF9A3779660759029C88D27EFD35FD0424974EA9838B97F6E74B92597E82F6C` |
| `ref-002` | `docs/PROJECT_MESSAGE_FRAMEWORK.md` | 39,693 | `C4D7DA1CF62C9D2DF3D3D522AAA87E2C7EFB57D1891E35AC3FB646C283052CE7` |
| `ref-003` | `docs/README_COMMUNICATION_AUDIT.md` | 26,739 | `D1D7ADCEE1CBD956506D53552E6E95FFA1B23D15FDD5FE2C46EBC11F2BC59AAD` |
| `ref-004` | `docs/RELEASE_MESSAGING.md` | 13,824 | `D1022BF767D76B6D01C5C1AC5EE6F398C61BE04AD08E44EBDAB12FA6D9CEC692` |
| `ref-005` | `docs/PROTOCOL.md` | 1,378 | `3763E077DD868D8ED83A675D668BB1284FA044FC625C66A8B3B22780F19FBD97` |
| `ref-006` | `docs/ARCHITECTURE.md` | 1,564 | `6B2727D101887BB2886D818D62523975F21CB45719749957E44E4B41149488DA` |
| `ref-007` | `docs/PRIVACY.md` | 1,239 | `2E09E810E3C5E7CE52A74F604C4EFEEE92A1FAFFF8D8214131B236E110AE456F` |
| `ref-008` | `SECURITY.md` | 1,636 | `28F3389A5ADE4F0A9462D39DBFE421BAB3853378BCF060EB24127CEDB1EF7E2E` |
| `ref-009` | `docs/EXAMPLES.md` | 6,761 | `ACFD0FD7211C71877865671B4689F73BCE70BA6541041B01E3C991DADA7DFA23` |

The test directory and CI configuration were not in this packet. The audit
therefore did not infer their contents.

测试目录和 CI 配置不在本次参考包内，因此本审计没有推断它们的内容。

## 3. Moderated Findings / 经裁决的 Findings

| ID | Severity | Reviewer conclusion / Reviewer 结论 | Codex outcome | Public action / 公开处理 |
|---|---|---|---|---|
| `CL-R2-001` | Medium | Sequential bilingual blocks create a density risk. / 顺序双语块带来密度风险。 | **Confirmed** | Non-blocking; preserve both languages and defer reader testing. / 非阻断；保留双语，读者测试后置。 |
| `CL-R2-002` | Medium | Product scope needs a closer bridge to v0.1.0. / 产品范围需要更近的 v0.1.0 桥接。 | **Duplicate** | Existing text already states Public Preview, Windows-first, and PowerShell immediately after the definition table. / 现有定义表后已写明 Public Preview、Windows-first 和 PowerShell。 |
| `CL-R2-003` | Medium | `Synchronized confidence` must not imply that agreement is usually wrong. / “同步的自信”不能暗示一致意见通常错误。 | **Confirmed** | Existing qualifier remains: agreement can be useful, but is not proof. / 保留现有限定：一致可供参考，但不是证明。 |
| `CL-R2-004` | Low | Future bilingual enforcement could not be determined. / 无法判断未来双语规则如何执行。 | **Not testable** | Test and CI files were outside the frozen packet. / 测试和 CI 文件不在冻结包内。 |
| `CL-R2-005` | Medium | A self-referential case is publishable only with explicit framing. / 自我指涉案例只有在明确边界下才可公开。 | **Confirmed** | Publish as internal dogfooding, not external validation. / 作为内部 dogfooding 公开，不作为外部验证。 |
| `CL-R2-006` | Medium | Failure and recovery behavior deserves visible explanation. / 失败与恢复行为值得显性说明。 | **Confirmed** | Demonstrate it in the case while preserving the compact hero. / 在案例中展示，同时保持首屏紧凑。 |
| `CL-R2-007` | Low | The terminal image is used twice across two languages. / “与终端争论”意象在两种语言中使用两次。 | **Rejected** | A meaning-equivalent translation is not a second independent marketing use. / 含义等价翻译不是第二次独立营销使用。 |
| `CL-R2-008` | Low | Repository slug and product name need another orientation sentence. / 仓库 slug 与产品名需要额外说明。 | **Duplicate** | The H1 title, `by LEVIUS`, release link, and repository URL already establish the relationship. / H1 标题、`by LEVIUS`、Release 链接和仓库 URL 已建立关系。 |
| `CL-R2-009` | Low | GEO measurement has no baseline. / GEO 测量没有基线。 | **Confirmed** | Keep it explicitly deferred; make no effectiveness claim. / 明确后置，不声称有效性。 |
| `CL-R2-010` | Low | The closing Meaning quotation may reduce technical trust. / Meaning 收尾引语可能降低技术信任。 | **Rejected** | It is outside the first-contact path and no harm evidence was supplied. / 它不在首屏路径，也没有伤害证据。 |

### Outcome distribution / 结果分布

| Outcome | Count | Meaning / 含义 |
|---|---:|---|
| `confirmed` | 5 | Evidence or bounded reasoning supports the finding. / 证据或有边界推理支持该 finding。 |
| `rejected` | 2 | The conclusion was unsupported or strategically invalid. / 结论缺乏支持或战略上不成立。 |
| `duplicate` | 2 | The concern was already addressed by current text. / 现有文本已处理该问题。 |
| `not-testable` | 1 | The frozen evidence was insufficient to decide. / 冻结证据不足以判断。 |

## 4. What the Audit Changed / 审计改变了什么

The audit did not authorize a broad rewrite. It changed the communication layer
in one high-leverage way: the README now links to a real strategy discussion
and outcome ledger instead of describing adversarial review only in the
abstract.

审计没有授权大范围重写。它只推动了一项高杠杆传播改动：README 现在链接到真实
战略讨论和 outcome 台账，而不是只抽象描述对抗性复审。

It also prevented four regressions:

- hiding or subordinating Chinese;
- inventing a cross-platform roadmap;
- presenting an unsupported GitHub ranking claim as fact; and
- treating model agreement as acceptance.

它还阻止了四种回退：

- 隐藏或降低中文层级；
- 虚构跨平台路线图；
- 把没有证据的 GitHub 排序判断当作事实；
- 把模型一致意见当成接受结论。

## 5. Audit Artifact Digests / 审计产物摘要

| Artifact / 产物 | SHA-256 |
|---|---|
| `brief.md` | `EDCC36B32EEB2EA64D68E8F6BBBF0C114BD9E2ED4B3D341168A86A5CDFEB80A9` |
| `round1/claude-code.md` | `C26EF04E7C31C7E518E4917A59D85F8EBF237CF236BBC04E34B389217CC938A7` |
| `codex-synthesis.md` | `E4F6052A21C91C4616FA2B7B4E621B0D63871F9E59AE207E8694BC4A91FA82BF` |
| `round2/claude-code.md` | `8085C404120648C6E5EFED2A2DD3172873811058E2C56CB07C669CF797287122` |
| `decision.md` | `D2464AA15A6D075005979C79EED180D3D2905C9F68BDE57CB6BAC3AC938E51D0` |
| `findings.json` | `82EC04DCB6100E4E61C27094053B0353BC57A31D218073025B6F8BBDAB71D568` |
| `disagreement-matrix.md` | `876C08373D24425BA68EFBCD51B0FA63F78318BF97765B88F15868CE06B60400` |
| `calibration-events.jsonl` | `1C4AD0A18895073E992FEFE5B1F8B34C929EA29FA7488CA1B110755E95671E36` |

These hashes identify the canonical local evidence behind this curated record.
They are provenance identifiers, not proof that the strategic recommendations
are effective.

这些哈希标识了本整理记录背后的本地 canonical 证据。它们是来源标识，不证明
战略建议有效。

## 6. Final Boundary / 最终边界

This audit establishes that the documented process ran to a moderated decision
against a frozen public packet. It does not establish that the README converts
better, ranks better, is more trusted, or that Meaning Assurance guarantees
correctness.

本审计只证明：文档化流程围绕一个冻结公开参考包运行到了经过裁决的决定。它不
证明 README 转化更好、排名更高、更受信任，也不证明 Meaning Assurance 保证
正确。

[Back to the case index / 返回案例索引](README.md) ·
[Read the strategy discussion / 阅读战略讨论](strategy-discussion.md)
