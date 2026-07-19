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

## 0.2.0

### Added

- Added `assert-recorded-call-count` for asserting the number of matching
  recorded boundary calls without introducing a separate matcher dependency.
- Added `assert-recorded-call-sequence` for asserting ordered recorded-call
  history, including prefix-only checks via `:exact-length nil`.
- Added a `reset-recording-*-calls`/`reset-recording-log-events` function for
  every boundary (`reset-recording-boundary-calls`,
  `reset-recording-filesystem-calls`, `reset-recording-environment-calls`,
  `reset-recording-random-source-calls`, `reset-recording-process-calls`,
  `reset-recording-network-calls`, and `reset-recording-log-events`). Each one
  clears a boundary's recorded history in place and returns the boundary, so a
  long-lived recording/test boundary's memory use can be bounded without
  discarding and recreating the object.
- Added `*native-process-search-path-p*` to control whether the native process
  runner searches `$PATH` for the program (like `execvp`, and `t` by default);
  bind it to `nil` around a call to require an absolute program path instead.

### Fixed

- Fixed a double-recording bug in the recording filesystem, environment,
  process, network, and custom boundaries, and in `make-recording-logger`, so a
  single boundary call now appears exactly once in the recorded history.
- An explicit `:environment` passed to `process-boundary-run` now replaces the
  parent process environment instead of merging with it, and an explicit empty
  `:environment '()` gives the child none of it. Omitting `:environment` still
  inherits the parent environment unchanged. This closes a subprocess
  environment leak where inherited variables could reach a child that was meant
  to run with a restricted environment.
- Fixed an orphaned child process when a capture thread failed to start.
- `make-fake-clock` and `advance-fake-clock` now validate their numeric
  arguments instead of accepting non-numbers silently.

### Documentation

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
