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
3. `src/core.lisp` provides shared boundary composition and recording helpers.
4. `src/testing.lisp` provides assertion helpers for inspecting recorded calls.
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
- `src/filesystem-*.lisp`, `src/env-classes.lisp`, `src/clock.lisp`,
  `src/random.lisp`, `src/process*.lisp`, `src/network-*.lisp`, and
  `src/logging.lisp` implement subsystem-specific boundaries
- `src/core.lisp` holds cross-cutting composition and generic recording utilities
- `src/testing.lisp` exposes lightweight test assertions
- `t/api-test.lisp`, `t/api-doc-claims-test.lisp`, `t/api-doc-links-test.lisp`,
  `t/api-doc-links-documents-test.lisp`, `t/api-executable-docs-test.lisp`, and
  `t/examples-test.lisp` protect documentation and example contracts

Changes that move responsibilities across these layers should update this
document, `README.md`, and the executable tests in the same change.

## Change Constraints

Architecture changes should be argued from:

- a concrete boundary use case
- an executable regression test
- the public contract documents in `README.md`, `COMPATIBILITY.md`, and `GOVERNANCE.md`

Broad framework concerns, hidden host fallbacks, and scope growth without a
boundary-specific justification are out of scope.
