---
name: agent-discussion
description: Use when Codex needs read-only external feedback for planning, architecture review, code discussion, strategy review, or decision support.
---

# Agent Discussion

Use this skill when Codex needs structured external feedback for planning, architecture review, code discussion, or decision support before making a final call.

## Current Path

For read-only external feedback, the current path is:

```text
New-AgentDiscussion.ps1
  -> Invoke-ClaudeFeedback.ps1 -Round <1-or-2> -Collect
  -> Invoke-ReasonixFeedback.ps1 -Round <1-or-2> -Collect when Reasonix is a reviewer
  -> Collect-AgentDiscussion.ps1
  -> Codex writes codex-synthesis.md, decision.md, or user-decision-needed.md
```

If Claude returns a malformed fragment, a file list, or feedback rejected by the format gate, stay in the same discussion folder and use:

```text
Invoke-ClaudeFeedback.ps1 -Round <1-or-2> -RawReadOnlyRecovery -Collect
```

Do not switch to an unrelated chat or a hand-written direct `claude.exe` command for this workflow.

## Rules

- Codex remains the moderator, evidence evaluator, and final decision maker.
- Discussion mode is read-oriented and file-based.
- Discussion mode does not edit repository files.
- Discussion creation does not launch external agents automatically; use `Invoke-ClaudeFeedback.ps1` only when the user wants Claude Code feedback now.
- Discussion mode does not create worktrees, merge branches, apply patches, or accept code changes.
- External agents write Markdown feedback files only.
- Reasonix CLI is the automatic review path. `Open-ReasonixDiscussion.ps1` remains manual compatibility only and never counts as completion by itself.
- Codex writes synthesis, user escalation, and final decision files.
- The default limit is two rounds.
- Pick `-Mode` for the task type so the generated `brief.md` carries the right output structure. Use `article-review` for article analysis, `strategy-review` for strategy/planning, `code-review` for code review, `decision` for option selection, and `general` otherwise.
- Use `-Protocol adversarial-discussion` when Codex needs debate, synthesis, and a second-round response. Use `-Protocol feedback` for one-way structured feedback.
- Use `-ExpectedSections` when the user needs named custom sections. This is preferred over prose format instructions.
- Use `-ExpectedOutputFormat` only for a complete Markdown template. Prose instructions like `Markdown with sections: ...` are normalized into a strict template and recorded as `custom_normalized`.
- Use `-ReferencePaths` when the external agent needs to inspect article drafts, source files, notes, or bounded folders. Discussion mode copies read-only snapshots into `references/files/` and writes `references/manifest.md`; external agents should read those snapshots rather than original absolute paths.
- Treat `ReferencePaths` as frozen evidence copied at discussion creation time. Round 2 and `-RawReadOnlyRecovery` stay on the same frozen snapshots. If the original source files changed and the user wants a re-review of current files, create a fresh discussion with new `-ReferencePaths`.
- Reference packaging fails on file-count or size truncation, and both CLI reviewers verify manifest inventory, byte counts, hashes, and evidence bundle identity before review.
- The evidence bundle ID is stored in `status.json` and derived as SHA-256 over ordered snapshot hashes joined by newlines.
- If a major disagreement remains unresolved after two rounds, Codex writes `user-decision-needed.md`, pauses, and asks the user to decide or redirect.
- `Agents` are required reviewers. `OptionalAgents` are attempted and reported but do not block collection. Do not describe a one-reviewer result as a dual audit.
- Use `-AuditProfile scientific` for consequential `code-review` and `strategy-review` work. Round 1 is blind and independent; Round 2 is limited to disputed, blocking, or weak-evidence findings.
- Scientific dual review is complete only when every expected canonical `roundN/<agent>.md` file exists. Instruction, retry, recovery, and arbitrary Markdown files never count.
- Reviewer-local finding IDs must be unique within each canonical file. Duplicate IDs are rejected rather than silently producing ambiguous calibration records.
- Consensus is not proof. Codex adjudicates evidence and records verified outcomes; it does not majority-vote.

## Create A Discussion

Run `New-AgentDiscussion.ps1` with a focused topic, question, context, and optional agent names.

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
& (Join-Path $WorkbenchRoot "scripts\New-AgentDiscussion.ps1") `
-WorkbenchRoot $WorkbenchRoot `
  -Slug "short-discussion-slug" `
  -Topic "Architecture review" `
  -Question "Which implementation direction best fits the current constraints?" `
  -Context "Summarize the relevant files, requirements, risks, and forbidden actions." `
  -Mode strategy-review `
  -Protocol adversarial-discussion `
  -AuditProfile scientific `
  -ReferencePaths "C:\Path\To\Your\Repository\docs\design.md" `
  -ExpectedSections "Summary","HIGH findings","MEDIUM findings","LOW findings","Scope verdict","Required remediation" `
  -Agents claude-code `
  -OptionalAgents reasonix
```

The script creates a discussion folder under `discussions` with `brief.md`, `status.json`, `run.log`, `round1`, `round2`, `codex-synthesis.md`, `user-decision-needed.md`, and `decision.md`. When references are provided, it also creates `references/manifest.md` and copied snapshots under `references/files/`.

Do not place original repository paths only inside `-Context`; local absolute paths are redacted for safety. Use `-ReferencePaths` for material Claude should read.

For multiple reference paths, prefer hashtable splatting so PowerShell preserves the array:

```powershell
$params = @{
WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
  Slug = "short-discussion-slug"
  Topic = "Architecture review"
  Question = "Which implementation direction best fits the current constraints?"
  Context = "Summarize the relevant files, requirements, risks, and forbidden actions."
  Mode = "strategy-review"
  Protocol = "adversarial-discussion"
  ReferencePaths = @(
    "C:\Path\To\Your\Repository\docs\design.md",
    "C:\Path\To\Your\Repository\src\module.py"
  )
  AuditProfile = "scientific"
  Agents = @("claude-code")
  OptionalAgents = @("reasonix")
  ReviewerLenses = @{
    "claude-code" = "route and doctrine fidelity"
    "reasonix" = "evidence and falsification"
  }
}
$DiscussionScript = Join-Path $params.WorkbenchRoot "scripts\New-AgentDiscussion.ps1"
$DiscussionFolder = & $DiscussionScript @params
```

## External Feedback Format

External agents receive `brief.md` and write feedback into:

- `round1/<agent>.md` for first independent feedback
- `round2/<agent>.md` for response to Codex synthesis and disagreements

Feedback should use the format embedded in `brief.md`. The default format is:

```markdown
# Agent Discussion Feedback

## Recommendation

## Reasoning

## Risks

## Disagreements Or Unknowns

## Questions For Codex Or User
```

Scientific code/strategy audit briefs instead require repeated `### Finding <reviewer-local-id>` blocks. Each finding records area, falsifiable claim, severity, evidence, confidence, counter-evidence, recommended action, and blocking status. Strategy findings additionally record claim type, falsifier, and minimum validation.

## Codex Moderator Workflow

1. Create the discussion brief.
2. Ask external agents to write round 1 feedback files.
   - Optional Claude Code runner: `Invoke-ClaudeFeedback.ps1 -DiscussionFolder <folder> -Round 1 -Collect`
   - Optional Reasonix CLI reviewer: `Invoke-ReasonixFeedback.ps1 -DiscussionFolder <folder> -Round 1 -Collect`
   - When `references/manifest.md` exists, the runner instructs Claude Code to read it and the listed snapshots.
3. Run `Collect-AgentDiscussion.ps1`.
4. Write `codex-synthesis.md` with consensus, disagreements, suspected misreadings, and round 2 questions.
5. Ask external agents to write round 2 feedback files.
   - Optional Claude Code runner: `Invoke-ClaudeFeedback.ps1 -DiscussionFolder <folder> -Round 2 -Collect`
   - Optional Reasonix CLI reviewer: `Invoke-ReasonixFeedback.ps1 -DiscussionFolder <folder> -Round 2 -Collect`
   - Round 2 requires `codex-synthesis.md`; Claude Code is instructed to respond to it instead of repeating one-way feedback.
6. Run `Collect-AgentDiscussion.ps1` again.
7. If the collector reports `needs_codex_decision`, Codex must write the final moderator decision into `decision.md`, or write `user-decision-needed.md` if a material disagreement still requires user judgment.
8. If a major disagreement remains unresolved, write `user-decision-needed.md` and pause for the user.
9. After user direction, write `decision.md` and collect again until state is `decision_ready`.

Codex should evaluate evidence, constraints, and project fit. Do not decide by majority vote.

## Collection Contract

`Collect-AgentDiscussion.ps1` reads canonical expected feedback files, prints sanitized excerpts, detects disagreement/risk/blocker signals, and updates `status.json`. Scientific collection also writes `findings.json` and `disagreement-matrix.md`; all matrix rows begin as `pending_codex`.

The collector updates:

- `state`
- `current_round`
- `round1_count`
- `round2_count`
- `round1_completed_agents` / `round1_missing_agents`
- `round2_completed_agents` / `round2_missing_agents`
- `round1_missing_optional_agents` / `round2_missing_optional_agents`
- `signals`
- `updated_at`

It does not modify feedback files, write `decision.md`, launch agents, edit source files, create worktrees, merge, or apply patches. `Invoke-ClaudeFeedback.ps1` and `Invoke-ReasonixFeedback.ps1` are explicit CLI invocation paths and write only their requested canonical round file after validation.

Claude Code is auto-discovered from an explicit path, `CLAUDE_CODE_EXE`, npm, or PATH. Both CLI discussion runners use PID-backed invocation leases: after caller timeout, rerun the same command to adopt the existing result instead of creating a duplicate reviewer. Use `-RetryFailedInvocation` only after inspecting a completed failed call; the old evidence is archived before retry. Reasonix Round 2 requires `codex-synthesis.md`; malformed Reasonix output is preserved under `invalid-feedback/` and retried through the same CLI route.

`Invoke-ClaudeFeedback.ps1` validates that Claude's response starts with the expected heading and includes the required `##` sections from `brief.md`. Invalid output is preserved under `invalid-feedback/`, `retry-brief.md` is generated, and the runner fails so Codex can retry or inspect the bad output.

If invalid feedback is an implausibly short fragment, a file list, or useful content rejected by the format gate, do not hand-write a direct `claude.exe` bypass. Re-run the same discussion through:

```powershell
$WorkbenchRoot = $env:AGENT_WORKBENCH_HOME
& (Join-Path $WorkbenchRoot "scripts\Invoke-ClaudeFeedback.ps1") `
-DiscussionFolder <folder> `
  -Round <1-or-2> `
  -RawReadOnlyRecovery `
  -Collect
```

Raw read-only recovery still uses only Read access, validates the same expected heading and sections, writes evidence under `recovery-feedback/`, writes the accepted canonical feedback under `roundN/<agent>.md`, and records recovery metadata in `status.json`. It is the governed replacement for manual raw CLI旁路.

For two-round `adversarial-discussion`, state meanings are:

- `awaiting_round1_reviewers`: at least one expected canonical Round 1 file is missing.
- `feedback_collected`: feedback exists, but final moderation may not yet be required.
- `awaiting_round2_reviewers`: Round 2 started but at least one expected canonical Round 2 file is missing.
- `awaiting_codex_synthesis`: all expected Round 2 files exist but `codex-synthesis.md` is still empty.
- `needs_codex_decision`: round 2 feedback exists and `decision.md` is still empty.
- `needs_user_decision`: Codex wrote `user-decision-needed.md` because the dispute should not be forced closed.
- `decision_ready`: `decision.md` is non-empty and can be treated as the final moderator output.
- `invalid_feedback_empty_or_fragment`: Claude returned a too-short fragment such as a code snippet; inspect `invalid-feedback/` and retry with `retry-brief.md`.
- `invalid_feedback_format`: Claude included expected sections but missed the required first heading.
- `invalid_feedback_incomplete`: Claude started correctly but missed required sections.
- `invalid_feedback_offtask`: Claude missed both heading and expected sections.

## Output Contract

Tell the user:

- discussion folder path
- expected round feedback files
- whether Claude feedback was generated manually or with `Invoke-ClaudeFeedback.ps1`
- whether Codex synthesis or user escalation is needed
- current `status.json` state
- final decision file path when a decision is written
- scientific `findings.json` and `disagreement-matrix.md` paths when present
- calibration paths after `Record-AgentAuditOutcome.ps1` records verified outcomes
