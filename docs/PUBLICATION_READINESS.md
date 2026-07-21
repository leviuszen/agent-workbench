# Publication Readiness

This document separates local release preparation from actions that expose the repository externally.

## Public Identity

- Project: **Agent Workbench**
- Author ID: **LEVIUS**
- Public contact: [agentworkbench@proton.me](mailto:agentworkbench@proton.me)
- License: Apache License 2.0
- Release: `v0.1.0` Public Preview

Suggested GitHub description:

> A lightweight, local-first protocol for coordinating replaceable coding agents with bounded workers, adversarial review, frozen evidence, and human-controlled decisions.

Suggested topics:

```text
ai-agents
agent-orchestration
coding-agents
multi-agent
local-first
code-review
git-worktree
powershell
claude-code
human-in-the-loop
```

## Completed Locally

- Clean public Git history with a public no-reply commit email.
- Apache License 2.0, contribution guide, security policy, bug log, and changelog.
- English and Simplified Chinese release drafts.
- Role-based positioning that does not bind the mechanism to one fixed agent trio.
- Synthetic examples without private task or discussion transcripts.
- Windows CI definitions for Windows PowerShell 5.1 and PowerShell 7.
- Public documentation, example, source-boundary, and privacy tests.
- Public author ID and contact channel.

## Required Before Public Release

1. Confirm the exact GitHub owner, repository name, and initial visibility.
2. Confirm the `2026-07-21` release date in `CHANGELOG.md` still matches the publication date.
3. Run a maintained secret scanner such as Gitleaks against the working tree and complete Git history.
4. Create a GitHub repository and push only after explicit publication approval.
5. Prefer a private staging repository first; confirm both Windows PowerShell 5.1 and PowerShell 7 CI jobs pass against the pushed commit.
6. Confirm the GitHub-rendered README, English release body, Chinese release body, code blocks, and relative links.
7. Enable branch protection, push protection, and private vulnerability reporting when available.
8. Confirm issue labels and the bug-report form work as intended.
9. Change visibility to public only after the private staging checks pass and the owner approves the exact destination.
10. Create the signed or annotated `v0.1.0` tag from the verified commit, then publish the GitHub Release using the selected language body.

## Language Options

GitHub provides one main body per Release. Choose one of these launch patterns:

- English body as the primary Release, with a link to the Chinese version in the repository.
- Chinese body as the primary Release, with a link to the English version in the repository.
- A short bilingual summary in the Release followed by links to both full drafts.

For a globally discoverable first release, the recommended default is an English primary body with a short Chinese summary and a direct link to `.github/RELEASE_v0.1.0.zh-CN.md` after the final repository URL is known.

## Optional Launch Polish

- Add a simple repository social-preview image after the positioning is stable.
- Record a short synthetic terminal demonstration of one review flow and one isolated worker flow.
- Add a feature-request issue template if community demand appears.
- Enable GitHub Discussions only if there is enough traffic to justify a separate discussion surface.

These items are optional. They should not delay publication of a verified public preview.

## Publication Boundary

Creating a remote, pushing commits, changing visibility, creating a tag on GitHub, or publishing a Release are external actions. None of them are authorized by preparing this document. Each requires explicit approval of the destination and action.
