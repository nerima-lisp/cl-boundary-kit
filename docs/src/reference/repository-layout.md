# Repository Layout

The repository root holds only the files that GitHub, ASDF, and the release
tooling read directly. Every other document lives under `docs/src/` and is
published as part of this site, so there is exactly one copy of each to keep
current.

## Root

- `src/` core library implementation
- `t/` test runner and subsystem tests
- `examples/` REPL-friendly usage snippets
- `cl-boundary-kit.asd` ASDF system definitions
- `run-tests.lisp` canonical checkout test runner
- `flake.nix` pinned Nix build, test, report, and coverage entrypoints
- `nix/` CI runner and coverage threshold tooling
- `docs/` MkDocs (Material) source for this documentation site
- `README.md` landing page and quick start
- `LICENSE` MIT license terms

There is no `CHANGELOG.md`. Release history is the GitHub Release description,
which is the org's only canonical changelog.

## Documentation

Community health documents (contributing, conduct, governance, support, and
security reporting) are also served org-wide from
[nerima-lisp/.github](https://github.com/nerima-lisp/.github); the pages here
record the parts specific to this repository.

- [`cookbook.md`](../guide/cookbook.md) pattern-oriented usage guide for supported flows
- [`faq.md`](../guide/faq.md) user-facing decision points and contract clarifications
- [`architecture.md`](architecture.md) layering model and design constraints
- [`compatibility.md`](compatibility.md) checked verification workflows
- [`contributing.md`](../project/contributing.md) change workflow and test expectations
- [`governance.md`](../project/governance.md) maintainer decision model and contract surface
- [`code-of-conduct.md`](../project/code-of-conduct.md) contributor behavior and reporting expectations
- [`support.md`](../project/support.md) request routing and maintenance boundary
- [`release-process.md`](../project/release-process.md) maintainer release checklist and evidence requirements
- [`roadmap.md`](../project/roadmap.md) deferred work and non-goals
- [`security.md`](../project/security.md) security reporting guidance
