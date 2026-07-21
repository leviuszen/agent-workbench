# Protocol

## Task Packets

A task packet defines the task, context, target agent, workspace, expected output, and current status. Implementation workers require an isolated Git worktree before non-interactive execution.

Canonical worker outputs are `agent-result.md` and the compatibility copy `result.md`. Execution logs and metrics are evidence, not substitutes for the canonical result.

## Discussion Packets

A discussion packet contains:

- `brief.md` for the question and output contract;
- `status.json` for protocol state;
- `references/manifest.md` and frozen files when references are supplied;
- `roundN/<agent>.md` canonical reviewer output;
- `codex-synthesis.md` for moderator synthesis;
- `decision.md` or `user-decision-needed.md` for closure.

## Scientific Audit

Scientific audit adds structured findings and a disagreement matrix.

Round 1 is blind. Reviewers must provide evidence, confidence, counter-evidence, blocking status, and a bounded recommendation.

Round 2 is not a repeated review. It addresses disputed, blocking, or weak-evidence findings and marks positions as maintained, revised, or withdrawn.

The moderator records one of four outcomes for each normalized finding:

- `confirmed`
- `rejected`
- `duplicate`
- `not-testable`

Agreement between reviewers does not establish correctness. Evidence and verification determine the outcome.
