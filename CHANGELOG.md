# Changelog

All notable public changes will be documented in this file.

The format is based on Keep a Changelog, and this project intends to use Semantic Versioning after the public API stabilizes.

## [Unreleased]

## [0.1.0] - 2026-07-21

### Added

- Initial public preview of file-backed task and discussion protocols.
- Isolated Git worktree dispatch for Claude Code and Reasonix workers.
- Frozen and hashed reference snapshots for read-only review.
- Scientific dual-review artifacts, explicit reviewer gates, and moderator outcomes.
- Clean public release layout with no private Git history or runtime records.
- Environment-based installation through `AGENT_WORKBENCH_HOME`.
- Windows CI and public-release hygiene checks.
- Public architecture, privacy, security, and contribution documentation.
- Synthetic end-to-end examples and a ready-to-paste GitHub release draft.
- English and Simplified Chinese release drafts with role-based marketing guidance and explicit adapter boundaries.
- Public author and contact records plus a staged publication-readiness guide.

### Changed

- Removed legacy private launcher discovery.
- Made the manual Reasonix Desktop path configurable through `REASONIX_DESKTOP_EXE`.
- Made the test runner preserve its calling PowerShell edition so the PowerShell 7 CI job exercises PowerShell 7.
