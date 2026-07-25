# Stability Policy

The public contract is intentionally narrow:

- The exported symbols listed across the [Guide](composition.md) pages define
  the supported library surface for `1.0.x`.
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

## Versioning

From `1.0.0` on, the surface above is a semantic-versioning contract rather
than a best-effort intention:

- **Patch** (`1.0.x`) releases fix behavior that already contradicted the
  documented contract. They do not change it.
- **Minor** (`1.x.0`) releases may add exported symbols, protocols, or keyword
  arguments with defaults that preserve existing call sites. Code written
  against an earlier `1.x` keeps working.
- **Major** releases are the only place a documented export may be removed,
  renamed, or given behavior that breaks an existing caller.

Removing something is a two-step process, never a single release: it is
deprecated first in [Changelog](changelog.md) with concrete migration guidance
while it keeps working, and only removed in a later major release.

Anything not listed as an exported symbol on the Guide pages -- internal
helpers, `%`-prefixed functions, class precedence details, slot names, and the
exact text of error messages -- is not covered by this contract and may change
in any release.

See [Design Non-Goals](design-notes.md) for what the library deliberately
does not try to become, and [Roadmap](roadmap.md) for directional,
non-committed work that has not yet shipped.
