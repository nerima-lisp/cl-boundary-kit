# Roadmap

The codebase is intentionally narrow. As of `1.0.0` the exported API is a
stable contract under the [Stability Policy](stability-policy.md), so the goal
of subsequent `1.x` work is usability and adoption quality rather than surface
growth.

## Status Semantics

- Items in this document are directional, not release commitments.
- Public changes that are already shipped or concretely queued for the next
  release belong in [Changelog](changelog.md), not only here.
- When a roadmap item ships, the corresponding release update should remove,
  narrow, or rewrite that roadmap entry so deferred intent does not masquerade
  as current fact.

## Near-Term

- Keep the exported `1.x` API stable and intentional; a new export has to
  earn its place against the non-goals below.
- Preserve parity between examples, README snippets, and regression tests.
- Keep the SBCL checkout flow and `run-tests.lisp` green, and keep the
  documented REPL test-runner contract green from a fresh process.
- Tighten public OSS metadata and policy documents only when they remain backed
  by executable verification in this repository.
- Add richer process and network adapters only when a concrete need appears.

## Longer-Term

- Add more host-agnostic adapters only when they stay small and explicit.
- Keep the boundary protocols stable before adding any new abstraction layer.
- Expand [Cookbook](cookbook.md) only when it explains a real usage pattern
  better than the existing examples.
- Add implementation compatibility claims only after they are exercised by real
  repository-level verification, not by assumption.

## Non-Goals

- Do not turn the library into an application framework.
- Do not add a generic dependency injection container.
- Do not add a full mocking framework.

See [Design Non-Goals](design-notes.md) for the corresponding implementation-level constraints.
