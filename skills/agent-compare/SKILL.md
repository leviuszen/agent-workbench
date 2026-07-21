---
name: agent-compare
description: Compare multiple external-agent outputs and let Codex produce the final decision.
---

# Agent Compare

Use this skill when two or more agent outputs disagree or when Codex needs to decide which result to trust.

## Rules

- Compare against the user's original request and local project constraints.
- Prefer tests, diffs, and file evidence over confident prose.
- Identify partial reuse opportunities instead of picking only one winner.
- Write the final decision to `codex-final.md` when working inside a task folder.

## Decision Format

Use this structure:

- Decision
- Why
- Accepted parts
- Rejected parts
- Files or patches to apply
- Tests to run
- Remaining risks
