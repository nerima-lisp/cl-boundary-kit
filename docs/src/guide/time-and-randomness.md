# Time and Randomness

## Clock

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

See [`examples/fake-clock.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/fake-clock.lisp).

## Random

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

See [`examples/deterministic-random.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/deterministic-random.lisp)
and [`examples/test-random.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-random.lisp).

## Sleeper

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

See [`examples/recording-sleeper.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-sleeper.lisp).

## UUID

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

See [`examples/sequential-uuid.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/sequential-uuid.lisp)
and [`examples/recording-uuid.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-uuid.lisp).

## Temp Path

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

See [`examples/sequential-temp-path.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/sequential-temp-path.lisp).
