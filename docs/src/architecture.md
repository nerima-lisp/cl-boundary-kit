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
- `src/logging-kit-adapter.lisp`, `src/process-kit-adapter.lisp` (loaded via
  the separate `cl-boundary-kit/process-kit` system), and `src/json-adapter.lisp`
  (loaded via the separate `cl-boundary-kit/json` system) bridge to sibling
  nerima-lisp libraries without pulling their dependencies into every consumer
- `src/testing.lisp`, `src/testing-helpers.lisp`, `src/testing-queries.lisp`,
  and `src/testing-events.lisp` expose lightweight test assertions and
  recorded-call/event query helpers
- `t/api-test.lisp`, `t/api-doc-claims-test.lisp`, `t/api-doc-links-test.lisp`,
  `t/api-doc-links-documents-test.lisp`, `t/api-executable-docs-test.lisp`, and
  `t/examples-test.lisp` protect documentation and example contracts

Changes that move responsibilities across these layers should update this
document, `README.md`, and the executable tests in the same change.

## Change Constraints

Architecture changes should be argued from:

- a concrete boundary use case
- an executable regression test
- the public contract documents in the [Guide](composition.md) pages,
  [Compatibility](compatibility.md), and [Governance](governance.md)

Broad framework concerns, hidden host fallbacks, and scope growth without a
boundary-specific justification are out of scope.

See [Repository Layout](repository-layout.md) for the top-level checkout
structure this layering model produces.
