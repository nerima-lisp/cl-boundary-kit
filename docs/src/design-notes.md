# Design Non-Goals

- CLI framework
- app-specific adapters
- full dependency injection container
- full mocking framework
- generic utility package
- domain logic

## Implementation Notes

- The public API is intentionally small and explicit.
- Recording variants are provided for test assertions without a separate
  mocking framework.
- `examples/` contains REPL-friendly snippets rather than a full tutorial.
- `cl-boundary-kit/test` is the canonical test entrypoint for both
  `run-tests.lisp` and REPL use.

See [Stability Policy](stability-policy.md) for how these constraints tie
into the public contract, and [Roadmap](roadmap.md) for the corresponding
directional non-goals.
