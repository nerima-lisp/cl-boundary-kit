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
- explicit verification notes

When tradeoffs are unclear, the maintainer may decline or defer changes until a
concrete boundary use case, regression test, or documentation contract justifies
them.

## Contract Surface

The project-level support and stability contract is defined by the checked-in
artifacts below:

- `README.md` for the project overview and entry point into the full documentation
- the [Guide](composition.md) pages for the supported public API surface
- [Verification](compatibility.md) for checked verification workflows
- [Contributing](contributing.md) for contributor workflow and test expectations
- [Support](support.md) for request routing and maintenance boundary
- [Security](security.md) for private reporting expectations
- [Code of Conduct](code-of-conduct.md) for participation rules
- `examples/*.lisp` and the executable test suite for regression-checked usage contracts

Changes that alter the supported contract should update the relevant documents
and the executable tests in the same change.

## Release and Change Expectations

The library is intentionally conservative:

- small additions are preferred over broad framework-like abstractions
- unsupported operations should fail explicitly instead of hiding host differences
- published documentation should be backed by repository-level verification

## Escalation Paths

- Usage and design questions follow [Support](support.md).
- Security-sensitive reports follow [Security](security.md).
- Conduct issues follow [Code of Conduct](code-of-conduct.md).
