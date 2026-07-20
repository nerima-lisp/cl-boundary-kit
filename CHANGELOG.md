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

## 0.3.0

### Added

- Added a UUID boundary (`make-uuid-source`, `make-sequential-uuid-source`,
  `make-test-uuid-source`, `make-recording-uuid-source`, and `uuid-generate`)
  for modeling unique identifier generation, with a deterministic
  counter-backed double and a queue-backed test double.
- Added a sleeper boundary (`make-sleeper`, `make-test-sleeper`,
  `make-recording-sleeper`, and `sleeper-sleep`) for modeling delays, with a
  non-blocking test double so time-dependent code stays testable.
- Added a console boundary (`make-console`, `make-test-console`,
  `test-console-output`, `test-console-errors`, `make-recording-console`,
  `console-read-line`, `console-write-line`, and `console-write-error`) for
  modeling terminal input and output with a capturing in-memory fake.
- Added a system boundary (`make-system-boundary`,
  `make-test-system-boundary`, `test-system-exit-codes`,
  `make-recording-system-boundary`, and `system-exit`) for modeling process
  termination, with a non-terminating double that records requested exit codes.
- Added a key/value store boundary (`make-kv-store`, `make-test-kv-store`,
  `make-recording-kv-store`, `kv-get`, `kv-put`, `kv-delete`, and `kv-keys`)
  with a stateful in-memory fake and presence-aware reads.
- Added a metrics boundary (`make-metrics`, `make-test-metrics`,
  `make-recording-metrics`, `recording-metric-events`, `metrics-count`,
  `metrics-gauge`, and `metrics-timing`) for modeling fire-and-forget
  instrumentation, mirroring the logging boundary.
- Added a lock boundary (`make-lock`, `make-test-lock`, `test-lock-held-p`,
  `make-recording-lock`, `lock-acquire`, `lock-release`, and `call-with-lock`)
  for modeling mutual exclusion, with a state-tracking test double that surfaces
  self-deadlocks and supports a reentrant mode; `call-with-lock` acquires,
  runs a thunk, and releases in an `unwind-protect` cleanup.
- Added a working-directory boundary (`make-working-directory`,
  `make-test-working-directory`, `make-recording-working-directory`,
  `working-directory-get`, and `working-directory-set`) for modeling the current
  directory without changing the real process directory.
- Added a publisher boundary (`make-publisher`, `make-test-publisher`,
  `make-recording-publisher`, `recording-published-messages`, and
  `publisher-publish`) for modeling fire-and-forget message publishing.
- Added a temp-path boundary (`make-temp-path-source`,
  `make-sequential-temp-path-source`, `make-test-temp-path-source`,
  `make-recording-temp-path-source`, and `temp-path-next`) for modeling unique
  temporary file path allocation.
- Added a command-line arguments boundary (`make-args`, `make-test-args`,
  `make-recording-args`, `args-list`, `args-count`, and `args-nth`).
- Added a host-info boundary (`make-host-info`, `make-test-host-info`,
  `make-recording-host-info`, `host-info-hostname`, `host-info-username`, and
  `host-info-pid`) for modeling process introspection.
- Added a DNS resolver boundary (`make-dns-resolver`, `make-test-dns-resolver`,
  `make-recording-dns-resolver`, and `dns-resolve`) with an in-memory fake that
  signals resolution failure for unknown hosts.
- Added a secret store boundary (`make-secret-store`, `make-test-secret-store`,
  `make-recording-secret-store`, `secret-get`, and `secret-names`) whose recording
  wrapper redacts secret values so they never leak into a call history;
  `secret-names` enumerates the configured secret names (which, being keys rather
  than values, are recorded verbatim).
- Added a feature-flags boundary (`make-feature-flags`,
  `make-test-feature-flags`, `make-recording-feature-flags`, `feature-enabled-p`,
  `feature-flags-enabled`, and `call-if-feature-enabled`);
  `feature-flags-enabled` enumerates the currently-enabled flags (unsupported on
  a native boundary without an `:enabled-list-fn`), and `call-if-feature-enabled`
  runs a thunk when a flag is on, with an optional disabled fallback.
- Added a cache boundary (`make-cache`, `make-test-cache`, `make-recording-cache`,
  `cache-get`, `cache-put`, and `cache-evict`) with time-to-live expiry driven by
  an injectable clock.
- Added a semaphore boundary (`make-semaphore`, `make-test-semaphore`,
  `make-recording-semaphore`, `semaphore-acquire`, `semaphore-release`,
  `semaphore-available`, and `call-with-semaphore`) whose test double signals on
  permit exhaustion; `call-with-semaphore` acquires a permit, runs a thunk, and
  releases it in an `unwind-protect` cleanup.
- Added a subscriber boundary (`make-subscriber`, `make-test-subscriber`,
  `make-recording-subscriber`, `subscriber-poll`, and `subscriber-poll-batch`)
  pairing with the publisher boundary for message consumption;
  `subscriber-poll-batch` drains up to a bounded maximum so it always terminates.
- Added a notifier boundary (`make-notifier`, `make-test-notifier`,
  `make-recording-notifier`, `recording-sent-notifications`, and
  `notifier-notify`) for modeling email/push notifications.
- Added a rate limiter boundary (`make-rate-limiter`, `make-test-rate-limiter`,
  `make-recording-rate-limiter`, `rate-limiter-allow-p`,
  `rate-limiter-available`, and `call-if-allowed`) with an in-memory token bucket
  whose refill is driven by an injectable clock; `call-if-allowed` runs a thunk
  only while quota remains, with an optional throttled fallback.
- Added a scheduler boundary (`make-scheduler`, `make-test-scheduler`,
  `test-scheduler-pending`, `test-scheduler-run-pending`,
  `make-recording-scheduler`, `scheduler-schedule`, and `scheduler-cancel`) for
  modeling deferred execution, with a fake that records tasks and runs them on
  demand.
- Added `boundary-context-require` (fail-fast reader), `boundary-context-remove`,
  and `boundary-context-merge` for deriving boundary contexts, plus
  `boundary-context-count` and `boundary-context-alist` for inspecting a whole
  context at once.
- Added `event-values`, `find-event`, `count-events`, `assert-event-present`,
  `assert-no-event`, and `assert-event-count`, which inspect and match the event
  lists captured by the fire-and-forget boundaries (logging, metrics, publisher,
  notifier) -- `event-values` pulls a key from every event, and the rest match
  against key/value constraints -- plus `find-recorded-call` (the single-result
  counterpart of `filter-recorded-calls`), giving the event-based and
  operation-based testing helper families symmetric coverage.
- Added `assert-no-recorded-call`, `assert-recorded-call-order`,
  `assert-recorded-operations`,
  `filter-recorded-calls`, `count-recorded-calls`, `recorded-call-operations`,
  `recorded-call-results`, `recorded-call-operation`, `recorded-call-arguments`,
  `recorded-call-result`, `nth-recorded-call`, and `last-recorded-call` testing
  helpers for non-asserting inspection, ordering assertions, negative assertions,
  and single-call field access over recorded call histories.
- Added `filesystem-delete-file`, `filesystem-copy-file`, and
  `filesystem-rename-file`, completing the filesystem's file operations. Delete
  returns whether the path existed (matching `kv-delete`/`cache-evict`); the
  native copy transfers raw bytes and the native rename uses `cl:rename-file` so
  both preserve exact content; the test filesystem updates its in-memory entries;
  and recording filesystems record each operation.
- Added `filesystem-make-directory`, `filesystem-directory-exists-p`, and
  `filesystem-delete-directory`, giving the filesystem boundary directory
  support alongside its file operations. The test filesystem tracks created
  directories in memory (an empty made directory still reports as existing and a
  non-empty one refuses deletion), and recording filesystems record each
  operation.
- Added `filesystem-read-file-lines` and `filesystem-store-file-lines`, which
  read a file into a list of lines (following `read-line` semantics) and write a
  list of strings as newline-terminated text (round-tripping with each other),
  plus `filesystem-append-file`, which appends content to a file (creating it if
  absent). All three are derived from
  `filesystem-read-file`/`filesystem-store-file`, so they work across every
  variant.
- Added `call-with-elapsed`, which calls a thunk and returns its result plus the
  monotonic time elapsed during it (measured with a clock), composing with
  `metrics-timing` and staying deterministic under a fake clock.
- Added `console-write`, which writes text to standard output without a trailing
  newline (useful for prompts); its output is captured in `test-console-output`
  and the recording console keeps `:write` and `:write-line` distinct. Added
  `console-prompt`, which writes a prompt without a newline and reads one line of
  input, and `console-format`/`console-format-line`, which write a `format`ted string
  without or with a trailing newline (mirroring `console-write`/`console-write-line`).
- Added `args-rest`, which returns the command-line arguments from a given index
  onward (useful for dropping a leading program name).
- Added `environment-unset` (removes a variable, returning whether it was bound;
  unsupported on a native environment without an `:unset-fn`) and `cache-clear`
  (empties the cache; unsupported on a native cache without a `:clear-fn`),
  rounding out the environment and cache operation sets.
- Added `call-with-environment-variable` and `call-with-working-directory`, which
  temporarily override an environment variable or the working directory for the
  duration of a thunk and restore the previous state in an `unwind-protect`
  cleanup.
- Added derived convenience operations on existing boundaries: `kv-update`
  (read-modify-write), `kv-clear`, `kv-get-or-put`, and `kv-increment` (counter
  increment treating an absent key as 0) on the key/value store,
  `cache-fetch` (read-through / get-or-compute) on the cache, `metrics-increment`
  on metrics, `random-source-element`, `random-source-boolean`,
  `random-source-sample` (draw N distinct elements without replacement),
  `random-source-shuffle`, and `random-source-bytes` (a random `(unsigned-byte 8)`
  vector for nonces/salts/tokens) on random sources, and `logger-debug`, `logger-info`, `logger-warn`, and `logger-error`
  level wrappers over `logger-log`. The store, cache, and random operations are
  derived from their protocols, so they work across the native, test, and
  recording variants without new collaborators.
- Added `reset-recording-*` history-clearing functions and dedicated
  regression suites and runnable examples for each of the new boundaries.
- Added `examples/application-composition.lisp`, a deterministic request handler
  composing the uuid, key/value, logging, metrics, and clock boundaries through a
  single boundary context, demonstrating multi-boundary composition end to end.

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
- Added `process-result-success-p`, which reads a `process-boundary-run` result's
  `:exit-code` and returns whether it is 0 (the common success check), and
  `process-result-check`, which returns the result on success but signals an
  error with the command, exit code, and stderr on failure (the "run or fail
  loudly" pattern).

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
