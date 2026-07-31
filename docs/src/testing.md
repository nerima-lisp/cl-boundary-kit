# Running the Test Suite

The recommended pinned checkout test command is:

```sh
nix run .#test
```

The flake pins SBCL, `cl-prolog`, and `cl-weave`, so this path does not require
Quicklisp or separately installed Common Lisp dependencies. `cl-weave` provides
the test runner, machine-readable reporting, and coverage integration.
`cl-prolog` is used by the test system to express and verify cross-boundary
invariants. These runnable flake apps and checks are emitted for
`x86_64-linux` only; the Ubuntu GitHub Actions workflow is the canonical
verification path.

On a supported Nix host, run `nix flake check --print-build-logs` to execute
the flake checks for that host, including the checkout runner,
machine-readable report generation, and the coverage threshold. The CI
workflow additionally builds the `machine-report` and `coverage` checks as
artifacts. They contain `report.json`, and, for the coverage check,
`coverage.dat`, `coverage-summary.txt`, and the `coverage-html/` report. The
coverage check requires 100% expression coverage of executable source forms.
`package.lisp`, `process.lisp`, `protocols.lisp`, and `system-data.lisp` are
excluded because they only establish package, constants, or generic-function
declarations; SB-COVER cannot record a runtime hit for those top-level
declarations. The `cl-weave` runner limits each test to 30 seconds. Each Nix
check has a 300-second outer limit followed by a 30-second forced-termination
grace period, so a stopped test process cannot retain a CI worker. Hosts outside
the emitted flake systems are not a compatibility claim; use
`sbcl --script run-tests.lisp` there when `cl-prolog` and `cl-weave` are
discoverable by ASDF.

For local development on any host with an existing SBCL environment, run
`sbcl --script run-tests.lisp`. Quicklisp itself is not required, but direct
SBCL and REPL use requires `cl-prolog` and `cl-weave` to be discoverable by
ASDF. The suite exercises
filesystem, environment, clock, random, process, network, logging, recording,
and boundary composition behavior.

If you want to run it from a REPL instead, register this checkout and those
dependencies, then load the test system and invoke the same documented REPL
runner explicitly:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit/test)
(cl-boundary-kit/test:run-tests)
```

The documented REPL runner reaches successful completion with `0 failures` and
exit status 0 when the whole suite is green; treat any other outcome as a
regression to fix before relying on the checkout.

See [Verification](compatibility.md) for the checked workflows, and [Contributing](contributing.md) for
the workflow that keeps documentation, examples, and tests in sync.
