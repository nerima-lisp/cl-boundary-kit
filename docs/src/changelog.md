# Changelog

This project follows a simple keep-a-changelog-style structure.

## Unreleased

This section tracks intentional public changes that may ship in the next
release. Long-term ideas, non-committed exploration, and deferred work belong
in [Roadmap](roadmap.md) instead.

Deprecations, removals, and intentionally breaking behavior changes should be
called out explicitly here. When a supported replacement exists, include
migration guidance so consumers can move without inferring policy from code
diffs alone.

Nothing is queued for the next release yet.

## 1.0.0

First stable release.

No exported symbol, protocol, or documented behavior changes from `0.6.0`. What
changes is the commitment attached to that surface: `1.x` now follows the
semantic-versioning contract in [Stability Policy](stability-policy.md),
so a documented export cannot be removed or given incompatible behavior without
a `2.0.0` major release. The release also fixes several defects that made this
repository's own verification weaker than it claimed to be.

### Stability

- The exported API documented across the `docs/src` Guide pages is now a stable
  `1.x` contract: additive changes ship as minor releases, incompatible changes
  require a major release, and anything scheduled for removal is deprecated
  first in `CHANGELOG.md` with concrete migration guidance.
- `SECURITY.md`, `RELEASE.md`, and `docs/src/stability-policy.md` moved from
  `0.6.x`-series wording to that `1.0.x` commitment, and `ROADMAP.md` no longer
  frames the project as pre-stable.

### Fixed

- `examples/*.lisp` could not run from a bare checkout at all, even though
  `docs/src/examples.md` documents `sbcl --script examples/<name>.lisp` as the
  way to run them. `examples/bootstrap.lisp` called
  `(asdf:load-system :cl-log-kit)` without ever configuring a source registry,
  so the command failed with `Component :CL-LOG-KIT not found` unless the caller
  had already exported `CL_SOURCE_REGISTRY`. It now locates sibling dependency
  checkouts the way `run-tests.lisp` does, and only for systems ASDF cannot
  already resolve, so a caller that configured a registry pays nothing for the
  search. The test suite hid the bug because it runs examples as subprocesses
  that inherit the registry `run-tests.lisp` exports.
- `examples/bootstrap.lisp` also loaded the ~70 `src/*.lisp` files by hand, in
  interpreted mode, on every example run. That list had to be kept in lockstep
  with `cl-boundary-kit.asd` by hand, and adding a source file without updating
  it broke the examples silently. The bootstrap now loads the system through
  ASDF, which keeps the component list in exactly one place and reuses the
  compiled-fasl cache instead of re-reading the tree as source.
- `run-tests.lisp` published every source-registry entry as a recursive `//`
  tree, even though each entry is a checkout root whose `.asd` sits at the top
  level. That registry is exported to the environment, so all ~40 example
  subprocesses re-walked six checkouts (`.git` directories included) before
  resolving a system that was immediately available. A fresh example process
  went from ~7s to ~0.2s and `examples-run-in-fresh-sbcl-processes` from 219s to
  6.8s, which also retires the flakiness of the 10s per-example timeout those
  runs used to sit just under. `flake.nix`'s `sourceRegistry` got the same fix.
- `run-tests.lisp` searched for every test dependency unconditionally, even when
  ASDF could already resolve all of them. The search globs `*/<system>.asd`
  under each of up to four parent directories, which is cheap beside a few
  sibling checkouts and ruinous anywhere else: run from a Nix store path -- as
  every flake check and app does -- the first parent is `/nix/store`, where a
  single such glob took 210s against 116k entries and matched 107 copies of the
  dependency, of which the search then picked an arbitrary one. Five
  dependencies made that roughly 17 minutes of filesystem scanning before the
  first test ran, close enough to CI's 30-minute cap to fail outright on a
  machine with a large store, and it could silently bind the suite to the wrong
  version of a dependency. Dependencies ASDF can already find are now skipped,
  so callers that set `CL_SOURCE_REGISTRY` first pay nothing and cannot pick up
  a stray copy, while a bare checkout still discovers its siblings.
- `t/test-macros.lisp` was listed as a `cl-boundary-kit/test` component but was
  never added to git. Nix copies only tracked files into the store, so all three
  `nix flake check` derivations failed with `Couldn't load
  .../t/test-macros.lisp: file does not exist`, while a local `sbcl --script
  run-tests.lisp` passed by reading the working tree directly.
- `nix build .#cl-boundary-kit` failed with `Component :CL-LOG-KIT not found`.
  The `packages.cl-boundary-kit` derivation never passed `cl-log-kit` to
  `buildASDFSystem`'s `lispLibs`; declaring it as a flake input only fed the
  `CL_SOURCE_REGISTRY` that `checks` and `devShells` use.
- `flake.lock` had drifted from `flake.nix`: the lock pinned `cl-prolog` v0.6.0
  and `cl-weave` v0.10.0 while `flake.nix` declared v0.8.0 and v0.11.0, and the
  declared `cl-log-kit` tag `v1.1.0` does not exist upstream at all. Inputs are
  now pinned to released tags that do exist -- `cl-weave` v1.0.0, `cl-prolog`
  v1.0.1, `cl-log-kit` v1.0.0, `cl-process-kit` v0.2.0, `cl-json-kit` v1.0.0 --
  and the lock was regenerated to match. No source change was required.
  `cl-prolog` is pinned at v1.0.1 rather than v1.0.0 because v1.0.0 carries a
  defect this repository's builds surface: an unbound variable in the type_error
  path of its Lisp-shape clause converter, which SBCL reports as a compile
  warning in every cold `nix flake check` log here.

### Documentation and build

- `README.md` is now a lean landing page (badges, a short description, a
  Quick Start snippet, and links out), matching `cl-weave`'s README structure.
  The exhaustive, executable-verified API/example contract it used to carry
  moved to the `docs/src` Guide pages (`docs/src/composition.md` and its
  sibling topic pages), which the test suite (`t/api-test.lisp`,
  `t/api-doc-claims-test.lisp`, `t/api-doc-links-test.lisp`,
  `t/api-executable-docs-test.lisp`, `t/examples-test.lisp`) now checks
  instead of `README.md` `## API Overview`/`## Examples`. `COMPATIBILITY.md`,
  `ARCHITECTURE.md`, `GOVERNANCE.md`, `SUPPORT.md`, `FAQ.md`, `RELEASE.md`,
  and `CONTRIBUTING.md` (and their `docs/src` mirrors) were updated to point
  at the new location; no exported symbol or documented behavior changed.

### Internal

- `cache-get`, `kv-get`, and `secret-get` on a recording boundary each
  hand-wrote the same `(values value present)` delegate-then-record shape;
  a new `define-recording-delegate-present-method` macro alongside
  `define-recording-delegate-method` (`src/recording-boundary.lisp`)
  generates it. The matching `test-kv-store`/`test-secret-store` `gethash`
  lookup was folded into a shared `%hash-table-get-present`
  (`src/core-utilities.lisp`).
- Removed the no-op `define-runtime-function` macro
  (`(progn (defun ...) 'name)`, behaviorally identical to plain `defun`) and
  its 7 call sites.
- `%process-call-keywords` (`src/process-recording.lisp`) built two
  near-duplicate plist literals instead of the conditional-splice idiom
  `%native-process-options` already established; now shares that style.
- `%wait-for-process-with-deadline` (`src/process-exec-lifecycle.lisp`)
  folded an unconditional "no deadline" branch into a polling loop clause;
  restructured as a top-level `if`.
- Added `deftest-reset-recording-clears-history` (`t/test-macros.lisp`), a
  shared `it`-case generator for the "one call recorded, reset clears it and
  returns the object" contract every recording boundary's test file
  asserted by hand; converted 19 of the 22 near-identical occurrences (3
  with an extra post-reset re-trigger assertion were left as-is).
- Adopted `cl-weave`'s `with-soft-assertions` in `t/context-test.lisp` and
  `t/kv-test.lisp` for `it` blocks with several independent `expect` calls.
- `flake.nix`: removed the unused `inputs@` capture in `outputs`, and
  generalized the `.asd` `:version` reader into an `asdVersion` function so the
  `cl-log-kit` derivation added for `lispLibs` derives its version from the same
  single source of truth rather than hard-coding one.
- Added `timeout-minutes: 10` to `.github/workflows/release.yml`'s job,
  matching `ci.yml` and `docs.yml`'s existing job-level timeouts.
- `%record-call` (`src/core-utilities.lisp`), the macro behind every recording
  boundary's call log, built a fresh `call` list and then deep-copied that
  whole freshly-consed spine again before storing it. Now copies only the
  `:arguments`/`:result` value forms while building the list, halving the
  consing on every recorded call (cache, kv, secret, subscriber, scheduler,
  rate limiter, process, network, filesystem, environment) with no change to
  recorded history.
- `plist-remove-keys` (`src/core-utilities.lisp`), used by
  `filesystem-store-file` on every write, allocated an `eq` hash-table to
  test membership in a fixed 3-keyword list; replaced with a `member` scan,
  which is faster and allocation-free at that size.
- `define-plist-accessor` (`src/core-utilities.lisp`) now declaims its
  generated reader `inline`, so the ~17 plist-getter wrappers it backs
  (`%filesystem-*`, `%process-*`, `recorded-call-*`) avoid full call overhead
  at their call sites instead of paying for a function call to run one
  `getf`.
- `define-emit-event-boundary-dispatch`'s (`src/core-utilities.lisp`)
  `recording-<class>` method, and the hand-written analog in
  `recording-logger`'s `%logger-emit-event` (`src/logging.lisp`), each
  deep-copied an event a second time purely to hand it to the delegate --
  redundant, since whichever `%<class>-emit-event`/`%logger-emit-event`
  method receives it next (plain, test, or another recording level) always
  makes its own defensive copy before storing or forwarding. Now passes the
  event through uncopied at that hand-off point; backs `metrics`, `notifier`,
  and `logger` recording boundaries, including nested ones.
- `%define-recording-filesystem-operation` (`src/filesystem-classes.lisp`)
  validated its `filesystem` argument via `%require-filesystem`, then called
  `%with-recording-filesystem-call`, which validates it again the same way;
  every `filesystem-read-file`/`-write-file`/`-probe-file`/`-delete-file`/
  `-copy-file`/`-rename-file`/`-list-directory`/`-make-directory`/
  `-directory-exists-p`/`-delete-directory` call paid for the check twice.
  Dropped the outer, now-redundant validation.

## 0.6.0

### Changed (breaking)

- `process-boundary-run` and `process-kit-run-fn` no longer wait unboundedly
  when a caller omits `:timeout`. It now defaults to
  `*default-process-timeout-seconds*` (60 seconds); a native child that runs
  past the deadline is SIGTERM-then-SIGKILL escalated, the same guarantee an
  explicit `:timeout` already provided.
  Migration: pass an explicit `:timeout nil` to restore the old unbounded wait.

### Documentation and build

- Added an MkDocs (Material) documentation site under `docs/`, publishable to
  GitHub Pages via `.github/workflows/docs.yml` and buildable offline with
  `nix build .#docs`. The site reorganizes the README's API reference into
  topic pages without changing the README itself, which remains the
  executable-verified source of truth.
- `flake.nix` now derives the package version from `cl-boundary-kit.asd`
  `:version` instead of hardcoding it, so the `cl-boundary-kit` and `docs`
  packages can no longer drift out of sync with the ASDF system definition.
- `cl-weave`, `cl-prolog`, `cl-json-kit`, `cl-log-kit`, and `cl-process-kit`
  are bumped to `v0.11.0`, `v0.8.0`, `v0.3.0`, `v1.1.0`, and `v0.1.0`
  respectively; `cl-log-kit` and `cl-process-kit` now pin to their first
  tagged releases instead of a verified commit.
- Internal refactor, no behavior change: three new macros
  (`define-plist-accessor`, `define-recording-boundary-constructor`,
  `define-recording-delegate-method`) collapse ~60 near-identical accessor,
  constructor, and CLOS recording-method definitions across `src/*.lisp` into
  single-form declarations. `%run-native-process/cps` and
  `test-scheduler-run-pending` each extract a self-contained sub-concern into a
  named helper. 26 pairs of near-identical "signals for unsupported boundary
  type" tests collapse into `it-each` tables, matching the pattern already
  used in `t/network-test.lisp`. `t/filesystem-test.lisp`,
  `t/process-test.lisp`, and `t/api-test-helpers-markdown.lisp` are each split
  into smaller, single-purpose files.
- Internal refactor, no behavior change: two new macros
  (`define-list-validator`, `define-name-validator`) and a shared
  `require-string` helper collapse 15 near-identical validator functions
  (list-must-be-a-list, name-must-be-a-symbol-or-string, and
  value-must-be-a-string checks) that were duplicated across `src/cache.lisp`,
  `src/dns.lisp`, `src/feature-flags.lisp`, `src/host-info.lisp`,
  `src/kv.lisp`, `src/metrics.lisp`, `src/network-helpers.lisp`,
  `src/notifier.lisp`, `src/process-helpers.lisp`, `src/publisher.lisp`,
  `src/random.lisp`, `src/secret.lisp`, `src/subscriber.lisp`,
  `src/temp-path.lisp`, `src/uuid.lisp`, and `src/working-directory.lisp` into
  single-form declarations or shared calls. `src/metrics.lisp` now uses the
  existing `define-emit-event-boundary-dispatch` macro (already used by
  `notifier.lisp`/`publisher.lisp`) instead of hand-duplicating its
  three-method dispatch. Six CLOS recording-delegate methods
  (`cache-evict`, `kv-put`, `kv-delete`, `kv-keys`, `feature-enabled-p`,
  `feature-flags-enabled`, `secret-names`, `working-directory-set`) that fit
  `define-recording-delegate-method`'s shape but predated its introduction now
  use it too. `t/prolog-boundary-invariants.lisp`'s untrusted-parsing, DCG,
  and finite-domain-constraint tests (cl-prolog 0.6.0 usage) split into a new
  `t/prolog-advanced-test.lisp`. `src/env-classes.lisp`'s
  `%make-native-environment`/`%make-test-environment`/
  `%make-recording-environment` each flatten a 1-4 level deep
  `multiple-value-bind`-plus-`(declare (ignore ...))` chain (the discarded
  secondary value was never used) into a plain `let` via a new
  single-value `%plist-value` helper in `src/env-helpers.lisp`.
- Test suite: adopted `cl-weave` v0.10+'s `with-soft-assertions` (aggregates
  every `expect` failure in a block into one report instead of stopping at
  the first) in the 8 `it` blocks across `t/env-test.lisp`,
  `t/coverage-completion-test.lisp`, `t/filesystem-test.lisp`,
  `t/kv-test.lisp`, `t/rate-limiter-test.lisp`, and `t/cache-test.lisp` with
  the most sequential `expect` calls (5-10 each), where seeing every failing
  assertion at once meaningfully speeds up diagnosing a broken boundary
  operation instead of fixing failures one bisection cycle at a time.
- Test suite: two new branch-coverage tests close real gaps identified from
  a measured sb-cover run (92.23% expression / 84.91% branch). `filesystem-
  ops-test.lisp` adds `make-filesystem-delete-file-signals-a-real-failure-
  instead-of-swallowing-it`, covering `%real-filesystem-delete-file`'s
  re-signal branch (a `file-error` where the path still exists, distinct
  from "already absent") via `delete-file` rejecting a directory pathname.
  `filesystem-test.lisp`'s `filesystem-round-trip` now also checks
  `filesystem-path-exists-p` against a genuinely absent real path, covering
  `make-filesystem`'s default `path-exists-p-fn`'s not-present branch
  alongside the already-tested present branch. `publisher-test.lisp`'s
  `publisher-publish-rejects-an-invalid-topic` now also passes a number
  (neither a string nor a symbol), covering `define-name-validator`'s
  `symbolp` branch's false arm; the existing `nil` case only ever exercised
  its true arm, since `nil` is itself a symbol.

## 0.5.0

### Added

- Optional adapters for three dependency-light sibling libraries, each in its
  own optional ASDF system so the core stays dependency-light:
  - `process-kit-run-fn` (`cl-boundary-kit/process-kit`), a `:run-fn` backed by
    `cl-process-kit` with process-group timeout and SIGTERM/SIGKILL escalation,
    usable in place of the hand-rolled `sb-ext:run-program` runner.
  - `recording-calls-to-json` (`cl-boundary-kit/json`), which serializes
    recorded call-history plists as a JSON array via `cl-json-kit`.
  - `make-log-kit-sink-fn`, which adapts a `cl-log-kit` logger into a
    `:sink-fn` for `make-logger`.

### Fixed

- `copy-value` now copies bit-vectors instead of returning them uncopied, so a
  caller can no longer mutate a stored or recorded bit-vector value in place.
- `scheduler-cancel` now always takes effect: cancelling a task that had
  already been snapshotted into a running `test-scheduler-run-pending` batch
  previously failed to skip it silently.
- `run-tests.lisp` no longer collects a stale or duplicate ancestor checkout
  of a local test dependency; it now stops at the first ancestor directory
  that has a match.

### Documentation and build

- The project's GitHub org changed from `takeokunn` to `nerima-lisp`; update
  any bookmarked repository, issue, or security-advisory links accordingly.
- The Nix flake and `run-tests.lisp` now also discover `cl-log-kit`,
  `cl-process-kit`, and `cl-json-kit`, pinning the first two by commit (no
  tagged release yet) and `cl-json-kit` at `v0.2.0`; `cl-weave` and
  `cl-prolog` are bumped to `v0.10.0` and `v0.7.0`.
- Internal refactor, no behavior change: `console.lisp`, the
  `filesystem-fakes-*` sources, `process-exec-helpers.lisp`, and `testing.lisp`
  are each split into smaller, single-purpose modules, and boundary sources
  share recording/event-dispatch macros instead of duplicating the same
  accessor pair per boundary.

## 0.4.0

This is a hardening release. It contains two intentionally breaking default
changes; both preserve the old behavior when opted back in.

### Changed (breaking)

- The native process boundary no longer searches `$PATH` by default.
  `*native-process-search-path-p*` now defaults to `nil`, so
  `make-process-boundary` requires an absolute program path unless the caller
  explicitly binds the variable to `t`. This prevents implicit execvp-style
  resolution of a relative or attacker-influenced program name.
  Migration: wrap trusted `$PATH`-dependent calls in
  `(let ((*native-process-search-path-p* t)) ...)`.
- Recording network boundaries now redact their in-memory call history by
  default. The delegate still returns the raw response to the caller, but stored
  requests and responses pass through a default sanitizer that redacts common
  sensitive fields (authorization headers, cookies, API keys, tokens,
  passwords, secrets, and payload/body/content values).
  Migration: pass `:request-redactor-fn #'identity` and
  `:response-redactor-fn #'identity` to `make-recording-network-boundary` when a
  test intentionally needs full-fidelity history.

### Added

- Independent-snapshot helpers (`%copy-boundary-value` and friends) so recorded
  history and emitted events are equal but independent copies; a caller that
  mutates a returned event or sink payload can no longer corrupt boundary
  history.
- The default temp-path source now uses 128-bit randomness, threads an
  injectable per-source random state, and skips candidate names that already
  exist on disk.

### Fixed

- Copying or renaming a file to itself is rejected before the destination is
  opened, so a copy can never truncate its own source through `:if-exists
  :supersede`, and rename-to-self no longer depends on host behavior.
- The filesystem delete operation tolerates a concurrent removal as a no-op
  instead of erroring.
- The scheduler preserves the failing task and all tasks queued after it when a
  task signals, and re-signals the error, instead of clearing the queue.
- Queue-backed test doubles (args, console, dns, random, subscriber, uuid,
  process) copy their seeded lists, so later mutation of a caller's list cannot
  corrupt the double.

### Documentation and build

- The Nix flake emits runnable apps and checks for `aarch64-darwin` in addition
  to `x86_64-linux`, and `run-tests.lisp` discovers local `cl-prolog`/`cl-weave`
  checkouts so `sbcl --script run-tests.lisp` works without Quicklisp.
- The random and UUID sources are documented as non-cryptographic; inject a
  CSPRNG-backed source for secrets, tokens, salts, or nonces.
- The cl-prolog invariant tests resolve library specials and conditions
  dynamically so the suite degrades gracefully across cl-prolog versions.

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
