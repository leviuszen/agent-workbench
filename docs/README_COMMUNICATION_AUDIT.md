# README Communication Audit

Status: Stage 1 audit accepted for README implementation on 2026-07-24.

This document evaluates the public README as a first-contact explanation of the
project. It does not change the product scope, technical architecture, release
status, or evidence standard.

## Audit baseline

- Repository: `https://github.com/leviuszen/agent-workbench`
- Source of truth: the public checkout at the audited revision
- Audited revision: `acecf5977fc78f895b1e73f573a2d4957aae532b`
- Public release: `v0.1.0` Public Preview
- Audience of this audit: a developer or technical reader seeing the repository
  for the first time

## Source hierarchy

This audit is a communication-order assessment, not a new positioning authority.
The existing repository sources retain these responsibilities:

1. `docs/RELEASE_MESSAGING.md` is the factual messaging and release-claim
   baseline.
2. `docs/PROTOCOL.md`, `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, and
   `SECURITY.md` define the implemented mechanism and its boundaries.
3. The current `README.md`, `AUTHORS.md`, and bilingual release notes establish
   the existing public use of Meaning and the LEVIUS author identity.
4. This audit identifies what the current README should foreground, retain, or
   move. It may propose a messaging delta, but it does not silently replace the
   existing messaging strategy.
5. `docs/PROJECT_MESSAGE_FRAMEWORK.md` records the candidate message decisions
   for this README refactoring. Any conflict with the sources above must be
   resolved explicitly before README editing.

## Executive finding

The current README is technically coherent and unusually explicit about
boundaries. It explains the mechanism, operating environment, workflows, review
gates, privacy model, limitations, and installation path.

Its communication weakness is ordering rather than missing technical substance:
it introduces the product as a local-first file-backed harness before making the
reader feel the problem that requires this kind of governance. The reader can
understand what the current repository does, but must read further to understand why
additional coding-agent output creates a trust and acceptance problem.

The next revision should therefore change the explanatory sequence, not inflate
the claims:

```text
familiar scene -> doubt -> counterintuitive question -> project position
-> product answer -> verifiable evidence
```

## First-screen assessment

### What the current first screen tries to solve

The opening currently answers these questions in this order:

1. What is this project? A local-first, file-backed harness for bounded work
   and review before acceptance.
2. What environment does it use? Windows-first PowerShell, with no hosted
   control plane.
3. How is it organized? By replaceable controller, worker, reviewer, and human
   roles rather than a fixed agent trio.
4. Why does it exist? To keep delegation bounded, evidence inspectable, retries
   deterministic, and final decisions under human control.

This is accurate, but the first sentence is a product description rather than a
recognition point for a developer who has already used coding agents.

### Thirty-second comprehension test

| Question | Current result | Assessment |
|---|---|---|
| Why might I need it? | Partially answered by the later `Why It Exists` section. | The trust and acceptance problem arrives too late. |
| What new problem does it address? | Bounded delegation, moving evidence, retries, review, and acceptance are described. | Present, but not yet compressed into one memorable conflict. |
| How is it different from ordinary multi-agent orchestration? | The role model and evidence-based moderation imply the distinction. | The explicit governance-versus-orchestration distinction is missing. |
| Why not just use Codex or Claude Code directly? | Not answered as a first-contact question. | Must be answered without attacking either tool. |
| Can I tell what it does in thirty seconds? | Mostly. | The mechanism is clear; the reason to care is weaker. |
| Can I retell the idea to someone else? | Not yet in one distinctive phrase. | `Synchronized confidence` can provide a memorable concept if it is defined precisely. |
| Can an AI answer system identify the entity, problem, mechanism, and boundary? | The facts exist across several sections. | The next opening needs concise, stable answer units and evidence links. |

### Current strengths to preserve

- The project is described as a mechanism, not as a fixed vendor bundle.
- Bounded task packets, isolated worktrees, frozen evidence, reviewer gates,
  moderation, and human acceptance are concrete capabilities already present in
  the README.
- The README explicitly says there is no automatic merge or patch application.
- The privacy model says runtime data can contain sensitive source, prompts,
  paths, and agent output.
- The limitations section avoids implying an operating-system sandbox, a UI, or
  stable public API.
- The release, installation, protocol, privacy, and contribution links provide
  a useful technical path after the reader understands the problem.

## Information architecture recommendation

### Content suitable for the first screen

Keep or move forward only the smallest set needed to establish the public
meaning of the project:

1. Product name, compact author attribution, and public-preview status:
   `Meaning Assurance` with `by LEVIUS`.
2. The familiar event: `Your coding agent says: "Done."`
3. No more than three primary questions: belief, evidence, and whether agreement
   is evidence or synchronized confidence.
4. The project position: agents can produce answers but should not approve their
   own work.
5. A one-sentence definition of Meaning Assurance as an assurance layer.
6. A mechanism-and-boundary summary immediately supporting that definition.
7. Restrained CTAs to inspect the protocol, evidence trail, and installation.

`Meaning` is the brand umbrella, `Assurance` is the function-derived product
word, and `LEVIUS` is the public author identity. Assurance denotes a governed
verification process, not a guarantee of correctness. The first screen
should not lead with an exhaustive capability list, installation variables,
provider names, or infrastructure exclusions.

### Dual-audience first-screen structure

The first screen must serve two readers without splitting into two unrelated
messages:

```text
Human attention:
recognition -> tension -> memorable concept -> retained agency -> action

AI/GEO answerability:
entity -> problem -> mechanism -> boundary -> evidence link
```

The same copy should satisfy both paths. The human-facing hook earns attention;
the machine-answerable definition and evidence structure prevent the hook from
becoming vague marketing.

Recommended hierarchy:

```text
Meaning Assurance
by LEVIUS
-> “Done” recognition scene
-> belief and evidence questions
-> synchronized-confidence contrast
-> no self-approval position
-> stable product definition
-> mechanism and boundary summary
-> protocol / evidence trail / install CTAs
```

Human communication rules:

- use the “arguing with the same terminal” image at most once;
- use no more than three primary hero questions;
- answer the questions before expanding into technical detail;
- define `synchronized confidence` as agreement without demonstrated independent
  verification;
- avoid `always`, guaranteed trust, manufactured urgency, invented adoption,
  and unsupported outcome claims;
- make the final movement restore reader agency rather than prolong anxiety.

AI/GEO rules:

- place the entity definition, brand relationship, problem, mechanisms, and
  boundaries in visible text under descriptive headings;
- use concise answer paragraphs, tables, FAQ-style questions, and stable anchors;
- link claims to protocol, architecture, privacy, security, or installation
  evidence;
- keep English and Chinese semantically equivalent;
- map content to user intents rather than repeating keywords;
- do not claim ranking, citation, or crawler access as guaranteed.

This reflects current official platform guidance: Google says AI search features
need no special AI markup and continue to rely on normal search fundamentals;
OpenAI requires `OAI-SearchBot` access for inclusion in ChatGPT search summaries
and snippets; Bing recommends clear headings, concise sections, tables,
FAQ-style content, and evidence-supported claims for AI answer clarity.

Reference guidance:

- [Google Search Central: AI features and your website](https://developers.google.com/search/docs/appearance/ai-features)
- [OpenAI: Publishers and Developers FAQ](https://help.openai.com/en/articles/12627856-publishers-and-developers-faq)
- [Bing Webmaster Tools: AI Performance](https://www.bing.com/webmasters/help/ai-performance-9f8e7d6c)

### Content better placed after the first screen

Move or retain these sections after the core narrative has landed:

- detailed `Why It Exists` examples and failure modes;
- bounded task and discussion workflows;
- implementation and review paths;
- requirements and installation;
- provider-specific CLI configuration;
- privacy and runtime handling;
- test instructions;
- limitations, public API status, detailed author information, contact, and
  license.

These are valuable implementation facts, but they are not the best first-contact
sequence.

## Proposed communication spine

The public explanation should make this distinction explicit:

```text
Orchestration assigns work.
Governance defines how results are checked and who may accept them.
```

The spine should then connect each claim to an existing mechanism:

| Communication claim | Existing evidence in the repository |
|---|---|
| Keep delegation bounded | Task packets with explicit scope and expected outputs |
| Keep evidence from moving | Frozen, hashed reference snapshots |
| Challenge an agent's conclusion | Required reviewers, blind Round 1, targeted Round 2 |
| Prevent duplicate execution | PID-backed invocation leases |
| Avoid model voting | Evidence-based moderation and explicit outcomes |
| Keep final authority human | No automatic merge or patch application |

## Fact and claim boundaries

The next README revision must not introduce unsupported claims such as:

- trusted by developers;
- production proven;
- reduction of bugs or hours by a stated percentage;
- industry standard;
- scientifically proven;
- real user cases, benchmarks, or independent validation that are not already
  present as public evidence.

The phrase `scientific` may describe a structured audit profile or evidence
review format. It must not imply that the product has passed scientific
validation.

The communication must also preserve these negative boundaries:

- Meaning Assurance is not an autonomous coding agent.
- It does not replace Codex or Claude Code.
- It does not make an agent's output trustworthy merely because agents agree.
- A Git worktree is not an operating-system security sandbox.
- Runtime folders remain private by default.

## Measurement plan for a later README stage

“Maximum propagation” is a goal to test, not a result to claim. If the README
rewrite is later authorized and published, compare a pre-change baseline with:

### Human comprehension and propagation

- five-second recall: can a reader name the problem after scanning the hero?
- sixty-second explanation: can a reader explain the position, mechanism, and
  human acceptance boundary?
- concept recall: does the reader remember and correctly explain `synchronized
  confidence`?
- CTA behavior: which of protocol, evidence trail, and installation receives
  attention where observable?
- retelling quality: does a third-party description preserve the mechanism, or
  collapse into “another agent tool”?

### AI/GEO answer quality

- run a fixed query set covering entity, comparison, mechanism, safety,
  installation, privacy, and authorship;
- check whether answers preserve the Meaning / Meaning Assurance / LEVIUS
  relationship;
- check whether answers cite the repository and retain the no-self-approval,
  no-automatic-merge, and no-correctness-guarantee boundaries;
- where available, observe Bing AI Performance citations and grounding-query
  themes, plus ChatGPT referral traffic;
- record errors and missing evidence instead of treating citation count as
  authority, ranking, or causation.

## Acceptance criteria for the next stage

The message framework was accepted for README implementation on 2026-07-24.
The revised first screen should allow a first-time reader to explain within
about sixty seconds:

> Why the coding-agent era needs governance, not only more agents.

The revision should also pass these checks:

- every capability claim maps to an existing public mechanism;
- every communication change is reconciled with `docs/RELEASE_MESSAGING.md`;
- the Meaning -> Meaning Assurance -> by LEVIUS hierarchy is preserved;
- `assurance` is never presented as a guarantee of correctness;
- the hero contains no more than three primary questions and answers them;
- `synchronized confidence` is memorable but technically defined;
- a human reader can retell the problem, position, and product answer;
- an AI answer system can extract the entity, brand relationship, problem,
  mechanism, boundaries, and evidence links from visible text;
- the project remains role-based and replaceable rather than a fixed trio;
- no automatic merge, self-approval, OS-sandbox, or production claim appears;
- existing installation, protocol, privacy, and contribution links remain valid;
- the README remains useful to technical readers after the new opening;
- the final copy is understandable to both a human developer and an AI search
  or answer system without keyword stuffing.

## Stage boundary

Decision record: the human owner accepted this audit and authorized the README
implementation stage on 2026-07-24. The authorized documentation surface is
`README.md` plus the required reconciliation of `docs/RELEASE_MESSAGING.md`.
Visual assets, FAQ, social-preview, Release, repository rename, GitHub settings,
external publication, commit, and push remain outside this authorization.

---

# README 传播审计（中文对照）

状态：Meaning Assurance 传播层第一阶段审计；已于 2026-07-24 获准进入
README 实施。

本文把公开 README 作为第一次接触项目时的解释入口进行评估。不改变产品
范围、技术架构、发布状态或证据标准。

## 审计基线

- 仓库：`https://github.com/leviuszen/agent-workbench`
- 事实来源：审计版本对应的公开 checkout
- 审计版本：`acecf5977fc78f895b1e73f573a2d4957aae532b`
- 公开号：`v0.1.0` Public Preview
- 审计对象：第一次看到仓库的开发者或技术读者

## 来源层级

本审计只判断传播顺序，不建立新的平行定位权威。仓库中既有文件继续承担以下
职责：

1. `docs/RELEASE_MESSAGING.md` 是事实化传播定位和 Release 主张的基线。
2. `docs/PROTOCOL.md`、`docs/ARCHITECTURE.md`、`docs/PRIVACY.md` 和
   `SECURITY.md` 定义已经实现的机制与边界。
3. 当前 `README.md`、`AUTHORS.md` 和中英文 Release 说明构成 Meaning 品牌
   与 LEVIUS 作者身份已经公开使用的依据。
4. 本审计只判断 README 应当前置、保留或后移哪些内容。它可以提出传播增量，
   但不能静默替代既有传播策略。
5. `docs/PROJECT_MESSAGE_FRAMEWORK.md` 记录本轮 README 重构的候选表达决策。
   如果它与上述来源冲突，必须先显式解决，再修改 README。

## 总体结论

当前 README 技术上连贯，并且对边界的说明较为充分。它解释了机制、运行
环境、工作流、复审门、隐私模型、限制和安装路径。

它的传播问题主要是信息顺序，而不是技术内容不足：README 先把项目介绍
成“本地优先、文件驱动的 harness”，然后才解释为什么需要这种治理方式。
读者能够理解当前仓库做什么，但需要继续阅读才会理解为什么更多
Coding Agent 输出会带来信任和接受问题。

因此，下一版应当调整解释顺序，而不是增加夸张表述：

```text
熟悉的场景 -> 质疑 -> 反直觉问题 -> 项目立场
-> 产品答案 -> 可验证证据
```

## 首屏评估

### 当前首屏试图解决什么

当前开场大致按以下顺序回答问题：

1. 这个项目是什么：用于委托受控工作并在接受修改前复审结果的本地
   优先、文件驱动 harness。
2. 它运行在哪里：以 Windows 和 PowerShell 为主，不需要托管控制平面。
3. 它如何组织：按可替换的 controller、worker、reviewer 和人类角色组织，
   而不是绑定固定 Agent 三件套。
4. 它为什么存在：让委托有边界、证据可检查、重试可控，并让最终决定由人类
   保持。

这些内容都准确，但第一句话仍然是产品描述，而不是让已经使用过 Coding
Agent 的开发者产生“这正是我遇到的问题”的识别点。

### 三十秒理解测试

| 问题 | 当前结果 | 评估 |
|---|---|---|
| 我为什么可能需要它？ | 在后面的 `Why It Exists` 中部分回答。 | 信任和接受问题出现得太晚。 |
| 它解决了什么新问题？ | 描述了边界、证据、重试、复审和接受。 | 内容存在，但还没有压缩成一个易记的冲突。 |
| 它和普通 Multi-Agent 编排有什么区别？ | 角色模型和证据裁决暗示了区别。 | 尚未明确说出“编排”和“治理”的差异。 |
| 为什么不直接使用 Codex 或 Claude Code？ | 首次阅读时没有直接回答。 | 需要在不攻击任何工具的前提下回答。 |
| 三十秒内能说清它做什么吗？ | 基本可以。 | 机制清楚，但“为什么值得关心”较弱。 |
| 我能把这个概念转述给别人吗？ | 目前还缺少一个独特短语。 | 如果定义准确，“同步的自信”可以成为易记概念。 |
| AI 回答系统能识别实体、问题、机制和边界吗？ | 事实分散在多个章节。 | 新开场需要简洁稳定的答案单元和证据链接。 |

### 应保留的优势

- 项目被描述为一种机制，而不是固定的供应商组合。
- 任务包、隔离 worktree、冻结证据、reviewer 门、moderation 和人工接受权
  都是 README 中已有的具体能力。
- README 明确说明没有自动 merge 或自动应用 patch。
- 隐私模型明确说明 runtime 可能包含敏感源代码、提示词、路径和 Agent 输出。
- 限制章节没有暗示操作系统级沙箱、UI 或稳定的公开 API。
- Release、安装、协议、隐私和贡献指南链接为理解项目后的技术阅读提供了路径。

## 信息架构建议

### 适合放在首屏的内容

首屏只保留建立项目公共含义所需的最小集合：

1. 产品名称、简洁作者署名和 Public Preview 状态：`Meaning Assurance`，
   配合 `by LEVIUS`。
2. 熟悉事件：`你的 Coding Agent 说：“完成了。”`
3. 不超过三个主要问题：是否相信、检查什么证据、一致意见究竟是证据还是
   同步的自信。
4. 项目立场：Agent 可以生产答案，但不应批准自己的工作。
5. 将 Meaning Assurance 定义为 assurance layer 的一句话。
6. 立即支持该定义的机制和边界摘要。
7. 指向 protocol、证据链和 installation 的克制 CTA。

`Meaning` 是品牌母层，`Assurance` 是从功能中提炼出的产品词，`LEVIUS`
是公开作者身份。Assurance 表示受治理的核验过程，不是正确性保证。首屏不应
以完整能力清单、安装变量、供应商名称或基础设施排除项开场。

### 双受众首屏结构

首屏必须同时服务两类读者，但不能拆成两套互不相关的信息：

```text
人类注意与传播：
识别 -> 张力 -> 可记忆概念 -> 保留主体性 -> 行动

AI/GEO 答案抽取：
实体 -> 问题 -> 机制 -> 边界 -> 证据链接
```

同一套文案应同时满足两条路径。面向人的钩子赢得注意力；机器可抽取的定义和
证据结构负责避免钩子退化为空泛营销。

建议层级：

```text
Meaning Assurance
by LEVIUS
-> “完成了”的识别场景
-> 相信与证据问题
-> 同步自信的反差
-> 不允许自我批准的立场
-> 稳定产品定义
-> 机制与边界摘要
-> protocol / 证据链 / installation CTA
```

人类传播规则：

- “和同一个终端争论”的画面最多出现一次；
- Hero 的主要问题不超过三个；
- 在展开技术细节前先回答问题；
- 把“同步的自信”定义为“意见一致，但没有展示独立核验”；
- 避免“永远”、保证可信、人为制造紧迫、虚构采用和未经支持的结果主张；
- 最终推进应恢复读者的主体性，而不是延长焦虑。

AI/GEO 规则：

- 把实体定义、品牌关系、问题、机制和边界放在描述性标题下的可见文本中；
- 使用简短答案段、表格、FAQ 式问题和稳定锚点；
- 把主张链接到 protocol、architecture、privacy、security 或 installation
  证据；
- 保持中英文语义等价；
- 按用户问题意图组织内容，不重复堆砌关键词；
- 不保证排名、引用或抓取权限。

这与当前官方平台指导一致：Google 表示 AI 搜索功能不需要特殊 AI 标记，
仍依赖正常搜索基础；OpenAI 要求允许 `OAI-SearchBot` 访问，内容才有资格
进入 ChatGPT 搜索摘要和片段；Bing 建议使用清晰标题、简短章节、表格、
FAQ 式内容和有证据支持的主张，提升 AI 答案清晰度。

参考指导：

- [Google Search Central：AI features and your website](https://developers.google.com/search/docs/appearance/ai-features)
- [OpenAI：Publishers and Developers FAQ](https://help.openai.com/en/articles/12627856-publishers-and-developers-faq)
- [Bing Webmaster Tools：AI Performance](https://www.bing.com/webmasters/help/ai-performance-9f8e7d6c)

### 更适合放在首屏之后的内容

- 详细的 `Why It Exists` 示例和失败模式；
- 任务与 discussion 工作流；
- implementation path 和 review path；
- requirements 与 installation；
- provider-specific CLI 配置；
- privacy 和 runtime 处理；
- 测试说明；
- limitations、公开 API 状态、详细作者信息、联系邮箱和许可证。

这些都是重要的实现事实，但不是最好的首次接触顺序。

## 建议的传播主线

公开解释应明确写出：

```text
编排决定谁来工作。
治理规定结果如何被核验，以及谁有权接受。
```

随后把每个传播主张连接到仓库中已有的机制：

| 传播主张 | 仓库中的已有证据 |
|---|---|
| 让委托有边界 | 带有明确范围和预期输出的任务包 |
| 防止证据发生移动 | 冻结并哈希的引用快照 |
| 挑战 Agent 的结论 | required reviewer、blind Round 1 和 targeted Round 2 |
| 防止重复执行 | PID-backed invocation lease |
| 避免模型投票 | 基于证据的 moderation 和明确结果 |
| 保留人工接受权 | 不自动 merge 或应用 patch |

## 事实与主张边界

下一版 README 不得引入以下未经支持的说法：

- trusted by developers；
- production proven；
- 按某个百分比减少 bug 或节省时间；
- industry standard；
- scientifically proven；
- 未公开存在的真实用户、Benchmark 或独立验证。

`scientific` 只能用于描述结构化审计 profile 或证据复审方式，不能暗示
产品已经通过科学验证。

传播内容还必须保留以下否定边界：

- Meaning Assurance 不是 autonomous coding agent；
- 它不替代 Codex 或 Claude Code；
- Agent 之间达成一致，不会自动让输出可信；
- Git worktree 不是操作系统级安全沙箱；
- runtime 目录默认仍属于私有数据。

## 后续 README 阶段的测量计划

“最大化传播力”是需要检验的目标，不是可以预先宣称的结果。如果后续 README
重写获得授权并完成发布，应建立变更前基线并比较：

### 人类理解与传播

- 五秒记忆：扫过 Hero 后，读者能否说出项目解决的问题？
- 六十秒解释：读者能否说明项目立场、机制和人工接受边界？
- 概念记忆：读者是否记住并正确解释“同步的自信”？
- CTA 行为：在可观测条件下，protocol、证据链和 installation 哪个得到关注？
- 转述质量：第三方介绍是否保留机制，还是退化成“另一个 Agent 工具”？

### AI/GEO 答案质量

- 使用覆盖实体、比较、机制、安全、安装、隐私和作者身份的固定问题集；
- 检查答案是否保持 Meaning / Meaning Assurance / LEVIUS 的关系；
- 检查答案是否引用仓库，并保留“不允许自我批准、不自动 merge、不保证
  正确”的边界；
- 在可用时观察 Bing AI Performance 的引用和 grounding-query 主题，以及
  ChatGPT referral 流量；
- 记录错误和缺失证据，不能把引用次数当成权威、排名或因果关系。

## 下一阶段验收标准

消息框架已于 2026-07-24 获准进入 README 实施。修订后的首屏应当让第一次
阅读的人在约六十秒内说明：

> 为什么 Coding Agent 时代需要治理，而不只是更多 Agent。

修订还应通过以下检查：

- 每个能力主张都能映射到公开仓库中的已有机制；
- 每项传播变化都已与 `docs/RELEASE_MESSAGING.md` 对齐；
- Meaning -> Meaning Assurance -> by LEVIUS 层级得到保留；
- `assurance` 不被表述为正确性保证；
- Hero 的主要问题不超过三个，并且得到回答；
- “同步的自信”既容易记忆，又有技术定义；
- 人类读者能够转述问题、项目立场和产品答案；
- AI 回答系统可以从可见文本中抽取实体、品牌关系、问题、机制、边界和证据
  链接；
- 项目继续保持角色可替换，而不是固定三件套；
- 不出现自动 merge、自我批准、OS sandbox 或生产能力主张；
- 现有 installation、protocol、privacy 和 contribution 链接仍然有效；
- 新开场之后，README 对技术读者仍然有用；
- 最终文案同时适合人类开发者和 AI 搜索/问答系统理解，而不是关键词堆砌。

## 阶段边界

决策记录：项目所有者已于 2026-07-24 接受本审计并授权 README 实施阶段。
获授权的文档范围是 `README.md` 和必要的 `docs/RELEASE_MESSAGING.md` 对齐。
视觉资产、FAQ、social-preview、Release、仓库重命名、GitHub 设置、外部发布、
commit 和 push 仍不在本次授权范围内。
