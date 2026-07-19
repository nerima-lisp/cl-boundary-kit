# cl-boundary-kit

`cl-boundary-kit` is a small Common Lisp library for making boundaries to the
outside world explicit.

It provides lightweight protocols and test doubles for:

- filesystem access
- environment access
- clocks and fake clocks
- randomness sources
- process execution
- network requests
- logging sinks
- boundary recording and context composition

It is not an application framework, not a CLI framework, and not a generic
utility grab bag. The goal is to make external effects easy to model, swap, and
test.

## Status

- Small, explicit surface area
- Self-contained ASDF system
- Tests included for every exported subsystem

## Highlights

- Protocol-first design with generic functions for each boundary
- Recording and fake implementations for tests
- Recording call histories preserve the arguments and results you asserted on
- Boundary context composition for wiring at the application edge
- Reproducible examples that run from the REPL

## Installation

Clone the repository and load it with ASDF:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit)
```

If you use a local-projects setup, place the repository under your ASDF source
tree and load it the same way.

## Quick Start

```lisp
(asdf:load-system :cl-boundary-kit)

(let ((clock (cl-boundary-kit:make-fake-clock :start 1000)))
  (list (cl-boundary-kit:clock-now clock)
        (progn (cl-boundary-kit:advance-fake-clock clock 5)
               (cl-boundary-kit:clock-now clock))))
;; => (1000 1005)
```

```lisp
(let* ((delegate (cl-boundary-kit:make-filesystem
                  :write-file-fn (lambda (path content
                                      &key if-exists if-does-not-exist external-format)
                                   (list :path path
                                         :content content
                                         :if-exists if-exists
                                         :if-does-not-exist if-does-not-exist
                                         :external-format external-format))))
       (fs (cl-boundary-kit:make-recording-filesystem :delegate delegate))
       (result (cl-boundary-kit:filesystem-store-file fs #P"example.txt" "hello"
                                                      :if-exists :append
                                                      :if-does-not-exist :create
                                                      :external-format :utf-8)))
  (list :result result
        :calls (cl-boundary-kit:recording-filesystem-calls fs)))
;; => (:RESULT (:PATH #P"example.txt" :CONTENT "hello" ...)
;;     :CALLS ((:OPERATION :WRITE-FILE ...)))
```

That pattern works the same way for environment, process, network, and logging
boundaries.

Recording helpers keep both the arguments and the returned result, including
explicit `nil` results when that is what the boundary returned.
When a delegate operation fails, the recording wrappers for filesystem,
environment, process, network, and custom boundaries re-signal that failure
without adding a partial call record. Logging is slightly different:
`make-recording-logger` keeps the attempted event even if the delegate sink
signals an error, which makes sink failures inspectable in tests.

## Core Concepts

### Boundary

A boundary is a controlled access point to the outside world. Each boundary is
modeled explicitly instead of being hidden behind ad hoc helpers.

### Protocol

Boundaries are exposed through generic functions such as
`filesystem-read-file`, `clock-now`, and `process-boundary-run`.

### Test Double

The library includes fakes and recording variants so tests can avoid real I/O
without a mocking framework.

### Testing Helper

Use `assert-recorded-call` when you want a small assertion around a recording
boundary call history without pulling in a separate matcher library.
Use `boundary-call-plist` when you want to construct the same call shape
explicitly in a unit test.

```lisp
(let* ((filesystem (cl-boundary-kit:make-recording-filesystem
                    :delegate (cl-boundary-kit:make-filesystem
                               :write-file-fn (lambda (path content
                                                   &key if-exists if-does-not-exist external-format)
                                                (list :path path
                                                      :content content
                                                      :if-exists if-exists
                                                      :if-does-not-exist if-does-not-exist
                                                      :external-format external-format)))))
       (result (cl-boundary-kit:filesystem-store-file filesystem #P"example.txt" "hello")))
  (cl-boundary-kit:assert-recorded-call
   (cl-boundary-kit:recording-filesystem-calls filesystem)
   :write-file
   :arguments (list #P"example.txt"
                    :content "hello"
                    :if-exists nil
                    :if-does-not-exist nil
                    :external-format nil)
   :result result))
;; => (:OPERATION :WRITE-FILE
;;     :ARGUMENTS (#P"example.txt" :CONTENT "hello"
;;                 :IF-EXISTS NIL :IF-DOES-NOT-EXIST NIL :EXTERNAL-FORMAT NIL)
;;     :RESULT (:PATH #P"example.txt" :CONTENT "hello"
;;              :IF-EXISTS NIL :IF-DOES-NOT-EXIST NIL :EXTERNAL-FORMAT NIL))
```

```lisp
(cl-boundary-kit:boundary-call-plist
 :write-file
 (list #P"example.txt" :content "hello")
 :result t)
;; => (:OPERATION :WRITE-FILE
;;     :ARGUMENTS (#P"example.txt" :CONTENT "hello")
;;     :RESULT T)
```

### Boundary Context

`make-boundary-context` bundles multiple boundaries into a single object for
composition at the application edge.

`make-boundary-context` expects keyword/value pairs and rejects an odd binding
count. `boundary-context-get` also preserves an explicit stored `nil` instead of
falling back to the default.
`boundary-context-present-p` mirrors the same distinction without returning the
stored value.
Non-keyword context keys are rejected so the composition surface stays explicit.

## Architecture

The library is organized around a few small ideas:

- `src/protocols.lisp` defines the boundary protocols.
- `src/*.lisp` files provide concrete implementations, fakes, and recorders for
  each subsystem.
- `src/core.lisp` contains boundary context composition, recording helpers, and
  shared utilities.
- `src/testing.lisp` provides small assertion helpers used by the test suite.

This keeps application code at the edge of the system while making external
effects visible and testable.

## API Overview

### Composition

- `make-boundary-context`
- `boundary-context-get`
- `boundary-context-present-p`
- `make-recording-boundary`
- `recording-boundary-calls`
- `recording-boundary-invoke`

`make-recording-boundary` requires `:handler` to be a function.
`recording-boundary-invoke` records the operation, arguments, and returned
result from custom handlers, preserving explicit `nil` results. If the handler
signals an error, the failure is re-signaled without adding a partial call
record.

### Conditions

- `unsupported-boundary-operation`
- `unsupported-boundary-operation-operation`
- `unsupported-boundary-operation-detail`

Boundaries use `unsupported-boundary-operation` when a capability is
intentionally unavailable instead of silently emulating behavior. The reader
functions expose the failed operation and its detail so callers and tests can
branch on explicit unsupported cases.

### Filesystem

- `make-filesystem`
- `filesystem-read-file`
- `filesystem-store-file`
- `filesystem-probe-file`
- `filesystem-list-directory`
- `filesystem-path-exists-p`
- `make-test-filesystem`
- `make-recording-filesystem`
- `recording-filesystem-calls`

The default writer returns `t` after writing, and recording filesystems preserve
that delegate result while storing the exact operation arguments that produced
it. For write operations, the recorded arguments include `:if-exists`,
`:if-does-not-exist`, and `:external-format`, so tests can assert on file I/O
policy without touching the host filesystem.
`make-test-filesystem` is a state-backed fake that accepts `:initial-files` as
either an alist or a plist, updates its in-memory files on write and append,
and exposes the same call-record contract via `recording-filesystem-calls`.
Missing reads and unsupported write-mode combinations signal explicitly instead
of silently inventing host filesystem behavior.
`make-filesystem` validates all function collaborators at construction time, and
recording filesystems require a `filesystem` delegate.

### Environment

- `make-environment`
- `environment-get`
- `environment-present-p`
- `environment-set`
- `environment-list`
- `make-test-environment`
- `make-recording-environment`
- `recording-environment-calls`

`make-test-environment` accepts either an alist or a plist of initial values.
Custom environment getters may return two values, where the second value marks
whether the first value is present. That lets a boundary preserve an explicit
`nil` result instead of falling back to a default.
Use `environment-present-p` when you need to distinguish a missing value from a
present `nil`.
The state-backed test environment also records reads, presence checks, and
writes through `recording-environment-calls`, so tests can inspect both the
observed values and the interaction history.
Its `environment-list` view is sorted by variable name, keeping examples and
test assertions reproducible across runs.
`make-environment` validates its collaborators at construction time: `:get-fn`
and `:list-fn` must be functions, and `:set-fn` must be either `nil` or a
function. Recording environments also require an `environment` delegate.

### Clock

- `make-clock`
- `clock-now`
- `clock-monotonic`
- `make-fake-clock`
- `advance-fake-clock`

`make-fake-clock` accepts an optional `:monotonic-start`, and
`advance-fake-clock` accepts `:monotonic-delta`, so tests can model wall-clock
time and monotonic time independently.
`make-clock` rejects non-function `:now-fn` and `:monotonic-fn` values.

### Random

- `make-random-source`
- `make-deterministic-random-source`
- `make-test-random-source`
- `random-source-random`

`make-deterministic-random-source` is intended for tests and reproducible
examples. Two sources created with the same seed produce the same sequence of
values for the same limits. Deterministic sources reject non-positive limits,
and `:modulus` must be an integer greater than 1.
`make-random-source` rejects non-`random-state` `:state` values, and every
`random-source-random` implementation rejects non-positive integer or real
limits.
`make-test-random-source` is a queue-backed fake for tests: each
`random-source-random` call consumes one precomputed value, signals when the
queue is exhausted, and rejects values that do not satisfy the requested
integer or real limit.

### Process

- `make-process-boundary`
- `make-test-process-boundary`
- `process-boundary-run`
- `make-recording-process-boundary`
- `recording-process-calls`

The default process runner returns a property list with `:command`, `:stdout`,
`:stderr`, and `:exit-code`. Recording process boundaries preserve the same
result while also storing the input arguments that produced it, including an
explicit `nil` result when that is what the delegate or test queue returned.
`process-boundary-run` accepts either a string program name or a pre-tokenized
command list; in both cases `:arguments` are appended to the normalized
command list stored in the native runner result.
`make-test-process-boundary` is a queue-backed fake for deterministic tests:
each `process-boundary-run` call consumes one precomputed result, records the
call, and signals when the queue is exhausted.
Both constructors validate their collaborators up front: `:run-fn` must be a
function, and recording wrappers require a `process-boundary` delegate.

### Network

- `make-network-boundary`
- `make-test-network-boundary`
- `network-boundary-request`
- `make-recording-network-boundary`
- `recording-network-calls`

`network-boundary-request` accepts an opaque request object plus an optional
`:timeout`, which is forwarded unchanged to the configured transport function.
Recording network boundaries keep both the request and the returned response so
tests can assert on transport interactions directly, including explicit `nil`
responses from test queues or delegates.
`make-test-network-boundary` is the matching queue-backed fake for network
responses: each request consumes one precomputed response, records the request,
and signals when no responses remain.
`make-network-boundary` requires `:request-fn` to be a function, and
`make-recording-network-boundary` requires a `network-boundary` delegate.

Boundaries whose native implementation is intentionally unavailable signal the
`unsupported-boundary-operation` condition. Its readers,
`unsupported-boundary-operation-operation` and
`unsupported-boundary-operation-detail`, expose the failed operation and the
reason. For example, `make-network-boundary` without a `:request-fn` and
`make-environment` without a `:set-fn` both fail this way instead of silently
pretending to support those operations.

### Logging

- `make-logger`
- `logger-log`
- `make-test-logger`
- `make-recording-logger`
- `recording-log-events`

`make-logger` accepts `:timestamp-fn` so log events can stay deterministic in
tests. `logger-log` returns the emitted event object, and
`make-recording-logger` records and forwards that same object to its delegate
sink. If the sink signals an error, the attempted event stays in
`recording-log-events` so sink failures remain inspectable in tests.
`make-test-logger` is the sinkless test double for the same contract: it records
each emitted event in `recording-log-events`, returns the exact event object to
the caller, and keeps timestamp generation injectable for deterministic tests.
`make-logger` rejects non-function `:sink-fn` and `:timestamp-fn` values, and
recording loggers require a `logger` delegate.

### Testing Helpers

- `assert-recorded-call`
- `assert-recorded-call-count`
- `assert-recorded-call-sequence`
- `boundary-call-plist`

`assert-recorded-call` checks a recorder call list for an operation, optional
arguments, and an optional result, signaling an error when no matching call is
present. `assert-recorded-call-count` asserts how many matching calls were
recorded without forcing the whole call history into an `equal` comparison.
`assert-recorded-call-sequence` asserts ordered call history and can relax the
tail with `:exact-length nil` when you only care about a prefix. Supplying `:result nil` asserts an explicit `nil` result. `boundary-call-plist` builds the same plist shape used by the built-in recorders from an explicit argument list,
which is useful when you want to compare or construct expected call records
directly in tests.

## Examples

Each documented example is directly runnable with `sbcl --script examples/<name>.lisp`
from a checkout; the files self-bootstrap the `cl-boundary-kit` system before
executing their snippet body.

- [`examples/fake-clock.lisp`](examples/fake-clock.lisp) shows deterministic time control.
- [`examples/deterministic-random.lisp`](examples/deterministic-random.lisp) shows reproducible random sequences from a fixed seed.
- [`examples/test-random.lisp`](examples/test-random.lisp) shows a queue-backed random source for deterministic tests.
- [`examples/recording-filesystem.lisp`](examples/recording-filesystem.lisp) shows write-option propagation and call recording around filesystem access.
- [`examples/test-filesystem.lisp`](examples/test-filesystem.lisp) shows a stateful in-memory filesystem fake with readable call history.
- [`examples/recording-environment.lisp`](examples/recording-environment.lisp) shows a recording environment with explicit test values.
- [`examples/test-environment.lisp`](examples/test-environment.lisp) shows a stateful environment fake with explicit `nil`, presence checks, mutation, and readable call history.
- [`examples/unsupported-operation.lisp`](examples/unsupported-operation.lisp) shows how to handle an unsupported boundary operation explicitly.
- [`examples/boundary-composition.lisp`](examples/boundary-composition.lisp) shows bundling multiple boundaries into a context.
- [`examples/recording-boundary.lisp`](examples/recording-boundary.lisp) shows recording a custom boundary handler and inspecting the stored result.
- [`examples/recording-process.lisp`](examples/recording-process.lisp) shows recording process invocations with a stub delegate.
- [`examples/test-process.lisp`](examples/test-process.lisp) shows queue-backed process results for deterministic tests.
- [`examples/recording-network.lisp`](examples/recording-network.lisp) shows recording network requests, including timeout propagation, with a stub transport.
- [`examples/test-network.lisp`](examples/test-network.lisp) shows queue-backed network responses for deterministic tests.
- [`examples/recording-logger.lisp`](examples/recording-logger.lisp) shows that the emitted log event is the same object returned, recorded, and forwarded to a sink.
- [`examples/test-logger.lisp`](examples/test-logger.lisp) shows a sinkless logger fake whose emitted events stay directly inspectable.

## Repository Layout

- `src/` core library implementation
- `t/` test runner and subsystem tests
- `examples/` REPL-friendly usage snippets
- `cl-boundary-kit.asd` ASDF system definitions
- `run-tests.lisp` canonical checkout test runner
- `flake.nix` pinned Nix build, test, report, and coverage entrypoints
- `nix/` CI runner and coverage threshold tooling
- `todo.md` original implementation prompt retained for context
- `COOKBOOK.md` pattern-oriented usage guide for supported flows
- `FAQ.md` user-facing decision points and contract clarifications
- `ARCHITECTURE.md` layering model and design constraints
- `COMPATIBILITY.md` current verification scope and non-claims
- `CONTRIBUTING.md` change workflow and test expectations
- `GOVERNANCE.md` maintainer decision model and contract surface
- `CODE_OF_CONDUCT.md` contributor behavior and reporting expectations
- `SUPPORT.md` request routing and maintenance boundary
- `RELEASE.md` maintainer release checklist and evidence requirements
- `CHANGELOG.md` release history and pending unreleased changes
- `ROADMAP.md` deferred work and non-goals
- `SECURITY.md` security reporting guidance
- `LICENSE` MIT license terms

## Testing

The recommended Linux checkout test command is:

```sh
nix run .#test
```

The flake pins SBCL, `cl-prolog`, and `cl-weave`, so this path does not require
Quicklisp or separately installed Common Lisp dependencies. `cl-weave` provides
the test runner, machine-readable reporting, and coverage integration.
`cl-prolog` is used by the test system to express and verify cross-boundary
invariants. These runnable flake apps and checks are intentionally Linux-only
(`x86_64-linux`), matching the Ubuntu GitHub Actions workflow.

On a Linux host, run `nix flake check --print-build-logs` to execute every flake
check, including the canonical checkout runner, machine-readable report
generation, and the coverage threshold. The CI workflow additionally builds the
`machine-report` and `coverage` checks as artifacts. They contain `report.json`,
and, for the coverage check, `coverage.dat`, `coverage-summary.txt`, and the
`coverage-html/` report. The coverage check currently requires at least 80%
statement coverage. On macOS and other non-Linux hosts, `nix run .#test` is not
available and `nix flake check` does not reproduce the Ubuntu CI check set
because the Linux-only outputs are omitted.

For local development on any host with an existing SBCL environment, run
`sbcl --script run-tests.lisp`. Quicklisp itself is not required, but direct
SBCL and REPL use requires `cl-prolog` and `cl-weave` to be discoverable by
ASDF. The suite exercises
filesystem, environment, clock, random, process, network, logging, recording,
and boundary composition behavior.

If you want to run it from a REPL instead, register this checkout and those
dependencies, then load the test system and invoke the same documented REPL
runner explicitly:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit/test)
(cl-boundary-kit/test:run-tests)
```

The documented REPL runner reaches successful completion with `0 failures` and
exit status 0 when the whole suite is green; treat any other outcome as a
regression to fix before relying on the checkout.

## Compatibility

See [`COMPATIBILITY.md`](COMPATIBILITY.md) for the current verification scope,
non-claims, and change policy. Compatibility claims are intentionally limited
to flows that are exercised by executable verification in this repository.
Behavior differences on unverified Common Lisp implementations or platforms
should not be treated as supported contracts unless that document says so.

## Stability Policy

The public contract is intentionally narrow:

- The exported symbols listed in `## API Overview` define the supported library
  surface for `0.1.x`.
- The checked-in README snippets, `examples/*.lisp`, and the
  `asdf:load-system :cl-boundary-kit/test` plus `cl-boundary-kit/test:run-tests`
  flow are treated as regression-checked usage contracts, not illustrative
  pseudocode.
- `COOKBOOK.md`, `FAQ.md`, `ARCHITECTURE.md`, `COMPATIBILITY.md`, and
  `RELEASE.md` are also part of the executable documentation contract when
  their guidance is backed by repository-level tests.
  - Breaking behavioral changes must be reflected in `README.md`,
    `COMPATIBILITY.md`, `CHANGELOG.md`, and the executable documentation tests
    in `t/api-test.lisp`, `t/api-doc-claims-test.lisp`,
    `t/api-doc-links-test.lisp`, `t/api-doc-links-documents-test.lisp`,
    `t/api-executable-docs-test.lisp`, and `t/examples-test.lisp`.
- Deprecations and removals must be called out explicitly in `CHANGELOG.md`,
  and when a supported replacement exists they should include concrete
  migration guidance instead of leaving consumers to infer the next step.
- Unsupported operations should keep failing explicitly; convenience fallbacks
  that hide host differences are out of scope for this library.

The project is still early-stage software, so additions may happen in `0.x`,
but any intentionally breaking change should be called out in the changelog and
should come with updated compatibility notes and migration guidance when a
replacement path exists.

## Design Non-Goals

- CLI framework
- app-specific adapters
- full dependency injection container
- full mocking framework
- generic utility package
- domain logic

## Implementation Notes

- The public API is intentionally small and explicit.
- Recording variants are provided for test assertions without a separate
  mocking framework.
- `examples/` contains REPL-friendly snippets rather than a full tutorial.
- `cl-boundary-kit/test` is the canonical test entrypoint for both
  `run-tests.lisp` and REPL use.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for local setup, workflow, and test
expectations. Changes to the supported public contract should update the
executable tests, relevant examples, and `README.md` in the same change.
Deprecations or intentionally breaking changes should also update
[`CHANGELOG.md`](CHANGELOG.md) with migration guidance when a supported
replacement exists.

## Cookbook

See [`COOKBOOK.md`](COOKBOOK.md) for pattern-oriented usage guidance that sits
between isolated examples and the full API overview.

## FAQ

See [`FAQ.md`](FAQ.md) for user-facing decision points such as when to choose a
recording boundary, when to choose a test boundary, and how explicit `nil`
values and unsupported operations are treated. It also explains how to route
implementation/platform-specific behavior through support or security, and how
deprecations or intentionally breaking changes are announced.
Route those questions through [`SUPPORT.md`](SUPPORT.md), or the
private security route when a report is sensitive. Include the
exact exported API, a minimal reproduction, and the
Common Lisp implementation/platform involved.

## Architecture

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the layering model, boundary
principles, and file responsibilities that shape the supported design.

## Governance

See [`GOVERNANCE.md`](GOVERNANCE.md) for maintainer decision criteria, contract
surface, and escalation boundaries. Supported contract claims are defined by
the checked-in documentation, examples, and executable verification rather
than by roadmap intent alone.

## Code of Conduct

See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for contributor behavior
expectations and the reporting path for conduct issues.

## Support

See [`SUPPORT.md`](SUPPORT.md) for where to ask usage questions, how to report
reproducible bugs, and when to use the private security route instead.
Support requests should include the exact exported API, a minimal
reproduction, and the Common Lisp implementation/platform involved.

## Security

See [`SECURITY.md`](SECURITY.md) for the private security route, supported
versions, and disclosure expectations. Do not post exploit details, secrets,
or sensitive system state in public issues; use the private report path there
instead.

## Roadmap

See [`ROADMAP.md`](ROADMAP.md) for directional, non-committed work and
non-goals. Shipped or concretely queued public changes belong in
[`CHANGELOG.md`](CHANGELOG.md) and should not be inferred from roadmap text.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for release history and unreleased changes.

## Release Process

See [`RELEASE.md`](RELEASE.md) for the maintainer checklist that ties version
updates, contract changes, and executable verification together.

## License

MIT, see [`LICENSE`](LICENSE).
