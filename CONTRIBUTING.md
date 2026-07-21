# Contributing

Thank you for considering a contribution to Agent Workbench.

## Development Setup

Requirements:

- Windows PowerShell 5.1 or PowerShell 7
- Git

Run the full test suite before submitting a change:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

Tests must not require live model credentials. Use temporary repositories and fake CLI shims for process, timeout, output, and worktree behavior.

## Change Rules

- Keep external worker changes inside isolated worktrees.
- Do not add automatic merge or automatic patch application.
- Preserve canonical evidence files and explicit state transitions.
- Treat model agreement as input, not proof.
- Add or update a focused regression test for behavioral fixes.
- Do not commit task packets, discussions, source snapshots, run logs, credentials, or local absolute paths.
- Keep provider-specific behavior inside its adapter or process runner.

## Pull Requests

Describe:

- the problem being solved;
- the bounded behavioral change;
- tests run;
- compatibility impact;
- any privacy or security implications.

Large architecture changes should begin with an issue describing the proposed state-machine or protocol change.
