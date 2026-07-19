# Security Policy

`cl-boundary-kit` is a boundary abstraction library, so security issues usually
show up as incorrect handling of external effects, unsafe assumptions about
filesystem or environment state, or tests that accidentally depend on real
system resources.

## Supported Versions

| Version | Supported |
| --- | --- |
| `0.1.x` | Yes |
| `< 0.1.0` | No |

## Supported Scope

- Filesystem boundaries
- Environment boundaries
- Time and random boundaries
- Process and network boundaries
- Logging and recording helpers

## Reporting Issues

Prefer a private report when the repository platform offers one. If a private
reporting channel is not available, open a minimal issue that asks the
maintainer for a private follow-up channel and do not include exploit details,
secrets, or weaponized proof-of-concept material in that public issue.

For any security-relevant bug, report the exact subsystem, the observable
behavior, and a minimal reproduction.

Include:

- the exported API you used
- the host implementation or platform if relevant
- whether the issue affects tests, examples, or production use

## Response Targets

- Acknowledge the report within 5 business days.
- Confirm whether the issue is in scope after triage.
- Coordinate a fix and release notes before public disclosure when a real
  vulnerability is confirmed.

## Disclosure Expectations

- Do not publish exploit details before a fix or mitigation is available.
- Keep reproductions minimal and deterministic.
- Prefer reports that explain the user-visible contract that was violated, not
  only the implementation detail that failed.

## Expectations

- Do not commit secrets into examples or tests.
- Keep boundary recorders from leaking real system state.
- Prefer explicit failures over silent fallback behavior when unsupported
  operations are encountered.
