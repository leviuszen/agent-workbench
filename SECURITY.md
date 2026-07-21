# Security Policy

## Supported Versions

Agent Workbench is currently a public preview. Security fixes are applied to the latest revision only.

## Reporting A Vulnerability

Do not open a public issue containing credentials, private source code, personal information, local paths, or unredacted runtime artifacts.

Use GitHub private vulnerability reporting when it is available for the repository. Include a minimal reproduction with synthetic data.

If private vulnerability reporting is unavailable, contact [agentworkbench@proton.me](mailto:agentworkbench@proton.me) with the subject `[Agent Workbench Security]`. Email is not an encrypted channel; do not include live credentials, private source code, or unnecessary sensitive artifacts.

## Security Boundaries

- Agent Workbench is a local orchestration and evidence harness, not an OS sandbox.
- Git worktrees isolate repository changes but do not prevent a CLI process from accessing resources allowed by the operating system.
- Each external CLI retains its own authentication, permissions, network access, and model-provider behavior.
- Redaction reduces accidental disclosure but cannot guarantee removal of every sensitive value.
- Runtime folders may contain source snapshots, prompts, logs, and model output and must be treated as private by default.

## Safe Defaults

- Keep `AGENT_WORKBENCH_HOME` outside the source checkout.
- Use read-only discussion mode for review tasks.
- Use isolated worktrees for implementation tasks.
- Inspect diffs and canonical result files before accepting changes.
- Never publish runtime folders without a separate disclosure review.
