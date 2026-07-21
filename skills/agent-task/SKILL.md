---
name: agent-task
description: Create a file-based task packet for formal external workers such as Claude Code, Reasonix, or a manual external agent while keeping Codex as final reviewer.
---

# Agent Task

Use this skill when the user wants Codex to delegate a bounded implementation, research, or exploration task to an external agent.

## Rules

- Codex remains the primary conversation and final reviewer.
- Create a task packet before launching any external agent.
- Keep the task narrow enough for one result file and one optional patch.
- Do not paste or log secrets, API keys, launcher contents, or provider environment variables.
- External agents should write outputs into the task folder.
- Do not claim the delegated task is complete until Codex has collected and reviewed result files.

## Workflow

1. Identify the workspace root and allowed paths.
2. Choose `claude-code`, `reasonix`, or `manual`.
3. Run `New-AgentTask.ps1` with the task, context, mode, target agent, and workspace root.
4. For implementation work where the external agent may edit repository files, create an isolated worktree before launch. See `Isolation For Implementation Tasks`.
5. Launch the selected agent:
- Formal non-interactive worker: `Invoke-AgentTask.ps1` after isolated worktree creation. It dispatches to Claude Code or Reasonix from `target_agent`.
- Claude Code direct compatibility runner: `Invoke-ClaudeCodeTask.ps1`
- Reasonix direct compatibility runner: `Invoke-ReasonixTask.ps1`
- Reasonix worker execution expects the `reasonix` CLI to be on PATH, or `REASONIX_COMMAND` / `-ReasonixCommand` to point to the real CLI shim.
- Close Reasonix Desktop before a CLI worker run. The runner preflights the Desktop process and translates CLI session-lock failures into a clear retry instruction.
- On Windows, the Reasonix runner denies `Bash(*)`, confines file writers to the isolated worktree with `workspace_root`, restores any original `reasonix.toml`, and leaves shell verification to Codex after collection.
- Treat `reasonix-stdout.log` and `reasonix-stderr.log` as redacted execution evidence. Canonical `agent-result.md` is cleaned and must start with `# Agent Result`.
   - Claude Code manual session: `Start-ClaudeTask.ps1`
   - Manual: give the task folder path to the user.
6. Wait for `agent-result.md`, `result.md`, or `patch.diff`.
7. Run `Collect-AgentResult.ps1`; when an isolated worktree exists, the collector prints a git status review section.
8. Review the output before applying any patch or recommendation.

## Isolation For Implementation Tasks

Use this before launching an external agent for implementation work that may edit repository files.

1. Create the task packet first with `New-AgentTask.ps1`.
2. Run `New-AgentWorktree.ps1` with the task folder, workbench root, workspace root, and slug.
3. For Claude Code or Reasonix, prefer `Invoke-AgentTask.ps1 -TaskFolder <folder> -Collect` when non-interactive execution is appropriate.
4. For manual agents, paste or provide `task.md` and `context.md`.
5. Tell the external agent to work only inside `isolated_workspace.path`.
6. After the agent finishes, Codex reviews `agent-result.md`, `result.md`, any other result files, and the `Isolated Worktree Diff` section before accepting changes.

## Output Contract

Tell the user:

- task folder path
- target agent
- expected output files
- whether a manual paste step is needed
- whether non-interactive worker execution was used
- what Codex will review next
