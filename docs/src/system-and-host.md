# System and Host

## Command-Line Arguments

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

See [`examples/test-args.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-args.lisp).

## Host Info

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

See [`examples/test-host-info.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-host-info.lisp).

## System

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

See [`examples/test-system.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-system.lisp).
