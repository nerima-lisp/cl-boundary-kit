# Concurrency Control

## Lock

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

See [`examples/recording-lock.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-lock.lisp).

## Semaphore

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

See [`examples/test-semaphore.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-semaphore.lisp).

## Rate Limiter

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

See [`examples/test-rate-limiter.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-rate-limiter.lisp),
which shows a token-bucket rate limiter that throttles then refills as a fake
clock advances.

## Scheduler

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

See [`examples/test-scheduler.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-scheduler.lisp).
