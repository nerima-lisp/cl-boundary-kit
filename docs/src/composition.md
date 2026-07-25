# Composition and Context

## Composition

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

See [`examples/boundary-composition.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/boundary-composition.lisp),
[`examples/application-composition.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/application-composition.lisp),
and [`examples/recording-boundary.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-boundary.lisp)
for end-to-end usage.

## Conditions

- `unsupported-boundary-operation`
- `unsupported-boundary-operation-operation`
- `unsupported-boundary-operation-detail`

Boundaries use `unsupported-boundary-operation` when a capability is
intentionally unavailable instead of silently emulating behavior. The reader
functions expose the failed operation and its detail so callers and tests can
branch on explicit unsupported cases.

See [`examples/unsupported-operation.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/unsupported-operation.lisp)
for handling this condition explicitly, and
[Boundary Context](core-concepts.md#boundary-context) for how contexts bundle
boundaries together at the application edge.
