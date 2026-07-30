# Contributing

`cl-boundary-kit` is intentionally small. Changes should keep the API explicit
and the dependency surface minimal.

Changes to documented public behavior should update the executable tests,
relevant examples, and `README.md` in the same change.

## Workflow

1. Make a focused change.
2. Update or add tests for any behavior change.
3. Run the ASDF test suite.
4. Keep the README and examples aligned with the exported API.
5. Follow [Code of Conduct](code-of-conduct.md) in review and discussion.

## Local Setup

On a supported Nix host, the reproducible setup is provided by the Nix flake.
Run the test app without installing Quicklisp or the test dependencies separately:

```sh
nix run .#test
```

The runnable flake app and check set are emitted for `x86_64-linux` and
`aarch64-darwin`; Ubuntu CI is the canonical Linux verification path. Before
submitting a change from a supported Nix host, run the complete check set:

```sh
nix flake check --print-build-logs
```

This runs the canonical checkout test runner, the `cl-weave` machine-report
check, and the coverage check. The latter enforces 100% expression
coverage. CI preserves `report.json`, `coverage.dat`, `coverage-summary.txt`,
and `coverage-html/` from the report and coverage derivations as build
artifacts. The runner limits each test to 30 seconds; Nix checks have a
300-second outer limit and force termination after a further 30-second grace
period. On hosts outside the emitted flake systems, use direct SBCL execution
and rely on Ubuntu CI for the canonical Linux verification.

To load the library itself with ASDF from a local checkout:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit)
```

Direct SBCL test execution is also available when the test dependencies are
discoverable by ASDF:

```sh
sbcl --script run-tests.lisp
```

If you prefer a REPL, register the checkout, load the test system, and invoke
the same runner explicitly. The test dependencies must also be present in the
ASDF source registry:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit/test)
(cl-boundary-kit/test:run-tests)
```

The documented REPL runner is `(asdf:load-system :cl-boundary-kit/test)`
followed by `(cl-boundary-kit/test:run-tests)`. A passing run reaches successful
completion with `0 failures`, which is the stable verification path to confirm
before submitting a change.

## Change Guidelines

- Prefer small protocol additions over broad abstractions.
- Keep recording/fake variants simple and inspectable.
- Do not add a new exported symbol unless it is part of the stable public API.
- Update the relevant `docs/src` Guide page when the public API changes.
- Update `docs/src/examples.md` when example files are added, removed, or renamed.
- Update examples when a public API changes.
- Update [Verification](compatibility.md) and [Release Evidence](release-process.md)
  when a change alters a checked workflow or release evidence.
- Update [Cookbook](cookbook.md) when a supported usage pattern changes or a new pattern
  becomes part of the public contract.
- Update [FAQ](faq.md) when a change alters user-facing boundary selection guidance.
- Update [Architecture](architecture.md) when subsystem responsibilities or layering constraints change.

## Test Expectations

Every exported subsystem should have at least one regression test. Prefer
tests that demonstrate observable behavior over tests that only inspect
implementation details. The test suite also checks that the `docs/src` Guide
pages document the current exported API surface and the checked-in example
files, and that verification, release, cookbook, and other documentation stays
aligned with executable verification, so documentation drift should be fixed in
the same change as the behavior. The checked-in `examples/*.lisp` files are
also expected to run from a fresh SBCL process after loading the checkout
through ASDF.

Use `cl-weave` for new test cases and machine-readable evidence. Where an
invariant spans multiple boundary implementations, prefer extending the
declarative `cl-prolog` rulebase rather than duplicating procedural assertions.

## Communication Expectations

Use repository discussions, issues, and review threads for technical decisions.
Keep criticism concrete, scoped to the code or design, and backed by evidence.
If discussion stops being productive, move to the conduct and reporting
guidance in [Code of Conduct](code-of-conduct.md).
Project-level scope and decision criteria are defined in
[Governance](governance.md); proposed changes should argue from that
contract surface rather than from framework-style expansion.
Design-level changes should also stay aligned with the layering model in
[Architecture](architecture.md) so protocol boundaries, shared utilities,
and test evidence do not drift apart.
Maintainers preparing a release should also follow [Release Process](release-process.md)
so release evidence and executable verification stay in sync.
Direct usage questions and support requests to the paths documented in
[Support](support.md) so bug reports, design discussion, and security
reports stay separated.
