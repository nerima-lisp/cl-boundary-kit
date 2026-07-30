# Installation

Clone the repository and load it with ASDF:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit)
```

If you use a local-projects setup, place the repository under your ASDF source
tree and load it the same way.

## Nix

The [flake.nix](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/flake.nix)
at the repository root packages `cl-boundary-kit` as a Nix flake and pins the
test environment, so a checkout does not require Quicklisp:

```sh
nix run .#test
```

See [Running the Test Suite](testing.md) for the full set of verification
paths.

Continue with [Quick Start](quick-start.md) → [Core Concepts](core-concepts.md).
