# Verification

## Checked Workflows

The repository exercises these workflows through checked-in verification.

- Provides a pinned Nix test path through `nix run .#test`
- Emits pinned Nix apps and checks for `x86_64-linux` only;
  the Ubuntu CI workflow is the canonical verification path
- Exercises the supported host flake check set through `nix flake check`,
  including the checkout runner, a `cl-weave` JSON report, and a 100% coverage
  threshold
- Does not require Quicklisp when using the Nix flake; Nix supplies SBCL and
  the ASDF dependencies used by the test suite
- Supports direct `sbcl --script run-tests.lisp` execution when the test
  dependencies are discoverable by ASDF
- Hosts outside the emitted flake systems can run the library when their implementation and dependencies satisfy the documented API requirements
- Regression-checks the docs/src installation, quick-start, and test commands
  against a fresh SBCL process, exercising the checkout install flow end to end
- Regression-checks the documented REPL runner as the stable verification path:
  `asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)` from a fresh SBCL process
- Treats that fresh-SBCL test-runner contract as successful completion with
  `0 failures` and exit status 0
- Regression-checks the checked-in `examples/*.lisp` files against a fresh
  SBCL process via direct `sbcl --script examples/<name>.lisp` execution
- Regression-checks cookbook snippets and documentation contracts alongside
  the checked-in examples and README flows
- Treats the exported symbol list documented across the [Guide](composition.md)
  pages and the file index in [Examples](examples.md) as regression-checked
  documentation contracts
- Produces `report.json` for machine-readable test results and coverage data,
  summary, and HTML files from the corresponding Ubuntu/Linux Nix checks

Use [Support](support.md) for reproducible failures or documentation drift, and
use [Security](security.md) when behavior exposes a vulnerability, secret leak,
or unsafe effect handling concern.
