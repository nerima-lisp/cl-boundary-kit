# cl-boundary-kit

[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-2952cc)](https://nerima-lisp.github.io/cl-boundary-kit/)

`cl-boundary-kit` is a small Common Lisp library for making boundaries to the
outside world explicit.

This README is the exhaustive, executable-verified API reference. A browsable
MkDocs (Material) site built from the same content, organized by topic, is
published at <https://nerima-lisp.github.io/cl-boundary-kit/>; its source
lives in [`docs/src/`](docs/src/README.md).

It provides lightweight protocols and test doubles for:

- filesystem access
- environment access
- clocks and fake clocks
- randomness sources
- unique identifier generation
- temporary file paths
- command-line arguments
- host introspection (hostname, user, pid)
- process execution
- network requests
- DNS resolution
- terminal input and output
- process termination
- delays and sleeping
- key/value stores
- time-to-live caches
- secret stores
- feature flags
- mutual exclusion locks
- counting semaphores
- rate limiting
- deferred scheduling
- working directory
- logging sinks
- metrics emission
- message publishing and consumption
- notifications (email/push)
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
- `boundary-context-require`
- `boundary-context-present-p`
- `boundary-context-keys`
- `boundary-context-count`
- `boundary-context-alist`
- `boundary-context-with`
- `boundary-context-remove`
- `boundary-context-merge`
- `make-recording-boundary`
- `recording-boundary-calls`
- `reset-recording-boundary-calls`
- `recording-boundary-invoke`

`make-recording-boundary` requires `:handler` to be a function.
`recording-boundary-invoke` records the operation, arguments, and returned
result from custom handlers, preserving explicit `nil` results. If the handler
signals an error, the failure is re-signaled without adding a partial call
record.
`boundary-context-keys` returns the keys bound in a context,
`boundary-context-count` returns how many bindings it has, and
`boundary-context-alist` returns all of them as a fresh `(key . value)` alist for
inspecting or serializing a whole context at once.
`boundary-context-with` returns a new context derived from an existing one
with explicit keyword overrides applied, leaving the original context
untouched.
`boundary-context-require` is the fail-fast reader: it returns a key's value or
signals when the key is absent, instead of silently substituting a default the
way `boundary-context-get` does. `boundary-context-remove` returns a new context
without the given keys, and `boundary-context-merge` returns a new context with a
second context's bindings layered over the first (the second wins on
conflicts); both leave their inputs untouched.
Every `reset-recording-*-calls`/`reset-recording-log-events` function across
this library clears a boundary's recorded history in place and returns the
boundary, so a long-lived recording/test boundary's memory use can be bounded
without discarding and recreating the object.

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
- `filesystem-read-file-lines`
- `filesystem-store-file`
- `filesystem-store-file-lines`
- `filesystem-append-file`
- `filesystem-probe-file`
- `filesystem-list-directory`
- `filesystem-path-exists-p`
- `filesystem-delete-file`
- `filesystem-copy-file`
- `filesystem-rename-file`
- `filesystem-make-directory`
- `filesystem-directory-exists-p`
- `filesystem-delete-directory`
- `make-test-filesystem`
- `make-recording-filesystem`
- `recording-filesystem-calls`
- `reset-recording-filesystem-calls`

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
`filesystem-delete-file` removes a path and returns whether it existed, matching
the delete contract shared with `kv-delete` and `cache-evict`; the state-backed
test filesystem drops the entry from its in-memory files, and recording
filesystems record the delete like any other operation.
`filesystem-copy-file` and `filesystem-rename-file` copy or move a path to a
destination and return the destination. The native copy transfers raw bytes and
the native rename uses `cl:rename-file` (atomic on the same volume), so both keep
the exact content rather than round-tripping through a string; the test
filesystem updates its in-memory entries, and recording filesystems record the
operation. Copying a file to itself is rejected before opening the destination,
so copy never truncates the source through `:if-exists :supersede`; renaming a
file to itself is rejected as well, avoiding implementation-dependent host
behavior and preserving fake filesystem contents.
`filesystem-read-file-lines` reads a file and returns its contents split into a
list of lines (following `read-line` semantics, so a trailing newline yields no
final empty line); it is derived from `filesystem-read-file`, so it works across
every variant and a recording filesystem records the underlying read.
`filesystem-store-file-lines` is the write-side counterpart: it writes a list of
strings as newline-terminated text (forwarding the same write options), so it
round-trips with `filesystem-read-file-lines`.
`filesystem-append-file` appends content to a file, creating it if absent, by
supplying the `:if-exists :append` and `:if-does-not-exist :create` combination
needed to append-or-create.
`filesystem-make-directory`, `filesystem-directory-exists-p`, and
`filesystem-delete-directory` round out the boundary with directory support. The
native versions use `ensure-directories-exist`, `probe-file`, and the host's
empty-directory deletion; the test filesystem tracks created directories in
memory (an empty directory it made still reports as existing, and a non-empty one
refuses deletion), and recording filesystems record each operation.

### Environment

- `make-environment`
- `environment-get`
- `environment-present-p`
- `environment-set`
- `environment-unset`
- `environment-list`
- `call-with-environment-variable`
- `make-test-environment`
- `make-recording-environment`
- `recording-environment-calls`
- `reset-recording-environment-calls`

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
and `:list-fn` must be functions, and `:set-fn` and `:unset-fn` must each be
either `nil` or a function.
Recording environments also require an `environment` delegate.
`environment-unset` removes a variable and returns whether it was bound; the
state-backed test environment drops it from its in-memory bindings, while a
native environment without an `:unset-fn` signals `unsupported-boundary-operation`,
just like `environment-set` without a `:set-fn`.
`call-with-environment-variable` temporarily binds a variable for the duration of
a thunk and restores its previous value (or unsets it when it was absent) in an
`unwind-protect` cleanup, so a scoped override is always undone even on a
non-local exit.

### Clock

- `make-clock`
- `clock-now`
- `clock-monotonic`
- `call-with-elapsed`
- `make-fake-clock`
- `advance-fake-clock`

`call-with-elapsed` calls a thunk and returns its result plus the monotonic time
elapsed during it, measured with the clock; it composes with `metrics-timing`,
which consumes an elapsed duration, and stays deterministic under a fake clock.
`make-fake-clock` accepts an optional `:monotonic-start`, and
`advance-fake-clock` accepts `:monotonic-delta`, so tests can model wall-clock
time and monotonic time independently.
`make-clock` rejects non-function `:now-fn` and `:monotonic-fn` values.

### Random

- `make-random-source`
- `make-deterministic-random-source`
- `make-test-random-source`
- `make-recording-random-source`
- `recording-random-source-calls`
- `reset-recording-random-source-calls`
- `random-source-random`
- `random-source-element`
- `random-source-boolean`
- `random-source-bytes`
- `random-source-sample`
- `random-source-shuffle`

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
`make-recording-random-source` records the requested limit and returned value
while delegating to a real or fake source (defaulting to
`make-random-source`), exposing the same call-record contract via
`recording-random-source-calls`.
`random-source-element` returns a random element of a non-empty sequence,
`random-source-boolean` returns a random boolean, `random-source-sample` returns
a list of N distinct elements drawn without replacement, `random-source-shuffle`
returns a freshly shuffled copy of a sequence (same type, input untouched), and
`random-source-bytes` returns a fresh `(unsigned-byte 8)` vector of N random
bytes. These helpers are based on Common Lisp `random-state`, not a
cryptographic RNG; for secrets, tokens, salts, or security nonces, inject a
boundary backed by your platform CSPRNG. All helpers are derived from
`random-source-random`, so they work with any random source and a recording
source records the underlying integer draws.

### Process

- `make-process-boundary`
- `process-kit-run-fn`
- `make-test-process-boundary`
- `process-boundary-run`
- `process-result-success-p`
- `process-result-check`
- `*native-process-search-path-p*`
- `*default-process-timeout-seconds*`
- `make-recording-process-boundary`
- `recording-process-calls`
- `reset-recording-process-calls`

The default process runner returns a property list with `:command`, `:stdout`,
`:stderr`, and `:exit-code`. `process-result-success-p` reads that result's
`:exit-code` and returns whether it is 0 (the common success check), signaling
when a result does not carry an integer `:exit-code`. `process-result-check`
returns the result on success but signals an error including the command, exit
code, and captured stderr on failure -- the "run or fail loudly" pattern. Recording process boundaries preserve the same
result while also storing the input arguments that produced it, including an
explicit `nil` result when that is what the delegate or test queue returned.
`process-boundary-run` accepts either a string program name or a pre-tokenized
command list; in both cases `:arguments` are appended to the normalized
command list stored in the native runner result. An explicit `:environment`
replaces rather than merges with the parent process's environment, and an
explicit empty `:environment '()` gives the child none of it; omitting
`:environment` inherits the parent environment unchanged.
`*native-process-search-path-p*` controls whether the native runner searches
`$PATH` for the program (like `execvp`). It is `nil` by default so native
process calls require absolute program paths unless callers explicitly bind it
to `t` for trusted convenience.
`:timeout` defaults to `*default-process-timeout-seconds*` (60), so a native
command execution is never left unbounded; a child that runs past the deadline
is SIGTERM-then-SIGKILL escalated. Pass an explicit `:timeout nil` to wait for
a child indefinitely instead.
`make-test-process-boundary` is a queue-backed fake for deterministic tests:
each `process-boundary-run` call consumes one precomputed result, records the
call, and signals when the queue is exhausted.
Both constructors validate their collaborators up front: `:run-fn` must be a
function, and recording wrappers require a `process-boundary` delegate.

`process-kit-run-fn` is a `:run-fn` backed by
[`cl-process-kit`](https://github.com/nerima-lisp/cl-process-kit), a
dependency-light process execution toolkit with process-group timeout and
SIGTERM/SIGKILL escalation, in place of this system's own hand-rolled
`sb-ext:run-program` loop:

```lisp
(make-process-boundary :run-fn #'process-kit-run-fn)
```

It returns the same `:command`/`:stdout`/`:stderr`/`:exit-code`/`:timed-out`
result shape as the default runner, so `process-result-success-p`,
`process-result-check`, and recording/test process boundaries work
unchanged regardless of which runner is plugged in.

### JSON

- `recording-calls-to-json`

`recording-calls-to-json` serializes the call-history plists that any
`recording-*-calls` reader returns as a JSON array of
`{operation, arguments, result}` objects, for logging, snapshotting, or diffing
boundary interactions. It is provided by the optional `cl-boundary-kit/json`
system, which pulls in
[`cl-json-kit`](https://github.com/nerima-lisp/cl-json-kit), a dependency-free
JSON reader/writer, so the core stays dependency-light:

```lisp
(recording-calls-to-json (recording-boundary-calls boundary) :pretty t)
```

An empty argument list serializes as `[]` and a `nil` result as `null`; pass
`:pretty t` to indent the output.

### Network

- `make-network-boundary`
- `make-test-network-boundary`
- `network-boundary-request`
- `make-recording-network-boundary`
- `recording-network-calls`
- `reset-recording-network-calls`

`network-boundary-request` accepts an opaque request object plus an optional
`:timeout`, which is forwarded unchanged to the configured transport function.
Recording network boundaries return the delegate's raw response to the caller
but sanitize their in-memory call history by default before storing requests
and responses. The default sanitizer redacts common sensitive fields such as
authorization headers, cookies, API keys, tokens, passwords, secrets, and
payload/body/content values while preserving non-sensitive metadata such as
method, URL, status, and safe headers. Pass explicit `:request-redactor-fn`
and `:response-redactor-fn` functions, for example `#'identity`, only when a
test intentionally needs full-fidelity call history.
The call history preserves explicit `nil` responses from test queues or delegates
after applying the configured response redactor.
`make-test-network-boundary` is the matching queue-backed fake for network
responses: each request consumes one precomputed response, records the request,
records the exact test call for assertion fidelity, and signals when no
responses remain.
`make-network-boundary` requires `:request-fn` to be a function, and
`make-recording-network-boundary` requires a `network-boundary` delegate plus
function-valued redactors when they are supplied.

Boundaries whose native implementation is intentionally unavailable signal the
`unsupported-boundary-operation` condition. Its readers,
`unsupported-boundary-operation-operation` and
`unsupported-boundary-operation-detail`, expose the failed operation and the
reason. For example, `make-network-boundary` without a `:request-fn` and
`make-environment` without a `:set-fn` both fail this way instead of silently
pretending to support those operations.

### Logging

- `make-logger`
- `make-log-kit-sink-fn`
- `logger-log`
- `logger-debug`
- `logger-info`
- `logger-warn`
- `logger-error`
- `make-test-logger`
- `make-recording-logger`
- `recording-log-events`
- `reset-recording-log-events`

`logger-debug`, `logger-info`, `logger-warn`, and `logger-error` are convenience
wrappers over `logger-log` that supply the matching level, so application code
can call `(logger-info logger "message" :field value)` directly.
`make-logger` accepts `:timestamp-fn` so log events can stay deterministic in
tests. `logger-log` returns the emitted event object, and
`make-recording-logger` records and forwards equal but independent snapshots to
its delegate sink. If the sink signals an error, the attempted event stays in
`recording-log-events` so sink failures remain inspectable in tests.
`make-test-logger` is the sinkless test double for the same contract: it records
each emitted event as an independent snapshot in `recording-log-events`, returns
an equal event object to the caller, and keeps timestamp generation injectable
for deterministic tests.
`make-logger` rejects non-function `:sink-fn` and `:timestamp-fn` values, and
recording loggers require a `logger` delegate.

`make-log-kit-sink-fn` adapts a [`cl-log-kit`](https://github.com/nerima-lisp/cl-log-kit)
`log-kit:logger` into a `:sink-fn` for `make-logger`, so a boundary logger's real
destination can be genuine structured logging (JSON or text, level-filtered,
stream-backed) while `make-test-logger`/`make-recording-logger` remain the test
doubles:

```lisp
(make-logger
 :sink-fn (make-log-kit-sink-fn
           (log-kit:make-logger :handler (make-instance 'log-kit:json-handler))))
```

This system's `:debug`/`:info`/`:warn`/`:error` levels map onto `cl-log-kit`'s
matching level constants; any other level passes through unchanged.

### Testing Helpers

- `assert-recorded-call`
- `assert-recorded-call-count`
- `assert-recorded-call-sequence`
- `assert-no-recorded-call`
- `assert-recorded-call-order`
- `assert-recorded-operations`
- `filter-recorded-calls`
- `count-recorded-calls`
- `find-recorded-call`
- `recorded-call-operations`
- `recorded-call-results`
- `recorded-call-operation`
- `recorded-call-arguments`
- `recorded-call-result`
- `nth-recorded-call`
- `last-recorded-call`
- `event-values`
- `find-event`
- `count-events`
- `assert-event-present`
- `assert-no-event`
- `assert-event-count`
- `boundary-call-plist`

`assert-recorded-call` checks a recorder call list for an operation, optional
arguments, and an optional result, signaling an error when no matching call is
present. `assert-recorded-call-count` asserts how many matching calls were
recorded without forcing the whole call history into an `equal` comparison.
`assert-recorded-call-sequence` asserts ordered call history and can relax the
tail with `:exact-length nil` when you only care about a prefix. Supplying `:result nil` asserts an explicit `nil` result. `boundary-call-plist` builds the same plist shape used by the built-in recorders from an explicit argument list,
which is useful when you want to compare or construct expected call records
directly in tests.
`assert-no-recorded-call` is the negative assertion: it signals when a matching
call is present, letting a test assert that an operation did not happen.
`filter-recorded-calls` and `count-recorded-calls` are the non-asserting
counterparts of `assert-recorded-call` and `assert-recorded-call-count`: they
return the matching subset or its count without signaling, and
`recorded-call-operations` returns just the `:operation` of each recorded call in
order for quick sequence checks.
`assert-recorded-call-order` asserts that a series of operations appear in call
order as a (not necessarily adjacent) subsequence, so a test can check that one
operation happened before another. `assert-recorded-operations` sits between
`assert-recorded-call-sequence` and `assert-recorded-call-order`: it asserts the
exact ordered list of operation names while ignoring arguments and results. `recorded-call-results` returns just the
`:result` of each recorded call, and `nth-recorded-call` and `last-recorded-call`
return a single recorded call by index or the most recent one.
`recorded-call-operation`, `recorded-call-arguments`, and `recorded-call-result`
pull the individual fields out of a single recorded call, so they compose with
`nth-recorded-call`/`last-recorded-call` for concise single-call assertions.
`find-event`, `count-events`, `assert-event-present`, and `assert-no-event` work
on the event lists captured by the fire-and-forget boundaries (`recording-log-events`,
`recording-metric-events`, `recording-published-messages`,
`recording-sent-notifications`): each takes a plist of key/value constraints and
matches events whose keys hold those values, so a test can assert (for example)
that a log event with `:level :error` was emitted regardless of the event shape.
`assert-event-count` mirrors `assert-recorded-call-count` for events, and
`find-recorded-call` is the single-result counterpart of `filter-recorded-calls`,
so the operation-based and event-based helper families stay symmetric.
`event-values` pulls a chosen key from every event (the event-based counterpart
of `recorded-call-operations`/`-results`), for example every log event's `:level`.

### UUID

- `make-uuid-source`
- `make-sequential-uuid-source`
- `make-test-uuid-source`
- `make-recording-uuid-source`
- `recording-uuid-source-calls`
- `reset-recording-uuid-source-calls`
- `uuid-generate`

`uuid-generate` returns a fresh identifier string from a UUID source. The
default `make-uuid-source` generator produces an RFC 4122 version-4 UUID string
from the host random state, so it is the one non-deterministic path in this
subsystem. It is not a secret-token generator; inject `:generate-fn` when UUIDs
need a cryptographic or platform-policy-specific source.
`make-sequential-uuid-source` is the deterministic double: it returns
`"<prefix>-<16 hex digits>"` for a counter that advances by one on each call, so
two sources created with the same `:prefix` and `:start` produce the same
identifier sequence.
`make-test-uuid-source` is the queue-backed fake: each `uuid-generate` call
consumes one precomputed string and signals when the queue is exhausted.
`make-recording-uuid-source` records the returned identifier while delegating to
a real or fake source (defaulting to `make-uuid-source`), exposing the same
call-record contract via `recording-uuid-source-calls`.

### Temp Path

- `make-temp-path-source`
- `make-sequential-temp-path-source`
- `make-test-temp-path-source`
- `make-recording-temp-path-source`
- `recording-temp-path-source-calls`
- `reset-recording-temp-path-source-calls`
- `temp-path-next`

The temp-path boundary models allocation of unique temporary file paths.
`temp-path-next` returns a fresh pathname. The default `make-temp-path-source`
builds a `"<prefix>-<128-bit random hex><suffix>"` name under a `:directory`
from a per-source random state and skips candidates that already exist. It
returns a candidate pathname rather than atomically creating the file, so callers
that need exclusive creation must still open the returned path with an exclusive
creation mode.
`make-sequential-temp-path-source` is the deterministic double: it numbers paths
from an advancing counter, so two sources created with the same arguments
produce the same path sequence.
`make-test-temp-path-source` is the queue-backed fake: each `temp-path-next` call
consumes one precomputed path and signals when the queue is exhausted.
`make-recording-temp-path-source` records the returned path while delegating to a
real or fake source (defaulting to `make-temp-path-source`), exposing the same
call-record contract via `recording-temp-path-source-calls`.

### Command-Line Arguments

- `make-args`
- `make-test-args`
- `make-recording-args`
- `recording-args-calls`
- `reset-recording-args-calls`
- `args-list`
- `args-count`
- `args-nth`
- `args-rest`

The command-line arguments boundary models reading the process argument vector.
`args-list` returns the arguments as a fresh list, `args-count` returns how many
there are, `args-nth` returns one by zero-based index or `nil` when out of range,
and `args-rest` returns the arguments from a zero-based index onward (useful for
dropping a leading program name). `make-args` defaults to the host process's argument vector, so it is the
path that reads the real command line, while `make-test-args` reads an explicit
`:arguments` list for deterministic tests.
`make-recording-args` records each read while delegating to another arguments
boundary, defaulting to an empty `make-test-args`, and exposes the history
through `recording-args-calls`.

### Host Info

- `make-host-info`
- `make-test-host-info`
- `make-recording-host-info`
- `recording-host-info-calls`
- `reset-recording-host-info-calls`
- `host-info-hostname`
- `host-info-username`
- `host-info-pid`

The host-info boundary models process introspection. `host-info-hostname`,
`host-info-username`, and `host-info-pid` return the host name, user name, and
process id. `make-host-info` wires those to injected collaborators, defaulting to
`machine-instance`, the `USER`/`USERNAME` environment, and the process id, so a
plain `make-host-info` reflects the running process.
`make-test-host-info` returns fixed `:hostname`, `:username`, and `:pid` values
for deterministic tests.
`make-recording-host-info` records each read while delegating to another
host-info boundary, defaulting to a `make-test-host-info`, and exposes the
history through `recording-host-info-calls`.

### Sleeper

- `make-sleeper`
- `make-test-sleeper`
- `make-recording-sleeper`
- `recording-sleeper-calls`
- `reset-recording-sleeper-calls`
- `sleeper-sleep`

`sleeper-sleep` pauses through a sleeper for a validated non-negative number of
seconds and returns that number. The default `make-sleeper` blocks the current
thread with `cl:sleep`, so it is the only path that produces a real delay.
`make-test-sleeper` is the non-blocking double: it validates and returns the
requested seconds without ever waiting, so time-dependent code stays testable
without slowing the suite down.
`make-recording-sleeper` records each requested duration while delegating to
another sleeper, defaulting to a non-blocking `make-test-sleeper` so recording
never introduces a real delay by accident. The recorded durations are available
through `recording-sleeper-calls`.

### Console

- `make-console`
- `make-test-console`
- `test-console-output`
- `test-console-errors`
- `make-recording-console`
- `recording-console-calls`
- `reset-recording-console-calls`
- `console-read-line`
- `console-write-line`
- `console-write`
- `console-write-error`
- `console-prompt`
- `console-format`
- `console-format-line`

The console boundary models terminal input and output. `console-read-line`
returns one line of input or `nil` at end of input, while `console-write-line`
and `console-write-error` emit a line to standard output or error output and
return it. The default `make-console` wraps the standard REPL streams, so it is
the path that touches the real terminal; its write operations require a string
line.
`make-test-console` seeds input from an in-memory queue of `:input-lines`,
returns `nil` once that queue is exhausted (mirroring stream end of input), and
captures writes for direct assertion through `test-console-output` and
`test-console-errors` instead of touching the terminal.
`console-write` writes text without a trailing newline (useful for prompts). Its
output is captured in `test-console-output` alongside `console-write-line`, while
the recording console keeps `:write` and `:write-line` operations distinct in its
history.
`console-prompt` writes a prompt without a newline and then reads one line of
input, returning it -- the common interactive pattern -- composing `console-write`
and `console-read-line`. `console-format` writes a `format`ted string (letting the
control string control newlines) through `console-write`, and
`console-format-line` writes a `format`ted string with a trailing newline through
`console-write-line` -- so `write`/`write-line` and `format`/`format-line` form
matching no-newline/newline pairs.
`make-recording-console` records every read, write, and error write while
delegating to another console, defaulting to a `make-test-console` so recording
never blocks on real terminal input. The interactions are available through
`recording-console-calls`.

### System

- `make-system-boundary`
- `make-test-system-boundary`
- `test-system-exit-codes`
- `make-recording-system-boundary`
- `recording-system-calls`
- `reset-recording-system-calls`
- `system-exit`

The system boundary models process termination. `system-exit` requests
termination with a validated non-negative integer exit code, defaulting to `0`.
The default `make-system-boundary` terminates the process through `uiop:quit`,
so it is the only path that actually exits.
`make-test-system-boundary` records requested exit codes and returns them
without terminating the process, so tests can assert that code asked to exit and
with which status through `test-system-exit-codes`.
`make-recording-system-boundary` records every exit request while delegating to
another system boundary, defaulting to a non-terminating
`make-test-system-boundary` so recording never exits the process by accident.
The requests are available through `recording-system-calls`.

### Key/Value Store

- `make-kv-store`
- `make-test-kv-store`
- `make-recording-kv-store`
- `recording-kv-calls`
- `reset-recording-kv-calls`
- `kv-get`
- `kv-put`
- `kv-delete`
- `kv-keys`
- `kv-update`
- `kv-clear`
- `kv-get-or-put`
- `kv-increment`

The key/value store boundary models a simple external store. `kv-get` returns a
key's value plus a present-p secondary value (so a stored `nil` is
distinguishable from a missing key), `kv-put` stores a value, `kv-delete` removes
a key and returns whether it was present, and `kv-keys` lists the current keys.
`make-kv-store` wires those operations to injected collaborator functions and
validates every one at construction time.
`make-test-kv-store` is a stateful in-memory fake seeded from an alist or plist
`:initial` value; it compares keys with `equal` and returns `kv-keys` sorted by
printed representation so test assertions stay reproducible.
`make-recording-kv-store` records every operation while delegating to another
store, defaulting to an empty `make-test-kv-store`, and exposes the history
through `recording-kv-calls`.
`kv-update` reads a key (or a default), applies a function, and stores the
result, `kv-clear` removes every key, `kv-get-or-put` returns a present value
or stores and returns a thunk's value, and `kv-increment` adds a delta (default
1) to a key's numeric value, treating an absent key as 0. All four are derived
from the protocol, so they work across the native, test, and recording stores
without extra wiring; a recording store records the underlying reads, writes, and
deletes.

### Metrics

- `make-metrics`
- `make-test-metrics`
- `make-recording-metrics`
- `recording-metric-events`
- `reset-recording-metric-events`
- `metrics-count`
- `metrics-gauge`
- `metrics-timing`
- `metrics-increment`

The metrics boundary models fire-and-forget instrumentation, mirroring the
logging boundary. `metrics-count`, `metrics-gauge`, and `metrics-timing` each
emit an event plist of the shape `(:type <type> :name <name> :value <value>)`
and return it; names must be a non-nil symbol or a string and values must be real
numbers, with timings additionally required to be non-negative.
`make-metrics` sends each event to an injected `:emit-fn`, defaulting to a no-op
sink so a plain metrics boundary drops events instead of touching a backend.
`make-test-metrics` is the sinkless double that records each emitted event and
exposes them through `recording-metric-events`.
`make-recording-metrics` records each event and forwards it to a delegate,
defaulting to a no-op `make-metrics` sink, exposing the same history through
`recording-metric-events`.
`metrics-increment` is a convenience wrapper over `metrics-count` that emits a
counter incremented by one.

### Lock

- `make-lock`
- `make-test-lock`
- `test-lock-held-p`
- `make-recording-lock`
- `recording-lock-calls`
- `reset-recording-lock-calls`
- `lock-acquire`
- `lock-release`
- `call-with-lock`

The lock boundary models mutual exclusion. `lock-acquire` and `lock-release`
each return true. `make-lock` wires those operations to injected `:acquire-fn`
and `:release-fn` collaborators, so the real path can hold any host mutex (for
example a bordeaux-threads lock) supplied at the application edge.
`make-test-lock` is a stateful in-memory double that tracks whether the lock is
held: a non-reentrant test lock signals on a second acquire before release
(surfacing a self-deadlock) and on a release while free, while a `:reentrant`
one counts acquire depth and only frees on the matching release. Inspect the
held state through `test-lock-held-p`.
`make-recording-lock` records each acquire and release while delegating to
another lock, defaulting to a non-reentrant `make-test-lock`, and exposes the
history through `recording-lock-calls`.
`call-with-lock` acquires the lock, calls a thunk, and releases the lock in an
`unwind-protect` cleanup so a non-local exit still frees it, returning the
thunk's value.

### Semaphore

- `make-semaphore`
- `make-test-semaphore`
- `make-recording-semaphore`
- `recording-semaphore-calls`
- `reset-recording-semaphore-calls`
- `semaphore-acquire`
- `semaphore-release`
- `semaphore-available`
- `call-with-semaphore`

The semaphore boundary models a counting resource permit. `semaphore-acquire`
takes a permit, `semaphore-release` returns one, and `semaphore-available`
reports the current permit count, all returning as documented. `make-semaphore`
wires those to injected collaborators for a real host semaphore.
`make-test-semaphore` is an in-memory double starting with `:permits` permits: an
acquire with none left signals rather than blocking, surfacing resource
exhaustion deterministically.
`make-recording-semaphore` records each operation while delegating to another
semaphore, defaulting to a single-permit `make-test-semaphore`, and exposes the
history through `recording-semaphore-calls`.
`call-with-semaphore` acquires a permit, calls a thunk, and releases the permit
in an `unwind-protect` cleanup so a non-local exit still returns it.

### Working Directory

- `make-working-directory`
- `make-test-working-directory`
- `make-recording-working-directory`
- `recording-working-directory-calls`
- `reset-recording-working-directory-calls`
- `working-directory-get`
- `working-directory-set`
- `call-with-working-directory`

The working-directory boundary models the current directory. `working-directory-get`
returns the current directory pathname and `working-directory-set` changes it,
coercing a string or pathname argument to a pathname. `make-working-directory`
wires those to injected `:get-fn` and `:set-fn` collaborators, defaulting to
reading and updating `*default-pathname-defaults*`, the process-wide base Common
Lisp resolves relative pathnames against.
`make-test-working-directory` is a stateful fake starting at an `:initial`
pathname; it updates and returns an in-memory directory without changing the
real process directory.
`make-recording-working-directory` records every read and change while
delegating to another working directory, defaulting to a
`make-test-working-directory`, and exposes the history through
`recording-working-directory-calls`.
`call-with-working-directory` temporarily changes the directory for the duration
of a thunk and restores the previous directory in an `unwind-protect` cleanup, so
a scoped change is always undone even on a non-local exit.

### DNS Resolver

- `make-dns-resolver`
- `make-test-dns-resolver`
- `make-recording-dns-resolver`
- `recording-dns-calls`
- `reset-recording-dns-calls`
- `dns-resolve`

The DNS resolver boundary models hostname resolution. `dns-resolve` returns the
address list for a hostname string. `make-dns-resolver` wires that to an injected
`:resolve-fn`, so the real path can call any resolver supplied at the application
edge.
`make-test-dns-resolver` is an in-memory fake seeded from a `:hosts` alist or
plist mapping each hostname to a list of address strings; it returns the mapped
addresses and signals for an unknown hostname, mirroring a resolution failure.
`make-recording-dns-resolver` records every lookup while delegating to another
resolver, defaulting to an empty `make-test-dns-resolver`, and exposes the
history through `recording-dns-calls`.

### Secret Store

- `make-secret-store`
- `make-test-secret-store`
- `make-recording-secret-store`
- `recording-secret-calls`
- `reset-recording-secret-calls`
- `secret-get`
- `secret-names`

The secret store boundary models reading credentials. `secret-get` returns a
secret's value plus a present-p secondary value (so a stored `nil` is
distinguishable from a missing secret). `make-secret-store` wires that to an
injected `:get-fn`, while `make-test-secret-store` is a stateful in-memory fake
seeded from an alist or plist `:initial` value.
`secret-names` returns the configured secret names (their keys, not their
values); the test store lists its keys sorted, while a native store without a
`:names-fn` signals `unsupported-boundary-operation`. Because names are
configuration keys rather than secret values, the recording store records them
verbatim, unlike `secret-get`'s redacted result.
`make-recording-secret-store` is deliberately different from the other recording
wrappers: it records the requested name with a `:redacted` result and omits the
default argument, so secret values never leak into a call history that tests or
logs inspect. The history is available through `recording-secret-calls`.

### Feature Flags

- `make-feature-flags`
- `make-test-feature-flags`
- `make-recording-feature-flags`
- `recording-feature-flag-calls`
- `reset-recording-feature-flag-calls`
- `feature-enabled-p`
- `feature-flags-enabled`
- `call-if-feature-enabled`

The feature-flags boundary models runtime feature toggles. `feature-enabled-p`
returns whether a named flag is on. `make-feature-flags` wires that to an
injected `:enabled-fn`, while `make-test-feature-flags` is an in-memory fake whose
`:enabled` list names the flags that are on (every other flag is off).
`make-recording-feature-flags` records each check while delegating to another
feature-flags boundary, defaulting to an all-off `make-test-feature-flags`, and
exposes the history through `recording-feature-flag-calls`.
`feature-flags-enabled` returns the currently-enabled flag names (the test double
lists its enabled set sorted, while a native boundary without an
`:enabled-list-fn` signals `unsupported-boundary-operation`), giving the
feature-flags boundary the same enumeration `environment-list` and `kv-keys`
provide.
`call-if-feature-enabled` runs a thunk when a flag is on (otherwise an optional
disabled-thunk or `nil`), expressing the common "new path when on, old path when
off" pattern -- the feature-gated counterpart of `call-if-allowed`.

### Cache

- `make-cache`
- `make-test-cache`
- `make-recording-cache`
- `recording-cache-calls`
- `reset-recording-cache-calls`
- `cache-get`
- `cache-put`
- `cache-evict`
- `cache-fetch`
- `cache-clear`

The cache boundary models a time-to-live cache. `cache-get` returns a key's
value plus a present-p secondary value, `cache-put` stores a value with an
optional `:ttl`, and `cache-evict` removes a key and returns whether it was
present. `make-cache` wires those to injected collaborators, while
`make-test-cache` is a stateful in-memory fake: entries stored with a `:ttl`
expire once its `:now-fn` passes their expiry, at which point `cache-get` treats
them as absent. Pass `(lambda () (clock-now a-clock))` as `:now-fn` to drive
expiry from a fake clock, keeping the two boundaries decoupled.
`make-recording-cache` records every operation while delegating to another cache,
defaulting to an empty `make-test-cache`, and exposes the history through
`recording-cache-calls`.
`cache-fetch` is the read-through pattern: it returns a present cached value or
computes it with a thunk, stores it with an optional `:ttl`, and returns it. It
is derived from the protocol, so it works across every cache variant.
`cache-clear` empties the cache; the test cache clears its in-memory table,
while a native cache without a `:clear-fn` signals
`unsupported-boundary-operation`.

### Rate Limiter

- `make-rate-limiter`
- `make-test-rate-limiter`
- `make-recording-rate-limiter`
- `recording-rate-limiter-calls`
- `reset-recording-rate-limiter-calls`
- `rate-limiter-allow-p`
- `rate-limiter-available`
- `call-if-allowed`

The rate limiter boundary models request throttling. `rate-limiter-allow-p`
consumes one unit of quota and returns whether it was permitted, and
`rate-limiter-available` returns the current quota count. `make-rate-limiter`
wires those to injected collaborators for a real limiter such as a shared token
bucket.
`make-test-rate-limiter` is an in-memory token bucket that starts full with
`:capacity` tokens and refills at `:refill-rate` tokens per unit of the time its
`:now-fn` returns. Pass `(lambda () (clock-now a-clock))` as `:now-fn` to drive
refill from a fake clock, keeping the two boundaries decoupled.
`make-recording-rate-limiter` records each check while delegating to another rate
limiter, defaulting to a single-token `make-test-rate-limiter`, and exposes the
history through `recording-rate-limiter-calls`.
`call-if-allowed` consumes one unit of quota and, when permitted, calls a thunk
(otherwise calls an optional throttled-thunk or returns `nil`) -- the
rate-limited-execution counterpart of the `call-with-*` helpers.

### Scheduler

- `make-scheduler`
- `make-test-scheduler`
- `test-scheduler-pending`
- `test-scheduler-run-pending`
- `make-recording-scheduler`
- `recording-scheduler-calls`
- `reset-recording-scheduler-calls`
- `scheduler-schedule`
- `scheduler-cancel`

The scheduler boundary models deferred execution. `scheduler-schedule` schedules
a thunk to run after a delay and returns a task id, and `scheduler-cancel` drops
a pending task. `make-scheduler` wires those to injected collaborators for a real
timer facility.
`make-test-scheduler` records scheduled tasks without running them: inspect the
queue with `test-scheduler-pending` (which returns `(:id <id> :delay <delay>)`
plists, omitting the thunks) and fire it deterministically with
`test-scheduler-run-pending`, so tests control exactly when deferred work runs.
`make-recording-scheduler` records each schedule and cancel while delegating to
another scheduler, defaulting to a `make-test-scheduler`; recorded `:schedule`
calls carry the delay but not the thunk, so the history stays comparable. The
history is available through `recording-scheduler-calls`.

### Publisher

- `make-publisher`
- `make-test-publisher`
- `make-recording-publisher`
- `recording-published-messages`
- `reset-recording-published-messages`
- `publisher-publish`

The publisher boundary models fire-and-forget message publishing, mirroring the
logging and metrics boundaries. `publisher-publish` emits a
`(:topic <topic> :message <message>)` event and returns it; the topic must be a
non-nil symbol or a string while the message is arbitrary.
`make-publisher` sends each event to an injected `:emit-fn`, defaulting to a
no-op sink so a plain publisher drops messages instead of touching a broker.
`make-test-publisher` is the sinkless double that records each published message
and exposes them through `recording-published-messages`.
`make-recording-publisher` records each message and forwards it to a delegate,
defaulting to a no-op `make-publisher` sink, exposing the same history through
`recording-published-messages`.

### Subscriber

- `make-subscriber`
- `make-test-subscriber`
- `make-recording-subscriber`
- `recording-subscriber-calls`
- `reset-recording-subscriber-calls`
- `subscriber-poll`
- `subscriber-poll-batch`

The subscriber boundary models consuming messages, pairing with the publisher
boundary. `subscriber-poll` returns the next message or `nil` when none is
available. `make-subscriber` wires that to an injected `:poll-fn`, while
`make-test-subscriber` is a queue-backed fake that yields its `:messages` in
order and returns `nil` once the queue is exhausted, mirroring a poll that finds
nothing waiting.
`make-recording-subscriber` records each poll while delegating to another
subscriber, defaulting to an empty `make-test-subscriber`, and exposes the
history through `recording-subscriber-calls`.
`subscriber-poll-batch` polls up to a maximum number of times, collecting
messages until a poll returns `nil` or the maximum is reached, so batch draining
always terminates even for a subscriber that keeps returning messages.

### Notifier

- `make-notifier`
- `make-test-notifier`
- `make-recording-notifier`
- `recording-sent-notifications`
- `reset-recording-sent-notifications`
- `notifier-notify`

The notifier boundary models sending notifications such as email or push
messages. `notifier-notify` emits a `(:recipient <r> :subject <s> :body <b>)`
event for string recipient, subject, and body, and returns it. `make-notifier`
sends each event to an injected `:emit-fn`, defaulting to a no-op sink so a plain
notifier drops notifications instead of touching a backend.
`make-test-notifier` is the sinkless double that records each sent notification
and exposes them through `recording-sent-notifications`.
`make-recording-notifier` records each notification and forwards it to a
delegate, defaulting to a no-op `make-notifier` sink, exposing the same history
through `recording-sent-notifications`.

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
- [`examples/application-composition.lisp`](examples/application-composition.lisp) shows a deterministic request handler composing uuid, key/value, logging, metrics, and clock boundaries through one context.
- [`examples/recording-boundary.lisp`](examples/recording-boundary.lisp) shows recording a custom boundary handler and inspecting the stored result.
- [`examples/recording-process.lisp`](examples/recording-process.lisp) shows recording process invocations with a stub delegate.
- [`examples/test-process.lisp`](examples/test-process.lisp) shows queue-backed process results for deterministic tests.
- [`examples/recording-network.lisp`](examples/recording-network.lisp) shows recording network requests, including timeout propagation, with a stub transport.
- [`examples/test-network.lisp`](examples/test-network.lisp) shows queue-backed network responses for deterministic tests.
- [`examples/recording-logger.lisp`](examples/recording-logger.lisp) shows that recorded and forwarded log events are equal but independent snapshots.
- [`examples/test-logger.lisp`](examples/test-logger.lisp) shows a sinkless logger fake whose emitted events stay inspectable through independent snapshots.
- [`examples/sequential-uuid.lisp`](examples/sequential-uuid.lisp) shows a deterministic counter-backed UUID source producing a reproducible identifier sequence.
- [`examples/recording-uuid.lisp`](examples/recording-uuid.lisp) shows recording generated identifiers around a queue-backed UUID source.
- [`examples/sequential-temp-path.lisp`](examples/sequential-temp-path.lisp) shows a deterministic counter-backed temp-path source producing a reproducible path sequence.
- [`examples/test-args.lisp`](examples/test-args.lisp) shows a command-line arguments fake reading an explicit list instead of the real process argv.
- [`examples/test-host-info.lisp`](examples/test-host-info.lisp) shows a host-info fake returning fixed hostname, username, and pid values.
- [`examples/recording-sleeper.lisp`](examples/recording-sleeper.lisp) shows recording requested sleep durations without introducing a real delay.
- [`examples/test-console.lisp`](examples/test-console.lisp) shows a queue-backed console fake that captures written output for direct assertion.
- [`examples/test-system.lisp`](examples/test-system.lisp) shows a system boundary that records requested exit codes instead of terminating the process.
- [`examples/test-kv-store.lisp`](examples/test-kv-store.lisp) shows a stateful in-memory key/value store fake with presence-aware reads and sorted keys.
- [`examples/test-metrics.lisp`](examples/test-metrics.lisp) shows a sinkless metrics fake whose emitted counter, gauge, and timing events stay inspectable.
- [`examples/recording-lock.lisp`](examples/recording-lock.lisp) shows recording acquire and release calls around a state-tracking lock fake.
- [`examples/test-semaphore.lisp`](examples/test-semaphore.lisp) shows a counting semaphore fake tracking available permits across acquire and release.
- [`examples/test-working-directory.lisp`](examples/test-working-directory.lisp) shows a stateful working-directory fake that changes an in-memory directory without touching the process.
- [`examples/test-dns.lisp`](examples/test-dns.lisp) shows an in-memory DNS resolver fake with mapped addresses and resolution-failure signaling.
- [`examples/recording-secret.lisp`](examples/recording-secret.lisp) shows a recording secret store that redacts secret values in its call history.
- [`examples/test-feature-flags.lisp`](examples/test-feature-flags.lisp) shows an in-memory feature-flags fake with a fixed set of enabled flags.
- [`examples/test-cache.lisp`](examples/test-cache.lisp) shows an in-memory cache whose time-to-live entries expire as a fake clock advances.
- [`examples/test-rate-limiter.lisp`](examples/test-rate-limiter.lisp) shows a token-bucket rate limiter that throttles then refills as a fake clock advances.
- [`examples/test-scheduler.lisp`](examples/test-scheduler.lisp) shows a scheduler fake that records deferred tasks and runs them on demand.
- [`examples/test-publisher.lisp`](examples/test-publisher.lisp) shows a sinkless publisher fake whose published topic/message events stay inspectable.
- [`examples/test-subscriber.lisp`](examples/test-subscriber.lisp) shows a queue-backed subscriber fake that yields messages then returns nil when drained.
- [`examples/test-notifier.lisp`](examples/test-notifier.lisp) shows a sinkless notifier fake whose sent notifications stay inspectable.

## Repository Layout

- `src/` core library implementation
- `t/` test runner and subsystem tests
- `examples/` REPL-friendly usage snippets
- `cl-boundary-kit.asd` ASDF system definitions
- `run-tests.lisp` canonical checkout test runner
- `flake.nix` pinned Nix build, test, report, and coverage entrypoints
- `nix/` CI runner and coverage threshold tooling
- `docs/` MkDocs (Material) source for the published documentation site
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

The recommended pinned checkout test command is:

```sh
nix run .#test
```

The flake pins SBCL, `cl-prolog`, `cl-weave`, `cl-log-kit`, `cl-process-kit`,
and `cl-json-kit`, so this path does not require Quicklisp or separately
installed Common Lisp dependencies. `cl-weave` provides the test runner,
machine-readable reporting, and coverage integration. `cl-prolog` is used by
the test system to express and verify cross-boundary invariants; `cl-log-kit`,
`cl-process-kit`, and `cl-json-kit` back the optional adapters exercised by
the test suite. These runnable flake apps and checks are emitted for
`x86_64-linux` and `aarch64-darwin`; the Ubuntu GitHub Actions workflow is the
canonical Linux CI path.

On a supported Nix host, run `nix flake check --print-build-logs` to execute
the flake checks for that host, including the checkout runner,
machine-readable report generation, and the coverage threshold. The CI
workflow additionally builds the `machine-report` and `coverage` checks as
artifacts. They contain `report.json`, and, for the coverage check,
`coverage.dat`, `coverage-summary.txt`, and the `coverage-html/` report. The
coverage check currently requires at least 80% statement coverage. Hosts outside
the emitted flake systems are not a compatibility claim; use
`sbcl --script run-tests.lisp` there when `cl-prolog`, `cl-weave`,
`cl-log-kit`, `cl-process-kit`, and `cl-json-kit` are already discoverable by
ASDF.

For local development on any host with an existing SBCL environment, run
`sbcl --script run-tests.lisp`. Quicklisp itself is not required, but direct
SBCL and REPL use requires `cl-prolog`, `cl-weave`, `cl-log-kit`,
`cl-process-kit`, and `cl-json-kit` to be discoverable by ASDF. The suite
exercises
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
  surface for `0.6.x`.
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
