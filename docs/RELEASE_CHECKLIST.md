# Release Checklist

## Source Boundary

- Build the release from an explicit allowlist.
- Do not copy private Git history, runtime folders, handoff documents, or real agent transcripts.
- Keep private denylist rules outside this repository.

## Verification

- Run `tests/run-tests.ps1` with Windows PowerShell 5.1.
- Run `tests/run-tests.ps1` with PowerShell 7.
- Confirm both CI jobs execute candidate scripts from the current checkout rather than another installed runtime.
- Run the public hygiene test.
- Run a secret scanner against files and the complete clean Git history.
- Search for personal information, local paths, private project names, and real email addresses.
- Install into a temporary runtime root and run a synthetic smoke test.
- Clone the candidate into an empty folder and repeat the tests and scans there.

## Release Content

- Review `.github/RELEASE_v0.1.0.md` and `.github/RELEASE_v0.1.0.zh-CN.md` against the final tagged code.
- Review `docs/RELEASE_MESSAGING.md` for positioning drift and unsupported adapter claims.
- Confirm `LEVIUS` and `agentworkbench@proton.me` are the intended public author ID and contact address.
- Confirm the `2026-07-21` date in `CHANGELOG.md` matches the actual publication date.
- Confirm the test count stated in the release body matches `tests/test-*.ps1`.
- Run the synthetic examples from the release checkout; do not substitute private runtime artifacts.
- Keep the release title and body labeled `Public Preview` until the public API and host support stabilize.
- Describe controller, worker, and reviewer as replaceable protocol roles; describe Claude Code and Reasonix only as the current built-in adapters.
- Do not imply built-in OpenHands or other runtime support until a tested adapter is included.

## Git Metadata

- Start from a new repository with no private refs, tags, reflogs, or objects.
- Use a public author name and a GitHub no-reply email address.
- Inspect `git log --all --format=fuller` before publication.

## Publication Gate

- Verify the exact repository owner, name, visibility, description, topics, and license.
- Follow `docs/PUBLICATION_READINESS.md` and record the final owner, repository URL, verified commit, and release URL.
- Enable push protection and private vulnerability reporting when available.
- Do not create a remote, push, or change repository visibility without explicit owner approval.
