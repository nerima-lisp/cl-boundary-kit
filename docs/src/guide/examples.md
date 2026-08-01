# Examples

Each documented example is directly runnable with `sbcl --script examples/<name>.lisp`
from a checkout; the files self-bootstrap the `cl-boundary-kit` system before
executing their snippet body.

- [`examples/fake-clock.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/fake-clock.lisp) shows deterministic time control.
- [`examples/deterministic-random.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/deterministic-random.lisp) shows reproducible random sequences from a fixed seed.
- [`examples/test-random.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-random.lisp) shows a queue-backed random source for deterministic tests.
- [`examples/recording-filesystem.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-filesystem.lisp) shows write-option propagation and call recording around filesystem access.
- [`examples/test-filesystem.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-filesystem.lisp) shows a stateful in-memory filesystem fake with readable call history.
- [`examples/recording-environment.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-environment.lisp) shows a recording environment with explicit test values.
- [`examples/test-environment.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-environment.lisp) shows a stateful environment fake with explicit `nil`, presence checks, mutation, and readable call history.
- [`examples/unsupported-operation.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/unsupported-operation.lisp) shows how to handle an unsupported boundary operation explicitly.
- [`examples/boundary-composition.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/boundary-composition.lisp) shows bundling multiple boundaries into a context.
- [`examples/application-composition.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/application-composition.lisp) shows a deterministic request handler composing uuid, key/value, logging, metrics, and clock boundaries through one context.
- [`examples/recording-boundary.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-boundary.lisp) shows recording a custom boundary handler and inspecting the stored result.
- [`examples/recording-process.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-process.lisp) shows recording process invocations with a stub delegate.
- [`examples/test-process.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-process.lisp) shows queue-backed process results for deterministic tests.
- [`examples/recording-network.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-network.lisp) shows recording network requests, including timeout propagation, with a stub transport.
- [`examples/test-network.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-network.lisp) shows queue-backed network responses for deterministic tests.
- [`examples/recording-logger.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-logger.lisp) shows that recorded and forwarded log events are equal but independent snapshots.
- [`examples/test-logger.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-logger.lisp) shows a sinkless logger fake whose emitted events stay inspectable through independent snapshots.
- [`examples/sequential-uuid.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/sequential-uuid.lisp) shows a deterministic counter-backed UUID source producing a reproducible identifier sequence.
- [`examples/recording-uuid.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-uuid.lisp) shows recording generated identifiers around a queue-backed UUID source.
- [`examples/sequential-temp-path.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/sequential-temp-path.lisp) shows a deterministic counter-backed temp-path source producing a reproducible path sequence.
- [`examples/test-args.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-args.lisp) shows a command-line arguments fake reading an explicit list instead of the real process argv.
- [`examples/test-host-info.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-host-info.lisp) shows a host-info fake returning fixed hostname, username, and pid values.
- [`examples/recording-sleeper.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-sleeper.lisp) shows recording requested sleep durations without introducing a real delay.
- [`examples/test-console.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-console.lisp) shows a queue-backed console fake that captures written output for direct assertion.
- [`examples/test-system.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-system.lisp) shows a system boundary that records requested exit codes instead of terminating the process.
- [`examples/test-kv-store.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-kv-store.lisp) shows a stateful in-memory key/value store fake with presence-aware reads and sorted keys.
- [`examples/test-metrics.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-metrics.lisp) shows a sinkless metrics fake whose emitted counter, gauge, and timing events stay inspectable.
- [`examples/recording-lock.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-lock.lisp) shows recording acquire and release calls around a state-tracking lock fake.
- [`examples/test-semaphore.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-semaphore.lisp) shows a counting semaphore fake tracking available permits across acquire and release.
- [`examples/test-working-directory.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-working-directory.lisp) shows a stateful working-directory fake that changes an in-memory directory without touching the process.
- [`examples/test-dns.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-dns.lisp) shows an in-memory DNS resolver fake with mapped addresses and resolution-failure signaling.
- [`examples/recording-secret.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/recording-secret.lisp) shows a recording secret store that redacts secret values in its call history.
- [`examples/test-feature-flags.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-feature-flags.lisp) shows an in-memory feature-flags fake with a fixed set of enabled flags.
- [`examples/test-cache.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-cache.lisp) shows an in-memory cache whose time-to-live entries expire as a fake clock advances.
- [`examples/test-rate-limiter.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-rate-limiter.lisp) shows a token-bucket rate limiter that throttles then refills as a fake clock advances.
- [`examples/test-scheduler.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-scheduler.lisp) shows a scheduler fake that records deferred tasks and runs them on demand.
- [`examples/test-publisher.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-publisher.lisp) shows a sinkless publisher fake whose published topic/message events stay inspectable.
- [`examples/test-subscriber.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-subscriber.lisp) shows a queue-backed subscriber fake that yields messages then returns nil when drained.
- [`examples/test-notifier.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-notifier.lisp) shows a sinkless notifier fake whose sent notifications stay inspectable.

For pattern-oriented walkthroughs that combine several of these building
blocks, see the [Cookbook](cookbook.md).
