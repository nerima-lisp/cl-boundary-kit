# Security Policy

`cl-boundary-kit` is a boundary abstraction library, so security issues usually
show up as incorrect handling of external effects, unsafe assumptions about
filesystem or environment state, or tests that accidentally depend on real
system resources.

## Supported Versions

| Version | Supported |
| --- | --- |
| `0.3.x` | Yes |
| `< 0.3.0` | No |

## Supported Scope

- Filesystem boundaries
- Environment boundaries
- Time and random boundaries
- Process and network boundaries
- Logging and recording helpers

## Known Scope Caveats

Recording boundaries (`make-recording-*`) and their `:test` counterparts keep
every call in an in-memory, unbounded list for the life of the boundary
object, with no built-in redaction, size cap, or reset short of discarding the
object. That is intentional for the library's actual scope -- a single test's
or example's boundary object -- but it is not a safe pattern for a long-lived
process: reusing one recording boundary across many operations in a
production-like service grows its call history without bound and retains
whatever arguments/results (including env values or subprocess
arguments/environment) flowed through it for as long as the object is
reachable. Give a recording boundary the lifetime of a single test or
operation rather than sharing one across a long-lived process.

## Reporting Issues

Send a private report through one of the channels below. Do not open a public
issue for a security report.

- **GitHub private vulnerability reporting (preferred).** Open a report from the
  repository's **Security → Report a vulnerability** tab, or directly at
  <https://github.com/takeokunn/cl-boundary-kit/security/advisories/new>.
- **Email.** If you cannot use GitHub's private reporting, email the maintainer
  at <bararararatty@gmail.com>.

Do not include exploit details, secrets, or weaponized proof-of-concept material
in any public issue. If neither private channel works for you, open a minimal
public issue that only asks the maintainer to establish a private follow-up
channel.

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
- Prefer absolute paths for native process execution. PATH lookup is disabled by
  default and should only be enabled around calls that intentionally trust the
  ambient process environment.
