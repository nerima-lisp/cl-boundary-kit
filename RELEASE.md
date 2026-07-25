# Release Process

`cl-boundary-kit` should only make compatibility claims that can be backed by
the checked-in verification in this repository. A release is therefore a
documentation and evidence exercise, not just a version bump.

## Release Checklist

1. Confirm the intended scope still fits [`GOVERNANCE.md`](GOVERNANCE.md) and
   the non-goals in `README.md`.
2. Update `CHANGELOG.md` so the release notes describe every intentional public
   change, explicitly call out deprecations or removals, include migration
   guidance when a supported replacement exists, and remove any stale
   `Unreleased` placeholders.
3. Reconcile `ROADMAP.md` with the release scope so shipped items are removed,
   narrowed, or rewritten as future work instead of being left as if they were
   still merely planned.
4. Update `README.md`, [`COOKBOOK.md`](COOKBOOK.md),
   [`COMPATIBILITY.md`](COMPATIBILITY.md), and `examples/*.lisp` for any public
   contract change.
5. Run `sbcl --script run-tests.lisp` from a clean checkout state and confirm
   the executable documentation still matches reality.
6. If the public contract changed, verify that `t/api-test.lisp`,
   `t/api-doc-claims-test.lisp`, `t/api-doc-links-test.lisp`,
   `t/api-doc-links-documents-test.lisp`, `t/api-executable-docs-test.lisp`,
   and `t/examples-test.lisp` cover the new or changed behavior.
7. For security-relevant fixes, make sure `SECURITY.md` reporting and disclosure
   expectations still match the release notes and do not force sensitive details
   into public issue history.
8. Cut the release only after the repository state, roadmap, and release notes
   agree.
9. Tag the release commit on `main` with an annotated `v<version>` tag whose
   version matches `cl-boundary-kit.asd` `:version`, then push the tag:

   ```sh
   git tag -a v0.6.0 -m "cl-boundary-kit 0.6.0"
   git push origin v0.6.0
   ```

   Pushing a `v[0-9]+.[0-9]+.[0-9]+` tag triggers
   [`.github/workflows/release.yml`](.github/workflows/release.yml), which
   verifies the tag matches the ASDF `:version`, extracts the matching
   `CHANGELOG.md` section as release notes, and publishes a GitHub Release. Push
   the tag only from a commit whose CI run is green.

## Versioning Expectations

- `0.6.x` should keep the documented exported API stable unless a breaking
  change is explicitly called out.
- Intentionally breaking changes must update `CHANGELOG.md` and
  [`COMPATIBILITY.md`](COMPATIBILITY.md) in the same change.
- Deprecations and removals should never appear as silent release-note drift:
  they belong in `CHANGELOG.md` with replacement or migration guidance when
  the project has a supported next step to recommend.
- New helpers should not be described as supported unless they are exercised by
  repository-level verification.

## Evidence Required Before Claiming Compatibility

Compatibility statements should be tied to what the repository actually proves:

- the checkout installation flow
- the documented REPL test-runner path
- the checked-in examples
- cookbook snippets and documentation contracts

If a claim is not backed by that evidence, it should stay out of release notes.

`CHANGELOG.md` is for shipped history and concrete unreleased public changes.
`ROADMAP.md` is for deferred direction and non-commitment planning. Releases
should keep shipped facts from deferred intent and preserve those distinct
roles.
