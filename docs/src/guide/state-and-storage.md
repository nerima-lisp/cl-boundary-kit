# State and Storage

## Key/Value Store

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

See [`examples/test-kv-store.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-kv-store.lisp).

## Cache

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

See [`examples/test-cache.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-cache.lisp),
which shows time-to-live entries expiring as a fake clock advances.

## Secret Store

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

See [`examples/recording-secret.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-secret.lisp),
which shows a recording secret store that redacts secret values in its call
history.

## Feature Flags

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

See [`examples/test-feature-flags.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-feature-flags.lisp).
