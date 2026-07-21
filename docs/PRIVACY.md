# Privacy

Agent Workbench is local-first. It does not add a hosted control plane or telemetry service.

That does not mean agent execution is offline. Claude Code, Reasonix, or another configured CLI may communicate with its own provider according to that CLI's settings and terms.

## Sensitive Runtime Content

Treat these folders as private:

- `tasks/`
- `discussions/`
- `worktrees/`
- `bugs/`

They may contain prompts, source snapshots, filenames, local paths, model output, diffs, and diagnostics.

## Reference Snapshots

Discussion references are copied intentionally so reviewers can inspect a frozen evidence set. Pass only files the reviewer is authorized to read. The manifest redacts original absolute paths, but copied file contents remain available to the selected external CLI.

## Logs And Redaction

The runners redact common secret shapes, provider variables, and local paths from selected logs. Redaction is not a substitute for reviewing artifacts before sharing them.

## Repository Hygiene

Keep the runtime root outside the source checkout. The included `.gitignore` is a backstop, not the primary boundary. Never commit runtime data, credentials, private reference files, or real agent transcripts as examples.
