# Governance

`cl-boundary-kit` is maintained as a small, explicit boundary library. The
project optimizes for a narrow stable contract, deterministic examples, and
evidence-backed changes over broad abstraction growth.

## Maintainer Role

The maintainer is responsible for:

- deciding whether a proposed change fits the library scope
- keeping the exported API explicit and intentionally small
- requiring tests and documentation updates for contract changes
- routing security and conduct reports through the documented private paths

## Decision Process

Technical decisions are made from concrete evidence:

- reproducible behavior
- executable tests
- checked-in examples
- explicit compatibility notes

When tradeoffs are unclear, the maintainer may decline or defer changes until a
concrete boundary use case, regression test, or documentation contract justifies
them.

## Contract Surface

The project-level support and stability contract is defined by the checked-in
artifacts below:

- `README.md` for public API overview and supported usage flows
- `COMPATIBILITY.md` for verification scope, non-claims, and change policy
- `CONTRIBUTING.md` for contributor workflow and test expectations
- `SUPPORT.md` for request routing and maintenance boundary
- `SECURITY.md` for private reporting expectations
- `CODE_OF_CONDUCT.md` for participation rules
- `examples/*.lisp` and the executable test suite for regression-checked usage contracts

Changes that alter the supported contract should update the relevant documents
and the executable tests in the same change.

## Release and Change Expectations

The library is intentionally conservative:

- small additions are preferred over broad framework-like abstractions
- unsupported operations should fail explicitly instead of hiding host differences
- compatibility claims should only be made after repository-level verification
- intentionally breaking changes should be called out in `CHANGELOG.md`

## Escalation Paths

- Usage and design questions follow `SUPPORT.md`.
- Security-sensitive reports follow `SECURITY.md`.
- Conduct issues follow `CODE_OF_CONDUCT.md`.
