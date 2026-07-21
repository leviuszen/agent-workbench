# Architecture

Agent Workbench separates public source code from private runtime artifacts.

```text
source checkout
  scripts/
  skills/
  tests/
        |
        | Install-AgentWorkbench.ps1
        v
runtime root
  tasks/
  discussions/
  worktrees/
  bugs/
```

## Task Path

```text
controller or human
  -> task packet
  -> isolated Git worktree
  -> external CLI worker
  -> canonical result and execution evidence
  -> controller reviews diff
  -> human accepts or rejects
```

No script merges the worker branch into the source branch.

## Discussion Path

```text
brief plus frozen references
  -> independent Round 1 reviewers
  -> normalized findings
  -> moderator synthesis
  -> targeted Round 2 challenge when needed
  -> evidence verification
  -> decision or user escalation
```

Only expected canonical reviewer files satisfy reviewer gates. Instructions, retries, recovery files, and arbitrary Markdown do not count as completed feedback.

## State And Evidence

Each task or discussion is a durable folder. `status.json` records the current state and expected participants. Markdown and JSONL artifacts preserve the human-readable evidence trail.

Invocation leases record process identity and completion state. A caller that times out can later adopt the existing result instead of launching a duplicate reviewer.

## Trust Model

External agents are untrusted evidence producers. They can propose code or findings, but they cannot accept their own output. The moderator checks files, evidence, and tests; the human retains final authority.
