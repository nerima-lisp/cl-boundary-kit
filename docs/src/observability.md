# Logging, Metrics, and Console

## Logging

- `make-logger`
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

For structured logging, call the application's logging system directly from
the application boundary. `cl-boundary-kit` does not translate external event
formats or log levels.


See [`examples/recording-logger.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-logger.lisp)
and [`examples/test-logger.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-logger.lisp).

## Metrics

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

See [`examples/test-metrics.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-metrics.lisp).
Pair `metrics-timing` with `call-with-elapsed` (see [Time and Randomness](time-and-randomness.md#clock))
for deterministic timing assertions under a fake clock.

## Console

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

See [`examples/test-console.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-console.lisp).
