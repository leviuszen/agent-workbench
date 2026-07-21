# Public Bug Log

This file records confirmed defects that are useful to users of released revisions.

Do not include credentials, private source code, personal information, local absolute paths, or unredacted agent output. Use synthetic reproduction data.

## Open

No confirmed public-release defects are recorded yet.

## Fixed Before 0.1.0

## 2026-07-21 - Test runner changed PowerShell edition

- Affected version: pre-release candidate
- Symptom: The PowerShell 7 CI job launched the test harness with PowerShell 7, but each test was then executed by Windows PowerShell 5.1.
- Root cause: `tests/run-tests.ps1` hard-coded `powershell.exe` for child test processes.
- Fix or mitigation: Resolve the child executable from the current PowerShell edition and use the same engine for every test.
- Verification: All 15 tests pass under Windows PowerShell 5.1. PowerShell 7 confirmation remains a publication gate for GitHub Actions.
- Compatibility impact: Test execution now matches the shell selected by the caller.

## 2026-07-21 - README worker example used an unsupported parameter

- Affected version: pre-release candidate
- Symptom: The isolated worker quick start passed `-Title` to `New-AgentTask.ps1`, which does not expose that parameter.
- Root cause: The documentation example drifted from the script contract.
- Fix or mitigation: Remove the unsupported parameter and add a public documentation contract test.
- Verification: The documentation test checks the obsolete parameter, required safety statements, workflow state gates, PowerShell code-block syntax, and the current test count.
- Compatibility impact: Documentation-only correction; no runtime API changed.

## 2026-07-21 - Public tests executed a sibling runtime instead of candidate source

- Affected version: pre-release candidate
- Symptom: Most tests resolved `tests\..\..\agent-workbench\scripts`, so a passing suite could validate an installed sibling runtime instead of the public candidate checkout.
- Root cause: Test paths retained the private source repository's former nested layout after the public repository was flattened.
- Fix or mitigation: Resolve the repository root from `tests\..`, target its local `scripts` folder, and add a hygiene guard against parent traversal and sibling runtime markers.
- Verification: All 15 tests pass against the candidate checkout; the synthetic public example test also creates a frozen discussion bundle and an isolated worktree from candidate scripts.
- Compatibility impact: Test-only correction; release evidence now refers to the code being published.

## 2026-07-21 - Chinese documentation assertions broke Windows PowerShell 5.1 parsing

- Affected version: pre-release candidate
- Symptom: Direct Chinese string literals in `test-public-documentation.ps1` were decoded through the Windows PowerShell 5.1 code page and produced parser errors.
- Root cause: The UTF-8 test file has no BOM, while Windows PowerShell 5.1 does not reliably infer UTF-8 for non-ASCII script source.
- Fix or mitigation: Keep PowerShell test logic ASCII-only and validate the Chinese release through non-ASCII character counts, stable ASCII markers, and bounded line checks.
- Verification: The documentation contract test and all 15 repository tests pass under Windows PowerShell 5.1.
- Compatibility impact: Test-only correction; the Chinese release remains UTF-8 Markdown.

## 2026-07-21 - CI launchers assumed Windows PowerShell and test source depended on local code pages

- Affected version: pre-release candidate
- Symptom: PowerShell 7 CI could not start helper scripts because it looked for `powershell.exe` under `$PSHOME`, then a Reasonix guard test looked for the wrong process name; Windows PowerShell 5.1 CI could not parse a test containing a direct Chinese path literal.
- Root cause: Five process launch points and one test fixture assumed Windows PowerShell host names, while one Unicode fixture depended on local source-code decoding.
- Fix or mitigation: Reuse the current PowerShell process executable and process name, construct the Unicode fixture from ASCII `[char]` values, and add a hygiene regression gate against hard-coded executable hosts.
- Verification: Parser checks, targeted regressions, and all 15 tests pass locally under Windows PowerShell 5.1. GitHub Actions run `29800641691` passed all 15 tests under both Windows PowerShell 5.1 and PowerShell 7.
- Compatibility impact: Helper scripts now preserve the caller's PowerShell edition; Unicode path coverage remains intact.

## Record Format

```markdown
## YYYY-MM-DD - Short defect title

- Affected version:
- Symptom:
- Root cause:
- Fix or mitigation:
- Verification:
- Compatibility impact:
```

After the GitHub repository is created, public bug reports should normally use GitHub Issues. Security-sensitive reports must follow `SECURITY.md` instead.
