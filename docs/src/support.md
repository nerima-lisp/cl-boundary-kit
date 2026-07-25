# Support

## What To Use

Use the repository issue tracker for:

- reproducible bugs in the public API
- documentation drift between `README.md`, examples, and behavior
- missing or unclear compatibility notes
- narrowly scoped feature requests that fit the library goals

Use project discussion threads, if available, for:

- usage questions
- design tradeoff questions before implementation
- examples or patterns that may belong in documentation

Check [Cookbook](cookbook.md) first when your question is about composing
boundaries, asserting recorder behavior, or handling unsupported operations.
Check [FAQ](faq.md) first when your question is about choosing between a
recording boundary and a test boundary, preserving explicit `nil`, or
understanding what counts as a compatibility promise. Check
[Changelog](changelog.md) first when your question is whether a behavior
was intentionally deprecated, removed, or changed in a breaking way.

Use the private route described in [Security](security.md) for:

- vulnerabilities
- exploit details
- leaks of secrets or sensitive system state

Use the conduct reporting route in [Code of Conduct](code-of-conduct.md)
for harassment, intimidation, personal attacks, or other participation issues
that are not ordinary support requests.

## What To Include

When asking for support, include:

- the exact exported API you called
- a minimal reproduction
- the Lisp implementation and platform when relevant
- the observed behavior and the expected contract

If you are reporting a deprecation or removal problem, also include:

- the changelog entry you followed, if one exists
- the migration step or replacement API that appears incomplete or unclear

## What Not To Expect

This project intentionally stays small. Support does not imply:

- application-specific architecture design
- broad framework integration consulting
- guarantees for untested Lisp implementations
- hidden fallback behavior for unsupported operations
- undocumented migration promises beyond what [Changelog](changelog.md) and
  [Compatibility](compatibility.md) explicitly describe

## Maintenance Boundary

Questions and bug reports are evaluated against the explicit public contract in
`README.md`, [Compatibility](compatibility.md), the checked-in examples,
the executable test suite, and the maintainer decision model in
[Governance](governance.md). Requests that conflict with the documented
non-goals or would expand the abstraction surface without a clear boundary use
case may be declined. Intentionally breaking changes, deprecations, and
removals are expected to be announced through [Changelog](changelog.md); when a supported
replacement exists, that route should carry the migration guidance consumers
are asked to follow.
