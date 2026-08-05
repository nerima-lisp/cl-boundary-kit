# Documentation Scope

The public contract is intentionally narrow. The current supported release
series is `2.2.x`:

- The exported symbols listed across the [Guide](../guide/composition.md) pages define
  the current library surface.
- The checked-in README snippets, `examples/*.lisp`, and the
  `asdf:load-system :cl-boundary-kit/test` plus `cl-boundary-kit/test:run-tests`
  flow are treated as regression-checked usage contracts, not illustrative
  pseudocode.
- [Cookbook](../guide/cookbook.md), [FAQ](../guide/faq.md), [Architecture](architecture.md), and
  [Release Process](../project/release-process.md) are executable documentation when their
  guidance is backed by repository-level tests.
- Unsupported operations should keep failing explicitly; convenience fallbacks
  that hide host differences are out of scope for this library.

Internal helpers, `%`-prefixed functions, class precedence details, slot names,
and exact error text are implementation details rather than documented API.

See [Design Non-Goals](../guide/design-notes.md) for what the library deliberately
does not try to become, and [Roadmap](../project/roadmap.md) for directional,
non-committed work that has not yet shipped.
