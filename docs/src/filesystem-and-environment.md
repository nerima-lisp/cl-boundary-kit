# Filesystem and Environment

## Filesystem

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

See [`examples/recording-filesystem.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-filesystem.lisp)
and [`examples/test-filesystem.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-filesystem.lisp).

## Environment

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
either `nil` or a function. `:set-fn` and `:unset-fn` default to real
`cl-host-kit`-backed mutation of the process environment, so a plain
`make-environment` both reads and writes the real host environment; pass
`:set-fn nil` and/or `:unset-fn nil` explicitly to opt a native environment
out of mutation.
Recording environments also require an `environment` delegate.
`environment-unset` removes a variable and returns whether it was bound; the
state-backed test environment drops it from its in-memory bindings, while a
native environment constructed with an explicit `:unset-fn nil` signals
`unsupported-boundary-operation`, just like `environment-set` on one
constructed with an explicit `:set-fn nil`.
`call-with-environment-variable` temporarily binds a variable for the duration of
a thunk and restores its previous value (or unsets it when it was absent) in an
`unwind-protect` cleanup, so a scoped override is always undone even on a
non-local exit.

See [`examples/recording-environment.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-environment.lisp)
and [`examples/test-environment.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-environment.lisp).

## Working Directory

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

See [`examples/test-working-directory.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-working-directory.lisp).
