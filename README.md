# cl-boundary-kit

[![CI](https://github.com/nerima-lisp/cl-boundary-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-boundary-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-2952cc)](https://nerima-lisp.github.io/cl-boundary-kit/)

`cl-boundary-kit` is a small Common Lisp library for making boundaries to the
outside world explicit: protocol-first abstractions, recording wrappers, and
deterministic test doubles for every external effect an application touches
(filesystem, environment, clock, random, process, network, DNS, logging,
metrics, key/value stores, caches, secrets, feature flags, locks, semaphores,
rate limiting, scheduling, and publish/subscribe messaging). It is not an
application framework, not a CLI framework, and not a generic utility grab
bag.

Full documentation, including the complete API guide, cookbook, and every
governance and policy document, is published at
<https://nerima-lisp.github.io/cl-boundary-kit/>. The source for that site
lives in [docs/src/](docs/src/README.md).

## Quick Start

```lisp
(asdf:load-system :cl-boundary-kit)

(let ((clock (cl-boundary-kit:make-fake-clock :start 1000)))
  (list (cl-boundary-kit:clock-now clock)
        (progn (cl-boundary-kit:advance-fake-clock clock 5)
               (cl-boundary-kit:clock-now clock))))
;; => (1000 1005)
```

See [Quick Start](https://nerima-lisp.github.io/cl-boundary-kit/quick-start/)
for more examples and [Installation](https://nerima-lisp.github.io/cl-boundary-kit/installation/)
for every install path.

## Install

Clone the repository and load it with ASDF:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit)
```

Or use the Nix flake, which pins SBCL and every test dependency so a checkout
does not require Quicklisp:

```sh
nix run .#test
```

## Development

```sh
nix develop
nix flake check
nix build .#docs
```

See [Running the Test Suite](https://nerima-lisp.github.io/cl-boundary-kit/testing/)
for the complete verification paths, including direct `sbcl --script
run-tests.lisp` execution without Nix.

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the supported workflow,
validation expectations, and public-surface rules. Project governance,
maintenance, and release policies are available in the
[documentation](https://nerima-lisp.github.io/cl-boundary-kit/).

## Support

Use the [Support](https://nerima-lisp.github.io/cl-boundary-kit/support/) page
for the canonical support boundaries, and
[private GitHub security advisories](https://github.com/nerima-lisp/cl-boundary-kit/security/advisories/new)
for vulnerability reporting. Do not put exploit details in a public issue.

Community conduct is defined in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and
release history is published through
[GitHub Releases](https://github.com/nerima-lisp/cl-boundary-kit/releases).

## License

MIT. See [LICENSE](LICENSE).
