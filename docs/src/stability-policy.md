# Stability Policy

The public contract is intentionally narrow:

- The exported symbols listed across the [Guide](composition.md) pages define
  the supported library surface for `0.5.x`.
- The checked-in README snippets, `examples/*.lisp`, and the
  `asdf:load-system :cl-boundary-kit/test` plus `cl-boundary-kit/test:run-tests`
  flow are treated as regression-checked usage contracts, not illustrative
  pseudocode.
- [Cookbook](cookbook.md), [FAQ](faq.md), [Architecture](architecture.md),
  [Compatibility](compatibility.md), and [Release Process](release-process.md)
  are also part of the executable documentation contract when their guidance
  is backed by repository-level tests.
  - Breaking behavioral changes must be reflected in `README.md`,
    `COMPATIBILITY.md`, `CHANGELOG.md`, and the executable documentation tests
    in `t/api-test.lisp`, `t/api-doc-claims-test.lisp`,
    `t/api-doc-links-test.lisp`, `t/api-doc-links-documents-test.lisp`,
    `t/api-executable-docs-test.lisp`, and `t/examples-test.lisp`.
- Deprecations and removals must be called out explicitly in
  [Changelog](changelog.md), and when a supported replacement exists they
  should include concrete migration guidance instead of leaving consumers to
  infer the next step.
- Unsupported operations should keep failing explicitly; convenience fallbacks
  that hide host differences are out of scope for this library.

The project is still early-stage software, so additions may happen in `0.x`,
but any intentionally breaking change should be called out in the changelog and
should come with updated compatibility notes and migration guidance when a
replacement path exists.

See [Design Non-Goals](design-notes.md) for what the library deliberately
does not try to become, and [Roadmap](roadmap.md) for directional,
non-committed work that has not yet shipped.
