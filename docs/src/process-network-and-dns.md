# Process, Network, and DNS

## Process

- `make-process-boundary`
- `process-kit-run-fn`
- `make-test-process-boundary`
- `process-boundary-run`
- `process-result-success-p`
- `process-result-check`
- `*native-process-search-path-p*`
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

See [`examples/recording-process.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-process.lisp)
and [`examples/test-process.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-process.lisp).

## Network

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
function-valued redactors when they are supplied. Like `make-environment`
without a `:set-fn`, a network boundary constructed without a `:request-fn`
signals `unsupported-boundary-operation` instead of silently pretending to
support requests — see [Conditions](composition.md#conditions).

See [`examples/recording-network.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-network.lisp)
and [`examples/test-network.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-network.lisp).

## DNS Resolver

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

See [`examples/test-dns.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-dns.lisp).

## JSON

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
