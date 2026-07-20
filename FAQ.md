# FAQ

## When Should I Use This Library?

Use `cl-boundary-kit` when you want external effects to be explicit in
application code and directly inspectable in tests.

It is a good fit when you want:

- boundary protocols instead of ad hoc host calls
- deterministic tests without a mocking framework
- explicit call recording for assertions
- a small contract surface you can reason about

It is not a good fit when you want a framework, dependency injection container,
or application-specific adapter stack. Those remain out of scope.

## How Do I Choose Between A Recording Boundary And A Test Boundary?

Use a recording boundary when you already have a delegate implementation and
want to assert on the exact arguments and returned result.

Use a test boundary when you want a fully in-memory fake with precomputed state
or queued results and no dependency on host resources.

As a rule of thumb:

- use `make-recording-filesystem`, `make-recording-environment`,
  `make-recording-process-boundary`, `make-recording-network-boundary`, and
  `make-recording-logger` when interaction history is the main thing you want
  to assert on
- use `make-test-filesystem`, `make-test-environment`,
  `make-test-process-boundary`, `make-test-network-boundary`,
  `make-test-random-source`, and `make-test-logger` when you need a deterministic
  fake that owns its own state

See [`COOKBOOK.md`](COOKBOOK.md) for end-to-end examples of both styles.

## How Do I Preserve Explicit `nil` Values?

Several boundaries distinguish between a missing value and an explicit `nil`.
This matters most for environment lookup and boundary context composition.

Use:

- `environment-present-p` when you need to know whether a variable exists
- `boundary-context-present-p` when you need to know whether a key was bound
- custom `:get-fn` collaborators that return a second presence value when `nil`
  is a valid result

The library does not collapse explicit `nil` into "missing" when the public
contract says those states differ.

## Why Do Unsupported Operations Signal Instead Of Falling Back?

The library prefers visible failure over host-dependent magic. If a boundary
operation is intentionally unavailable, it signals
`unsupported-boundary-operation` so tests and production wiring both see the
same contract.

That is why `make-environment` without a `:set-fn` does not pretend mutation is
supported, and why a network boundary without a transport function does not
invent one.

See [`COMPATIBILITY.md`](COMPATIBILITY.md) for the verification scope around
those guarantees.

## What If Behavior Differs Across Lisp Implementations Or Platforms?

Start by checking [`COMPATIBILITY.md`](COMPATIBILITY.md). Only the
implementation and verification scope documented there should be treated as a
compatibility claim for `0.4.x`.

If a behavior covered by that verified contract fails, report it through
[`SUPPORT.md`](SUPPORT.md) with:

- the exact exported API you called
- a minimal reproduction
- the Common Lisp implementation and platform
- the observed behavior and the documented expectation

If the behavior difference exposes unsafe effect handling, leaks secrets or
host state, or otherwise turns into a vulnerability, use the private reporting
path in [`SECURITY.md`](SECURITY.md) instead of the public support route.

## How Will Deprecations Or Breaking Changes Be Communicated?

The project treats deprecations and intentionally breaking changes as explicit
public contract events, not implicit maintainer intent.

Expect them to be called out in [`CHANGELOG.md`](CHANGELOG.md). When a
supported replacement exists, the changelog entry should include migration
guidance instead of only naming the removal.

For `0.4.x`, any intentionally breaking compatibility change should also update
[`COMPATIBILITY.md`](COMPATIBILITY.md) so the documented verification scope and
change policy stay aligned with the release notes.

## What Counts As The Stable Public Surface?

For `0.4.x`, stability claims are intentionally narrow. The effective public
contract is defined by:

- exported symbols documented in `README.md`
- checked-in examples and cookbook snippets that are exercised by the test suite
- compatibility notes in [`COMPATIBILITY.md`](COMPATIBILITY.md)
- contributor and maintainer policy in [`CONTRIBUTING.md`](CONTRIBUTING.md) and
  [`GOVERNANCE.md`](GOVERNANCE.md)

If a behavior is not covered by those artifacts and executable verification, do
not treat it as a compatibility promise.
