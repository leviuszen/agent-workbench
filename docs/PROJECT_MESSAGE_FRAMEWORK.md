# Meaning Assurance Project Message Framework

Status: Stage 1 communication framework; accepted for README implementation on
2026-07-24.

This framework defines the message that a later README revision may express. It
is not a product-roadmap change, a user-case claim, or evidence of market
validation.

## Authority and relationship to existing messaging

This framework is a decision delta for the README communication-layer
refactoring. It does not create a second independent product-positioning source.

Use this source order:

1. `docs/RELEASE_MESSAGING.md` remains the factual positioning, audience,
   supported-claim, and release-validation baseline.
2. `docs/PROTOCOL.md`, `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, and
   `SECURITY.md` remain the authority for implemented behavior and boundaries.
3. This framework evaluates candidate opening messages and records which ones
   are adopted, revised, rejected, or left for human decision.
4. A later README rewrite may use this framework only after every messaging
   delta has been reconciled with the sources above.

## Project identity

Meaning Assurance is a local, file-backed assurance protocol for coding agents.
It lets bounded execution be delegated while keeping evidence reviewable and
final acceptance under human control.

The mechanism is role-based and replaceable. A controller coordinates the work,
workers execute bounded tasks, reviewers challenge results, and a human retains
the acceptance decision. Codex, Claude Code, Reasonix, and other tools may fill
roles when they honor the same artifact and evidence contracts; no fixed vendor
trio defines the product.

## Brand architecture

The approved public hierarchy is:

```text
Meaning                         brand umbrella
└── Meaning Assurance           product and project name
    └── by LEVIUS               public author signature
```

- `Meaning` is the parent brand and philosophical frame, expressed as
  `Meaning — Living-Seeking-Meaning.`
- `Assurance` is the function-derived product word: bounded execution,
  reviewable evidence, and human acceptance form an assurance process.
- `Meaning Assurance` is the formal public product name.
- `LEVIUS` is the public author and creator identity.
- The compact author signature is `by LEVIUS`.
- Existing repository, script, and CLI identifiers remain technical
  compatibility names until a separately authorized rename.

This brand layer establishes provenance and authorship. It is not a product
capability claim. `Assurance` means a governed verification process, not a
guarantee of correctness, and LEVIUS is not a controller, worker, reviewer, or
acceptance role in the protocol.

## Central problem

Coding agents are increasingly good at producing answers and changes. The hard
problem is no longer only how to obtain another answer. It is how to decide what
can be trusted, what evidence was actually inspected, whether a retry duplicated
work, and who is allowed to accept a result into the codebase.

An agent's tone can be more certain than the evidence it leaves behind. Asking
the same agent again—or adding another agent that inspects the same unstable
material—can produce synchronized confidence without independent verification.

The communication should make the reader recognize this situation without
claiming that agents are inherently dangerous or useless.

## Core principle

> More agents create more output—not automatically more certainty.

The supporting principle is:

> Agents propose. Evidence is verified. Humans decide what to accept.

These are communication anchors, not claims that every agent output is wrong or
that human review guarantees correctness.

## Candidate message decisions

| Candidate expression | Decision | Reason |
|---|---|---|
| `More agents create more output—not automatically more certainty.` | Adopt | `Not automatically` preserves the distinction between capacity and verified confidence without claiming that multi-agent work is useless. |
| `Your agent says: "Done." Do you believe it?` | Adopt as the opening hook | It activates a familiar uncertainty. It must be followed immediately by an evidence question so the page does not stop at fear or distrust. |
| `Or you—arguing with the same terminal until it gives you a more reassuring answer?` | Adopt once, then recover technical restraint | The image is concrete, lightly absurd, and easy to retell. Repetition would make the page sound theatrical. |
| `Is that evidence—or just synchronized confidence?` | Adopt as a concept label | It names the gap between agreement and independent verification. The page must define it instead of treating all agreement as worthless. |
| `The agent's tone is always more confident than its evidence.` | Reject | `Always` is an unsupported absolute. Use `can be more certain than the evidence` or another qualified form. |
| `Two agents agreeing is not proof.` | Adopt | This directly matches the protocol rule that reviewer agreement does not establish correctness. |
| `Agents propose. Evidence decides. Humans accept.` | Revise | Evidence does not decide by itself. The protocol requires verification, moderation, and human authority. |
| `Orchestration assigns work. Governance determines what can be trusted.` | Revise | Governance defines verification and acceptance rules; it does not determine truth by declaration. |
| The current repository title as the public product name | Retire from the communication layer | It describes a tool surface, not the assurance outcome that differentiates the project. Technical identifiers remain unchanged in this stage. |
| `Assurance` as the function-derived product word | Adopt | It compresses bounded execution, evidence review, and human acceptance into an established governance concept without naming a specific agent vendor. |
| `Meaning Assurance` as the public product name | Adopt | It combines the Meaning parent brand with the functional category and keeps `LEVIUS` available as a separate author signature. |

## One-sentence definition

> Meaning Assurance is a local, file-backed assurance protocol for coding agents:
> it delegates bounded execution, preserves review evidence, and keeps
> acceptance under human control.

Chinese rendering for bilingual communication:

> Meaning Assurance 是 Coding Agent 的 assurance layer：让执行可以被委托，让证据接受复核，并把最终接受权留给人类。

## Narrative sequence

The public explanation should follow this sequence:

```text
familiar scene
-> doubt
-> counterintuitive question
-> project position
-> product answer
-> verifiable evidence
```

### 1. Familiar scene

Your coding agent says “Done.”

This is a recognition prompt, not an accusation against the agent.

### 2. Doubt

Do you believe it? What evidence do you check before accepting it?

The belief question earns attention; the evidence question converts emotion into
an engineering problem.

### 3. Counterintuitive question

If another agent agrees, is that evidence—or synchronized confidence? A second
answer is not independent verification when it depends on the same moving source,
scope assumptions, or untested claim.

### 4. Project position

Agents are good at producing answers. They should not have the authority to
approve themselves.

### 5. Product answer

Meaning Assurance supplies the public mechanisms already present in the repository:

- bounded task and discussion packets;
- isolated Git worktrees for implementation workers;
- frozen and hashed reference snapshots for review;
- required reviewer gates, blind Round 1, and targeted Round 2;
- invocation leases to distinguish active work from safe retries;
- canonical result files and explicit moderation outcomes;
- no automatic merge or patch application.

### 6. Verifiable evidence and decision boundary

The system can structure execution and evidence. It does not turn model output
into truth, remove the need for judgment, or grant an agent authority to approve
itself.

## Message stack

### Hero direction

Provisional direction for a later README rewrite:

```text
Meaning Assurance
by LEVIUS

Your coding agent says: “Done.”

Do you believe it?

What evidence do you check before accepting it?

Without an independent review path, the fallback can become you—arguing with the
same terminal until the answer feels safer.

If another agent agrees, is that evidence—or synchronized confidence?

Agents are good at producing answers.
They should not have the authority to approve themselves.

Meaning Assurance is a local, file-backed assurance protocol for coding agents:
it delegates bounded execution, preserves review evidence, and keeps acceptance
under human control.
```

This is a direction for review, not final README copy. It should be tested for
technical restraint, readability, and compatibility with the existing public
release language before adoption.

### Approved title and attribution hierarchy

The public title is `Meaning Assurance`, with `by LEVIUS` as a subordinate
author signature. The repository, scripts, and CLI keep their current technical
identifiers in this stage. Writing the new public title into README still
requires separate README-edit authorization.

### Human marketing and psychology rules

The first screen should use psychology as an attention and comprehension aid,
not as a substitute for evidence:

1. **Recognition before explanation.** Open with the familiar “Done” event so a
   reader can place the product before learning new terminology.
2. **A bounded curiosity gap.** Ask no more than three primary questions in the
   hero, then answer them immediately. Do not prolong anxiety to manufacture
   engagement.
3. **Concrete imagery.** The “arguing with the same terminal” line may appear
   once in supporting copy because it is vivid and retellable.
4. **A distinctive concept label.** Define `synchronized confidence` as agent
   agreement without demonstrated independent verification.
5. **Agency preservation.** Move from uncertainty to the reader's retained
   authority: delegate work, inspect evidence, decide what to accept.
6. **Cognitive fluency.** Prefer short parallel sentences, one contrast at a
   time, and visible progression from claim to mechanism to evidence.
7. **Proof after promise.** Follow every major positioning statement with a
   repository mechanism or boundary the reader can inspect.

These are communication hypotheses, not demonstrated conversion results. A later
README should be evaluated with real reader comprehension, referral, and search
data rather than declaring the psychology effective in advance.

### Short phrases

- Your agent says it is done. What evidence did it leave?
- Is that evidence—or synchronized confidence?
- Two agents agreeing is not proof.
- Delegate the work. Verify the evidence. Keep the decision human.
- More agents. More output. Not automatically more certainty.
- No agent approves itself.
- Orchestration assigns work. Governance defines how results are checked and who
  may accept them.
- Do not stop at what the agent says. Inspect what it left behind.

### Mechanism proof points

Use concrete repository capabilities immediately after the central message.
Do not use generic AI language where a mechanism is available.

| Message | Public mechanism |
|---|---|
| Delegation needs a boundary | Explicit task scope and expected outputs |
| Review needs stable material | Frozen, inventoried, hashed references |
| Challenge must remain independent | Blind Round 1 and targeted Round 2 |
| Timeout recovery needs state | PID-backed invocation leases |
| Agreement is not proof | Evidence verification and moderation outcomes |
| Acceptance needs authority | Human decision and no automatic merge |

### Claim traceability

| Claim or boundary | Repository evidence |
|---|---|
| Existing messaging position and audience | `docs/RELEASE_MESSAGING.md` |
| Task and discussion packet contracts | `docs/PROTOCOL.md`, `scripts/New-AgentTask.ps1`, `scripts/New-AgentDiscussion.ps1` |
| Isolated implementation worktree and no automatic merge | `docs/ARCHITECTURE.md`, `scripts/New-AgentWorktree.ps1` |
| Frozen evidence and canonical reviewer files | `docs/PROTOCOL.md`, `scripts/New-AgentDiscussion.ps1`, `scripts/Collect-AgentDiscussion.ps1` |
| Structured findings and moderation outcomes | `docs/PROTOCOL.md`, `scripts/Record-AgentAuditOutcome.ps1` |
| Invocation leases and duplicate-review protection | `docs/ARCHITECTURE.md`, `scripts/Invoke-ClaudeFeedback.ps1`, `scripts/Invoke-ReasonixFeedback.ps1` |
| Runtime privacy and sandbox limitations | `docs/PRIVACY.md`, `SECURITY.md`, `docs/ARCHITECTURE.md` |
| Human final authority | `docs/ARCHITECTURE.md` |

## Audience framing

The message is for people who use or evaluate coding-agent workflows:

- developers delegating bounded implementation work;
- teams reviewing agent-produced code or design decisions;
- technical readers comparing orchestration with governance;
- maintainers who need durable evidence and restartable handoffs.

These are problem-based audience descriptions, not claims that the project has
already been adopted by these groups. Do not add named users, testimonials,
benchmarks, or invented case studies.

## Differentiation

The important distinction is not “more agents versus fewer agents.” It is:

```text
Orchestration decides who does the work.
Governance defines how results are checked and who may accept them.
```

Meaning Assurance is therefore not presented as:

- another chat transcript;
- a hosted multi-agent platform;
- an autonomous coding agent;
- a replacement for Codex or Claude Code;
- a fixed Codex/Claude Code/Reasonix product bundle;
- an OS-level security sandbox;
- an automatic merge system.

## FAQ seed questions

These questions should guide a later `docs/FAQ.md` or README FAQ section. They
are not yet a commitment to add that file:

1. Does Meaning Assurance replace Codex?
2. Does it replace Claude Code?
3. Does it make agents autonomous?
4. Does it automatically merge code?
5. Is a Git worktree a security sandbox?
6. Why freeze evidence?
7. Why is reviewer agreement not proof?
8. Who has final authority?
9. How does the current implementation coordinate Codex and Claude Code without
   making either one part of the permanent product definition?

Each answer should be short, factual, and traceable to the existing README,
protocol, architecture, privacy, or security documentation.

## AI/GEO discovery and answerability

GEO is treated here as accurate retrieval, extraction, citation, and answer
reuse—not as a promise of ranking. Current platform guidance supports the same
fundamentals as useful SEO: important information should be crawlable, textual,
clearly structured, and consistent with visible claims. Google states that its
AI search features require no special AI markup; OpenAI requires access for
`OAI-SearchBot` for inclusion in ChatGPT search summaries and snippets; Bing
recommends descriptive headings, concise sections, tables, FAQ-style content,
and evidence-supported claims for AI citation clarity.

The future README and FAQ should make these questions answerable without keyword
stuffing:

- What is the relationship between Meaning, Assurance, and LEVIUS?
- What problem does Meaning Assurance solve?
- How is it different from autonomous coding agents?
- How does Meaning Assurance coordinate Codex and Claude Code in the current
  implementation?
- How can a controller coordinate replaceable workers and reviewers?
- Why does human acceptance matter in coding-agent workflows?
- How does Meaning Assurance handle disagreement?

The homepage should provide five reusable answer units:

1. **Entity definition:** one stable sentence defining Meaning Assurance.
2. **Brand relationship:** Meaning is the parent brand, Meaning Assurance is the
   product, and LEVIUS is the public author identity.
3. **Problem statement:** agent output and agent agreement are not by themselves
   verified evidence.
4. **Mechanism summary:** bounded tasks, isolated worktrees, frozen evidence,
   independent review, visible disagreement, and human acceptance.
5. **Boundary summary:** no automatic merge, no self-approval, no OS-sandbox
   claim, and no guarantee of correctness.

Each unit should be:

- expressed in visible text rather than only in an image or badge;
- placed under a stable, descriptive heading;
- short enough to quote without losing the necessary boundary;
- internally linked to the relevant protocol, architecture, privacy, security,
  or installation section;
- semantically equivalent in English and Chinese;
- free of invented usage, benchmark, trust, or production claims.

Use a question-intent map rather than a keyword list:

| Intent | Homepage answer target |
|---|---|
| What is it? | Stable entity definition |
| Why does it exist? | “Done” scenario and synchronized-confidence problem |
| How does it work? | Mechanism summary and evidence trail |
| How is it different? | Orchestration-versus-assurance distinction |
| Is it safe or proven? | Explicit limitations and claim boundaries |
| How do I use it? | Protocol, evidence-trail, and installation links |

The current-implementation answer must say that Codex-oriented moderation and
the Claude Code adapter are one supported arrangement, not the product identity.
The general answer must explain the replaceable controller, worker, and reviewer
roles. Both answers must preserve the distinction between model output,
evidence, review, moderation, and human acceptance.

Do not add `llms.txt`, custom AI metadata, FAQ schema, or other machine-readable
files merely to claim GEO progress. Such changes require a separate technical
review and must match visible page content. GitHub-hosted crawl access is also a
platform condition, not something this README framework can guarantee.

Reference guidance:

- [Google Search Central: AI features and your website](https://developers.google.com/search/docs/appearance/ai-features)
- [OpenAI: Publishers and Developers FAQ](https://help.openai.com/en/articles/12627856-publishers-and-developers-faq)
- [Bing Webmaster Tools: AI Performance](https://www.bing.com/webmasters/help/ai-performance-9f8e7d6c)

## Claim discipline

Allowed claims must describe public mechanisms and documented boundaries. Avoid
or reject the following unless new public evidence is added and reviewed:

- “trusted by developers”;
- “production proven”;
- “reduces bugs by X%”;
- “saves X hours”;
- “industry standard”;
- “scientifically proven”;
- real user cases, independent validation, or benchmark results.

“Scientific audit” may be used only to describe a structured evidence-audit
profile or review style. It must not imply scientific validation of the product.

## Language governance

- The current public README and primary Release body are English-primary.
- The Chinese text is a required meaning-equivalent counterpart, not optional
  promotional copy.
- Locked messages, claim boundaries, title decisions, and FAQ answers must be
  updated in English and Chinese in the same change.
- The tokens `Meaning`, `Assurance`, `Meaning Assurance`, and `LEVIUS`, their
  hierarchy, and the attribution meaning must remain synchronized across both
  languages.
- A translation may improve natural phrasing, but it must not add capability,
  certainty, adoption, or safety claims absent from the other language.
- If the two versions conflict, stop the README rewrite and resolve the meaning
  before publication.

## Review gate before README editing

Before this framework is used to modify README, a human reviewer should confirm:

- the central principle accurately represents the project;
- the approved Meaning -> Meaning Assurance -> by LEVIUS hierarchy is
  preserved;
- `assurance` is described as a process and never as a correctness guarantee;
- the recognition prompt does not overstate agent failure;
- the hero uses no more than three primary questions and answers them before
  moving into technical detail;
- `synchronized confidence` is defined as a verification gap, not used as a
  blanket dismissal of multi-agent agreement;
- the human-facing hook is followed by a stable entity definition, mechanism
  summary, evidence links, and explicit boundaries suitable for AI extraction;
- the governance distinction does not change the technical product identity;
- every proposed proof point exists in the current public checkout;
- the message remains compatible with the `v0.1.0` public-preview status;
- the next stage may change only the authorized documentation files.

Decision record: on 2026-07-24, the human owner accepted this framework and
authorized the README implementation stage. That authorization covers
`README.md` and the required reconciliation of `docs/RELEASE_MESSAGING.md`; it
does not authorize FAQ, visual asset, social-preview, Release, repository rename,
external publication, or GitHub setting changes.

---

# Meaning Assurance 项目消息框架（中文对照）

状态：第一阶段传播框架；已于 2026-07-24 获准进入 README 实施。

本框架定义后续 README 可以表达的核心消息。它不是产品路线变更，不是用户
案例主张，也不是市场验证证据。

## 与既有传播规范的权威关系

本框架是 README 传播层重构的增量决策文件，不建立第二套独立产品定位。

来源顺序如下：

1. `docs/RELEASE_MESSAGING.md` 继续作为事实定位、目标受众、可支持主张和
   Release 传播验证的基线。
2. `docs/PROTOCOL.md`、`docs/ARCHITECTURE.md`、`docs/PRIVACY.md` 和
   `SECURITY.md` 继续作为已实现行为和边界的权威来源。
3. 本框架只评估候选开场表达，并记录哪些表达被保留、调整、拒绝或留给人类
   决定。
4. 后续 README 只有在所有传播增量都与上述来源完成对齐后，才能采用本框架。

## 项目身份

Meaning Assurance 是一套本地、文件化的 Coding Agent assurance 协议：让有边界的
执行可以被委托，同时让证据保持可复核，最终接受权仍由人类掌握。

它采用可替换的角色机制。controller 协调工作，worker 执行受控任务，reviewer
挑战结果，人类保留接受决定。Codex、Claude Code、Reasonix 或其他工具都可以
在遵守相同产物和证据合约时承担角色；任何固定的供应商三件套都不是产品定义。

## 品牌架构

已确认的公开层级为：

```text
Meaning                         品牌母层
└── Meaning Assurance           产品与项目名称
    └── by LEVIUS               公开作者署名
```

- `Meaning` 是品牌母层和理念框架，固定表达为
  `Meaning — Living-Seeking-Meaning.`
- `Assurance` 是从功能中提炼出的产品词：受控执行、可复核证据和人工接受共同
  构成 assurance 过程。
- `Meaning Assurance` 是正式公开产品名称。
- `LEVIUS` 是公开作者与创作者身份。
- 简洁作者署名使用 `by LEVIUS`。
- 现有仓库、脚本和 CLI 标识在本阶段继续作为技术兼容名称；重命名需要另行
  授权。

品牌层表达来源和作者归属，不构成产品能力主张。`Assurance` 表示受治理的
核验过程，不是正确性保证；LEVIUS 也不是协议中的 controller、worker、
reviewer 或 acceptance 角色。

## 核心问题

Coding Agent 越来越擅长生成答案和修改。真正困难的不再只是如何得到另一个
答案，而是如何判断什么可以被信任、reviewer 实际检查了哪些证据、重试是否
造成了重复工作，以及谁有权让结果进入代码库。

Agent 的语气可能比它留下的证据更确定。再次询问同一个 Agent，或增加一个
检查相同不稳定材料的 Agent，可能只会产生“同步的自信”，而不是独立核验。

传播时应让读者识别这个场景，但不能声称 Agent 天生危险或没有价值。

## 核心原则

> 更多 Agent 会带来更多输出，但不会自动带来更多确定性。

配套原则是：

> Agent 提出结果，证据接受核验，人类决定是否采纳。

这两句话是传播锚点，不是声称每个 Agent 输出都错误，也不是声称人工复审
能够保证正确。

## 候选表达裁决

| 候选表达 | 结论 | 理由 |
|---|---|---|
| `更多 Agent 会带来更多输出，但不会自动带来更多确定性。` | 保留 | “不会自动”准确区分了执行能力和经过核验的确定性，也没有否定 Multi-Agent 工作本身。 |
| `你的 Agent 说“完成了”。你真的相信吗？` | 作为开场钩子保留 | 它会唤醒熟悉的不确定感，但后面必须立即追问证据，不能让页面停留在恐惧或不信任。 |
| `还是你亲自和同一个终端争论，直到它给出更让你安心的回答？` | 只使用一次，随后恢复技术克制 | 画面具体、略带荒诞且容易复述；重复使用会让页面显得戏剧化。 |
| `那是证据，还是同步的自信？` | 作为概念标签保留 | 它准确命名“一致意见”和“独立核验”之间的缺口，但不能把所有一致意见都描述为无价值。 |
| `Agent 的语气永远比证据更自信。` | 拒绝 | “永远”是没有依据的绝对判断，应使用“可能比它留下的证据更确定”等限定表达。 |
| `两个 Agent 的一致意见不是证明。` | 保留 | 与协议中“reviewer 一致不等于正确”的规则直接一致。 |
| `Agent 提出结果，证据决定可信度，人类决定是否接受。` | 调整 | 证据不会自行作出决定；协议还要求 verification、moderation 和人工权限。 |
| `编排决定谁来工作，治理决定什么可以被信任。` | 调整 | 治理规定核验和接受规则，不通过宣告直接决定事实真假。 |
| 将当前仓库标题继续作为公开产品名 | 从传播层退役 | 它描述的是工具形态，而不是项目最有差异性的 assurance 结果；本阶段不改技术标识。 |
| 使用 `Assurance` 作为功能产品词 | 保留 | 它把受控执行、证据复核和人工接受压缩为成熟的治理概念，也不绑定具体 Agent 厂商。 |
| 使用 `Meaning Assurance` 作为公开产品名 | 保留 | 它组合 Meaning 母品牌和功能类别，并让 `LEVIUS` 保持为独立作者署名。 |

## 一句话定义

> Meaning Assurance 是一套本地、文件化的 Coding Agent assurance 协议：让有边界的执行可以被委托，保留可复查证据，并把最终接受权留给人类。

## 叙事顺序

公开解释应遵循以下顺序：

```text
熟悉的场景
-> 质疑
-> 反直觉问题
-> 项目立场
-> 产品答案
-> 可验证证据
```

### 1. 熟悉的场景

你的 Coding Agent 说“完成了”。

这是一个识别问题，不是对 Agent 的指控。

### 2. 质疑

你真的相信吗？在接受它之前，你会检查什么证据？

“相信吗”负责赢得注意力，“什么证据”负责把情绪转换成工程问题。

### 3. 反直觉问题

如果另一个 Agent 也同意，那是证据，还是同步的自信？如果两个 Agent 依赖
相同的移动源文件、范围假设或未经测试的主张，第二个答案仍然不是独立核验。

### 4. 项目立场

Agent 擅长生产答案，但不应该拥有批准自己的权力。

### 5. 产品答案

Meaning Assurance 在公开仓库中已经具备以下机制：

- 有边界的任务包和 discussion 包；
- implementation worker 使用隔离 Git worktree；
- 用于复审的冻结、哈希化引用快照；
- required reviewer、blind Round 1 和 targeted Round 2；
- 用 invocation lease 区分活动中的工作和安全重试；
- 规范化结果文件和明确的 moderation 结果；
- 不自动 merge 或应用 patch。

### 6. 可验证证据与决策边界

系统可以组织执行和证据，但不会把模型输出变成事实，不会取消判断，也不会
授予 Agent 自我批准的权限。

## 消息层级

### 首屏方向

供后续 README 重写审核的临时方向：

```text
Meaning Assurance
by LEVIUS

你的 Coding Agent 说：“完成了。”

你真的相信吗？

在接受它之前，你会检查什么证据？

如果没有独立复审路径，最后可能还是你亲自和同一个终端争论，直到答案听起来
更让人安心。

如果另一个 Agent 也同意，那是证据，还是同步的自信？

Agent 擅长生产答案，
但不应该拥有批准自己的权力。

Meaning Assurance 是一套本地、文件化的 Coding Agent assurance 协议：让有边界的执行可以被委托，保留可复查证据，并把最终接受权留给人类。
```

这是审核方向，不是最终 README 文案。采用前仍需检查技术克制、可读性以及
与现有公开发布语言的兼容性。

### 已确认的标题与归属层级

公开标题使用 `Meaning Assurance`，并以 `by LEVIUS` 作为次级作者署名。
本阶段保留仓库、脚本和 CLI 的当前技术标识。把新公开标题实际写入 README
仍需要单独的 README 修改授权。

### 人类营销与心理学规则

首屏可以利用心理机制帮助注意和理解，但不能用心理刺激替代证据：

1. **先识别，后解释。** 用熟悉的“完成了”事件开场，让读者先定位问题，再
   学习新术语。
2. **有边界的好奇缺口。** Hero 中主要问题不超过三个，并立即给出答案；不能
   通过持续制造焦虑换取停留。
3. **具体画面。** “和同一个终端争论”可在辅助文案中出现一次，因为它具体、
   略带荒诞且容易转述。
4. **独特概念标签。** 把“同步的自信”定义为“Agent 意见一致，但没有展示
   独立核验”。
5. **保留主体性。** 从不确定感转向读者仍然掌握的权力：委托工作、检查证据、
   决定是否接受。
6. **认知流畅。** 使用短句、平行结构和单一对比，让读者看到从主张到机制再
   到证据的推进。
7. **承诺之后给证据。** 每项重要定位后面都应紧跟可检查的仓库机制或边界。

这些是传播假设，不是已经证明的转化效果。后续 README 应通过真实读者理解、
转述、引荐和搜索数据评估，不能预先宣称心理策略有效。

### 短句

- Agent 说任务完成了。它留下了什么证据？
- 那是证据，还是同步的自信？
- 两个 Agent 的一致意见不是证明。
- 委托执行，核验证据，把决定留给人。
- 更多 Agent，更多输出，不会自动带来更多确定性。
- 没有 Agent 可以批准自己。
- 编排决定谁来工作；治理规定结果如何被核验，以及谁有权接受。
- 不要停留在 Agent 怎么说，检查它实际留下了什么。

### 机制证据点

核心消息之后应立即使用仓库中的具体能力，不要用泛化的 AI 语言替代机制。

| 消息 | 公开机制 |
|---|---|
| 委托需要边界 | 明确任务范围和预期输出 |
| 复审需要稳定材料 | 冻结、清单化并哈希化的引用文件 |
| 挑战必须保持独立 | blind Round 1 和 targeted Round 2 |
| 超时恢复需要状态 | PID-backed invocation lease |
| 一致意见不是证明 | 证据核验和 moderation 结果 |
| 接受需要权力边界 | 人工决定和不自动 merge |

### 主张追溯表

| 主张或边界 | 仓库证据 |
|---|---|
| 既有传播定位和目标受众 | `docs/RELEASE_MESSAGING.md` |
| 任务包和 discussion 包合约 | `docs/PROTOCOL.md`、`scripts/New-AgentTask.ps1`、`scripts/New-AgentDiscussion.ps1` |
| 隔离 implementation worktree 和不自动 merge | `docs/ARCHITECTURE.md`、`scripts/New-AgentWorktree.ps1` |
| 冻结证据和规范 reviewer 文件 | `docs/PROTOCOL.md`、`scripts/New-AgentDiscussion.ps1`、`scripts/Collect-AgentDiscussion.ps1` |
| 结构化 findings 和 moderation 结果 | `docs/PROTOCOL.md`、`scripts/Record-AgentAuditOutcome.ps1` |
| invocation lease 和防重复 reviewer | `docs/ARCHITECTURE.md`、`scripts/Invoke-ClaudeFeedback.ps1`、`scripts/Invoke-ReasonixFeedback.ps1` |
| runtime 隐私和沙箱限制 | `docs/PRIVACY.md`、`SECURITY.md`、`docs/ARCHITECTURE.md` |
| 人类最终决定权 | `docs/ARCHITECTURE.md` |

## 受众表达

消息面向使用或评估 Coding Agent 工作流的人：

- 委托有边界实现任务的开发者；
- 复审 Agent 生成代码或决策的团队；
- 比较 orchestration 与 governance 的技术读者；
- 需要持久证据和可恢复交接的维护者。

这些是基于问题的受众描述，不是声称项目已经被这些群体采用。不得添加具名
用户、推荐语、Benchmark 或虚构案例。

## 差异化

关键区别不是“更多 Agent”对“更少 Agent”，而是：

```text
编排决定谁来工作。
治理规定结果如何被核验，以及谁有权接受。
```

因此，Meaning Assurance 不应被描述为：

- 又一个聊天记录；
- 托管式 Multi-Agent 平台；
- autonomous coding agent；
- Codex 或 Claude Code 的替代品；
- 固定的 Codex/Claude Code/Reasonix 产品组合；
- 操作系统级安全沙箱；
- 自动 merge 系统。

## FAQ 种子问题

这些问题可作为后续 `docs/FAQ.md` 或 README FAQ 章节的输入，但目前不等于
已经承诺新增该文件：

1. Meaning Assurance 会替代 Codex 吗？
2. 它会替代 Claude Code 吗？
3. 它会让 Agent 自主运行吗？
4. 它会自动 merge 代码吗？
5. Git worktree 是安全沙箱吗？
6. 为什么要冻结证据？
7. 为什么 reviewer 一致意见不是证明？
8. 谁拥有最终接受权？
9. 当前实现如何协调 Codex 和 Claude Code，同时避免把它们写成永久产品定义？

每个答案都应简短、事实化，并能追溯到现有 README、protocol、architecture、
privacy 或 security 文档。

## AI/GEO 发现与答案抽取

这里的 GEO 指准确检索、抽取、引用和答案复用，不承诺排名。当前平台指导仍然
强调有用 SEO 的基础：重要信息应当可抓取、以可见文本表达、结构清楚，并与
页面上的公开主张一致。Google 说明 AI 搜索功能不需要特殊 AI 标记；OpenAI
要求允许 `OAI-SearchBot` 访问，内容才有资格进入 ChatGPT 搜索摘要和片段；
Bing 建议使用描述性标题、简短章节、表格、FAQ 式内容和有证据支持的主张，
帮助 AI 清楚引用。

未来 README 和 FAQ 应让以下问题能够被回答，但不能进行关键词堆砌：

- Meaning、Assurance 与 LEVIUS 之间是什么关系？
- Meaning Assurance 解决什么问题？
- 它与 autonomous coding agent 有什么区别？
- 当前实现如何协调 Codex 和 Claude Code？
- controller 如何协调可替换的 worker 和 reviewer？
- 为什么 Coding Agent 工作流需要人工接受？
- Meaning Assurance 如何处理分歧？

主页应提供五个可复用答案单元：

1. **实体定义：** 用一个稳定句子定义 Meaning Assurance。
2. **品牌关系：** Meaning 是品牌母层，Meaning Assurance 是产品，LEVIUS
   是公开作者身份。
3. **问题定义：** Agent 输出和 Agent 一致意见本身都不是经过核验的证据。
4. **机制摘要：** 有边界任务、隔离 worktree、冻结证据、独立复审、显性分歧
   和人工接受。
5. **边界摘要：** 不自动 merge、不允许自我批准、不声称 OS 级沙箱，也不
   保证正确。

每个答案单元都应：

- 使用可见文本表达，不能只存在于图片或 badge；
- 放在稳定、描述性的标题下；
- 足够简短，可以被引用，同时不丢失必要边界；
- 内部链接到相应 protocol、architecture、privacy、security 或 installation；
- 中英文语义等价；
- 不包含虚构的使用、Benchmark、信任或生产级主张。

使用问题意图表，而不是关键词清单：

| 意图 | 主页答案目标 |
|---|---|
| 它是什么？ | 稳定实体定义 |
| 为什么存在？ | “完成了”场景与同步自信问题 |
| 如何工作？ | 机制摘要和证据链 |
| 有什么不同？ | orchestration 与 assurance 的区别 |
| 它安全吗、经过证明了吗？ | 明确限制和主张边界 |
| 如何使用？ | protocol、证据链和 installation 链接 |

对当前实现的回答必须说明：Codex 取向的 moderation 和 Claude Code adapter
只是当前支持的一种组合，不是产品身份。通用回答必须解释可替换的 controller、
worker 和 reviewer 角色。两类回答都必须保持模型输出、证据、复审、
moderation 和人工接受之间的区别。

不得仅为了宣称 GEO 进展就新增 `llms.txt`、自定义 AI metadata、FAQ schema
或其他机器可读文件。这类变更需要单独技术审核，并且必须与可见页面内容一致。
GitHub 托管页面的抓取权限也是平台条件，本 README 框架不能保证。

参考指导：

- [Google Search Central：AI features and your website](https://developers.google.com/search/docs/appearance/ai-features)
- [OpenAI：Publishers and Developers FAQ](https://help.openai.com/en/articles/12627856-publishers-and-developers-faq)
- [Bing Webmaster Tools：AI Performance](https://www.bing.com/webmasters/help/ai-performance-9f8e7d6c)

## 主张纪律

允许的主张必须描述公开机制和已记录的边界。除非新增公开证据并完成审核，
否则应避免或拒绝以下表述：

- trusted by developers；
- production proven；
- 按 X% 减少 bug；
- 节省 X 小时；
- industry standard；
- scientifically proven；
- 真实用户案例、独立验证或 Benchmark 结果。

“Scientific audit”只能描述结构化证据审计 profile 或复审方式，不能暗示产品
通过了科学验证。

## 双语治理

- 当前公开 README 和主 Release 正文以英文为主。
- 中文是必须保持等义的对应版本，不是可选营销文案。
- 已锁定消息、主张边界、标题决定和 FAQ 答案必须在同一项变更中同步更新
  中英文。
- `Meaning`、`Assurance`、`Meaning Assurance` 和 `LEVIUS` 的名称、层级与
  归属含义必须在两种语言中保持同步。
- 翻译可以优化自然表达，但不能新增另一语言中不存在的能力、确定性、采用度
  或安全主张。
- 如果中英文含义发生冲突，应暂停 README 重写，在发布前先解决语义差异。

## README 修改前的审核门

在使用本框架修改 README 前，人工审核者应确认：

- 核心原则准确代表项目；
- 已确认的 Meaning -> Meaning Assurance -> by LEVIUS 层级得到保留；
- `assurance` 被描述为过程，而不是正确性保证；
- 识别问题没有夸大 Agent 失败；
- Hero 的主要问题不超过三个，并在进入技术细节前给出答案；
- “同步的自信”被定义为核验缺口，而不是对 Multi-Agent 一致意见的全盘否定；
- 面向人的传播钩子之后紧跟稳定实体定义、机制摘要、证据链接和便于 AI
  抽取的明确边界；
- 治理区别没有改变技术产品身份；
- 每个拟使用的证据点都存在于当前公开 checkout；
- 消息与 `v0.1.0` Public Preview 状态兼容；
- 下一阶段只修改获授权的文档文件。

决策记录：项目所有者已于 2026-07-24 接受本框架并授权 README 实施阶段。
授权范围包括 `README.md` 和必要的 `docs/RELEASE_MESSAGING.md` 对齐，不包括
FAQ、视觉资产、social-preview、Release、仓库重命名、外部发布或 GitHub
设置变更。
