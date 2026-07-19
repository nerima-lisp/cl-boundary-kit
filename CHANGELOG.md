# Changelog

This project follows a simple keep-a-changelog-style structure.

## Unreleased

This section tracks intentional public changes that may ship in the next
release. Long-term ideas, non-committed exploration, and deferred work belong
in [`ROADMAP.md`](ROADMAP.md) instead.

Deprecations, removals, and intentionally breaking behavior changes should be
called out explicitly here. When a supported replacement exists, include
migration guidance so consumers can move without inferring policy from code
diffs alone.

- Added `assert-recorded-call-count` for asserting the number of matching
  recorded boundary calls without introducing a separate matcher dependency.
- Added `assert-recorded-call-sequence` for asserting ordered recorded-call
  history, including prefix-only checks via `:exact-length nil`.
- Clarified the testing-helper contract in `README.md` and `COOKBOOK.md`,
  including explicit `:result nil` assertions and `boundary-call-plist`
  construction patterns.
- Expanded executable documentation coverage for `FAQ.md` so the stable public
  surface policy is regression-checked alongside the README and compatibility
  contract.
- Added a public API contract test that requires exported runtime functions and
  types to retain non-empty Common Lisp `documentation` strings.

## 0.1.0

- Initial public release of `cl-boundary-kit`.
- Added explicit boundary abstractions for filesystem, environment, clock,
  random, process, network, and logging interactions.
- Included deterministic test doubles, recording wrappers, examples, and a
  self-contained SBCL test suite.
