# Compatibility

## Verification Scope

Current compatibility claims are intentionally narrow and tied to executable
verification in this repository.

- Provides a pinned Nix test path through `nix run .#test`
- Emits pinned Nix apps and checks for `x86_64-linux` and `aarch64-darwin`;
  the Ubuntu CI workflow is the canonical Linux verification path
- Exercises the supported host flake check set through `nix flake check`,
  including the checkout runner, a `cl-weave` JSON report, and an 80% coverage
  threshold
- Does not require Quicklisp when using the Nix flake; Nix supplies SBCL,
  `cl-prolog`, `cl-weave`, `cl-log-kit`, `cl-process-kit`, and `cl-json-kit`
- Supports direct `sbcl --script run-tests.lisp` execution when `cl-prolog`,
  `cl-weave`, `cl-log-kit`, `cl-process-kit`, and `cl-json-kit` are already
  discoverable by ASDF
- Does not claim compatibility for hosts outside the emitted flake systems;
  direct SBCL execution is the fallback there
- Regression-checks the README installation, quick-start, and test commands
  against a fresh SBCL process, exercising the checkout install flow end to end
- Regression-checks the documented REPL runner as the stable verification path:
  `asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)` from a fresh SBCL process
- Treats that fresh-SBCL test-runner contract as successful completion with
  `0 failures` and exit status 0
- Regression-checks the checked-in `examples/*.lisp` files against a fresh
  SBCL process via direct `sbcl --script examples/<name>.lisp` execution
- Regression-checks cookbook snippets and documentation contracts alongside
  the checked-in examples and README flows
- Treats the exported symbol list in `README.md` `## API Overview` and the file
  index in `README.md` `## Examples` as regression-checked documentation
  contracts
- Produces `report.json` for machine-readable test results and coverage data,
  summary, and HTML files from the corresponding Ubuntu/Linux Nix checks

## Non-Claims

Other Common Lisp implementations may work, but they are not claimed as
supported until they are exercised by real verification in this repository.

Compatibility does not imply:

- host-specific fallback behavior for unsupported operations
- guarantees for application frameworks layered on top of this library
- support promises for implementations or platforms that are only assumed to
  work

If behavior differs on an unverified implementation or platform, do not treat
that as a broken compatibility promise by itself. Use [`SUPPORT.md`](SUPPORT.md)
for ordinary compatibility questions, reproducible contract failures, or
documentation drift, and use [`SECURITY.md`](SECURITY.md) when the behavior
exposes a vulnerability, secret leak, or unsafe effect handling concern.

## Change Policy

When compatibility expectations change, update the executable tests together
with `README.md`, this document, and `CHANGELOG.md`.
