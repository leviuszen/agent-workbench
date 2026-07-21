---
name: agent-review
description: Create a read-focused external-agent review packet for code, diffs, plans, or generated artifacts.
---

# Agent Review

Use this skill when Codex wants Claude Code, Reasonix, or a manual external agent to review work without taking over the main workspace.

## Rules

- Prefer read-only review.
- Findings come before suggestions.
- Ask for file paths, line references, severity, and concrete risk.
- Optional fixes must be written as small suggestions or `patch.diff`.
- Codex decides whether findings are valid.
- For mandatory dual code or strategy review, use `New-AgentDiscussion.ps1 -AuditProfile scientific -Protocol adversarial-discussion -Agents claude-code,reasonix`. While Reasonix is non-blocking, use `-Agents claude-code -OptionalAgents reasonix` and report that the audit is not dual when Reasonix is absent.
- Round 1 is blind; Round 2 addresses only disputed, blocking, or weak-evidence findings.
- Do not treat Reasonix Desktop launch, instruction files, or single-reviewer completion as review evidence.
- Do not decide by model vote. Use `findings.json`, `disagreement-matrix.md`, and verified calibration outcomes.

## Review Packet Contents

Include:

- user request
- files or diff under review
- expected behavior
- tests already run
- tests still needed
- severity scale
- forbidden actions

## Required Review Output

The external agent should write `review.md` with:

- Findings
- Evidence
- Suggested fixes
- Residual risks
- Tests recommended

For scientific review, use the finding block required by `brief.md`, including evidence, confidence, counter-evidence, blocking status, and a bounded recommended action.
