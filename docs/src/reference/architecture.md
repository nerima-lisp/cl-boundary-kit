# Architecture

`cl-boundary-kit` is intentionally small. The architecture exists to keep
external effects explicit, testable, and easy to replace without pulling the
library toward framework-like abstraction growth.

## Design Goals

- model host interaction behind explicit boundary protocols
- keep constructors small and validate collaborators up front
- ship test doubles as first-class library features
- prefer deterministic examples and executable documentation over prose-only claims

## Layering Model

The repository is organized around a narrow layering model:

1. `src/protocols.lisp` defines the generic functions that describe each boundary.
2. `src/*.lisp` implementation files provide concrete constructors, fakes, and recording wrappers.
3. `src/core.lisp`, `src/core-utilities.lisp`, and `src/recording-boundary.lisp`
   provide shared boundary composition and recording helpers.
4. `src/testing.lisp` and its `src/testing-*.lisp` companions provide assertion
   and query helpers for inspecting recorded calls and events.
5. `examples/*.lisp` and `t/*.lisp` act as executable design evidence for the supported usage flows.

Application code is expected to depend on the protocol and constructor surface,
then wire concrete boundaries at the outer edge of the application.

## Boundary Principles

The library keeps a few constraints stable across subsystems:

- unsupported operations fail explicitly with `unsupported-boundary-operation`
- fake and recording implementations preserve observable arguments and results
- deterministic testing is preferred over hidden host fallback behavior
- context composition uses explicit keyword bindings instead of implicit lookup

These principles matter more than adding new convenience wrappers.

## Macro Consolidation

Repeated shapes are pushed into `defmacro` in `src/core-utilities.lisp` rather
than hand-copied per subsystem: `define-scalar-validator` and
`define-list-validator` generate the `%validate-*` guard functions every
constructor calls before wiring a boundary together, and
`define-emit-event-boundary-dispatch` generates the class triple (`CLASS`,
`TEST-<CLASS>`, `RECORDING-<CLASS>`) plus dispatch methods for the
emit-event-shaped boundaries (metrics, notifier, publisher). A validator or
emit-event boundary should reach for the existing macro before writing a new
hand-rolled guard or defclass triple; only a validator whose return value
isn't its own input, or whose element check isn't a bare predicate, has
outgrown what the macros model and needs its own hand-written function.

## CPS Convention

Continuation-passing style is used where a boundary's own logic already
threads a producer through a shared normalization or dispatch step, not
applied uniformly across the codebase. The canonical example is
`%normalize-pairs-cps` in `src/filesystem-fakes-normalize.lisp`, which turns a
null/alist/plist input into `(key . value)` pairs and hands them to a
`continuation` function; `src/dns.lisp`, `src/kv.lisp`, `src/cache.lisp`,
`src/secret.lisp`, and `src/env-helpers.lisp` all normalize their initial
bindings through it (some via a thin direct-style, `#'identity`-continuation
wrapper where a caller genuinely only wants the immediate value back).
`%run-native-process/cps` in `src/process-exec-helpers.lisp` is the other
real user, threading a continuation through the deadline-sharing timeout path
of the native process runner. CPS is not used for simple two-step read/write
or loop-shaped logic (for example `cache-fetch`, `kv-get-or-put`, or the
filesystem copy loop) where a continuation parameter would add ceremony
without a real producer/consumer relationship to thread through -- forcing it
there would work against the "human readable" and "avoid convenience
wrappers" principles above.

## File Responsibilities

- `src/package.lisp` exports the supported public API
- `src/protocols.lisp` defines the protocol contract
- the subsystem implementation files under `src/` (for example
  `src/filesystem-*.lisp`, `src/env-classes.lisp`, `src/clock.lisp`,
  `src/random.lisp`, `src/uuid.lisp`, `src/temp-path.lisp`, `src/args.lisp`,
  `src/host-info.lisp`, `src/sleeper.lisp`, `src/console.lisp`, `src/system.lisp`,
  `src/kv.lisp`, `src/cache.lisp`, `src/secret.lisp`, `src/feature-flags.lisp`,
  `src/lock.lisp`, `src/semaphore.lisp`, `src/rate-limiter.lisp`,
  `src/scheduler.lisp`, `src/working-directory.lisp`, `src/dns.lisp`,
  `src/process*.lisp`, `src/network-*.lisp`, `src/logging.lisp`,
  `src/metrics.lisp`, `src/publisher.lisp`, `src/subscriber.lisp`, and
  `src/notifier.lisp`) each implement a subsystem-specific boundary; a
  subsystem whose implementation file grows past a focused size splits into
  that primary file plus a companion `-helpers`/`-methods` file (for example
  `src/env-helpers.lisp`, `src/console-methods.lisp`)
- `src/core.lisp` provides shared boundary-context composition;
  `src/core-utilities.lisp` and `src/recording-boundary.lisp` hold the generic
  call-recording utilities and delegate-method macros every subsystem
  boundary builds on
- `src/testing.lisp`, `src/testing-helpers.lisp`, `src/testing-queries.lisp`,
  and `src/testing-events.lisp` expose lightweight test assertions and
  recorded-call/event query helpers
- `t/api-test.lisp`, the `t/api-doc-*-test.lisp` and
  `t/api-executable-docs-*-test.lisp` split suites, and `t/examples-test.lisp`
  protect documentation and example contracts

Changes that move responsibilities across these layers should update this
document, `README.md`, and the executable tests in the same change.

## Change Constraints

Architecture changes should be argued from:

- a concrete boundary use case
- an executable regression test
- the public contract documents in the [Guide](../guide/composition.md) pages,
  [Verification](compatibility.md), and [Governance](../project/governance.md)

Broad framework concerns, hidden host fallbacks, and scope growth without a
boundary-specific justification are out of scope.

See [Repository Layout](repository-layout.md) for the top-level checkout
structure this layering model produces.
