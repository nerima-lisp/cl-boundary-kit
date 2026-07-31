# cl-boundary-kit

`cl-boundary-kit` is a small Common Lisp library for making boundaries to the
outside world explicit.

It provides lightweight protocols and test doubles for filesystem access,
environment access, clocks, randomness, unique identifiers, temporary paths,
command-line arguments, host introspection, process execution, network
requests, DNS resolution, terminal I/O, process termination, delays, key/value
stores, TTL caches, secret stores, feature flags, locks, semaphores, rate
limiting, deferred scheduling, working directory, logging, metrics,
publish/subscribe messaging, notifications, and boundary recording/context
composition.

It is not an application framework, not a CLI framework, and not a generic
utility grab bag. The goal is to make external effects easy to model, swap, and
test.

!!! tip "New to cl-boundary-kit?"

    Load the library, then swap a real clock for a fake one in under a minute:

    ```lisp
    (asdf:load-system :cl-boundary-kit)
    (cl-boundary-kit:clock-now (cl-boundary-kit:make-fake-clock :start 1000))
    ;; => 1000
    ```

    Continue with [Installation](installation.md) → [Quick Start](quick-start.md)
    → [Core Concepts](core-concepts.md).

## Explore the docs

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } &nbsp; **Getting Started**

    ---

    Install with ASDF or Nix, run your first recorded boundary call, and learn
    the Boundary / Protocol / Test Double / Boundary Context vocabulary.

    [:octicons-arrow-right-24: Installation](installation.md) ·
    [Quick Start](quick-start.md) ·
    [Core Concepts](core-concepts.md)

-   :material-book-open-variant:{ .lg .middle } &nbsp; **Guide**

    ---

    Every boundary's full API, grouped by concern: composition, filesystem and
    environment, time and randomness, process/network/DNS, observability,
    storage, concurrency, messaging, and system/host introspection.

    [:octicons-arrow-right-24: Composition and Context](composition.md) ·
    [Filesystem and Environment](filesystem-and-environment.md) ·
    [Assertions and Testing Helpers](testing-helpers.md)

-   :material-flask-outline:{ .lg .middle } &nbsp; **Examples**

    ---

    Every documented example is directly runnable with
    `sbcl --script examples/<name>.lisp` from a checkout.

    [:octicons-arrow-right-24: Examples](examples.md)

-   :material-cog-outline:{ .lg .middle } &nbsp; **Reference**

    ---

    Layering model, repository layout, the pinned Nix test path, verification
    scope, and the narrow public stability contract.

    [:octicons-arrow-right-24: Architecture](architecture.md) ·
    [Running the Test Suite](testing.md) ·
    [Verification](compatibility.md) ·
    [Documentation Scope](stability-policy.md)

</div>

## Status

- Small, explicit surface area
- Self-contained ASDF system
- Tests included for every exported subsystem

## Highlights

- Protocol-first design with generic functions for each boundary
- Recording and fake implementations for tests
- Recording call histories preserve the arguments and results you asserted on
- Boundary context composition for wiring at the application edge
- Reproducible examples that run from the REPL

## Guide Map

- [Composition and Context](composition.md) — `make-boundary-context`,
  custom recording boundaries, and the `unsupported-boundary-operation`
  condition.
- [Filesystem and Environment](filesystem-and-environment.md) — file, directory,
  environment variable, and working-directory boundaries.
- [Time and Randomness](time-and-randomness.md) — clocks, random sources,
  sleepers, UUIDs, and temporary paths.
- [Process, Network, and DNS](process-network-and-dns.md) — subprocess
  execution, HTTP-shaped requests, DNS resolution, and JSON serialization of
  call histories.
- [Logging, Metrics, and Console](observability.md) — structured logging,
  fire-and-forget metrics, and terminal I/O.
- [State and Storage](state-and-storage.md) — key/value stores, TTL caches,
  secret stores, and feature flags.
- [Concurrency Control](concurrency-control.md) — locks, semaphores, rate
  limiters, and deferred scheduling.
- [Messaging](messaging.md) — publishers, subscribers, and notifiers.
- [System and Host](system-and-host.md) — command-line arguments, host
  introspection, and process termination.
- [Assertions and Testing Helpers](testing-helpers.md) — the full
  recorded-call and event assertion API.

## Nix Workflow

The [flake.nix](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/flake.nix)
at the repository root packages `cl-boundary-kit` as a Nix flake:

- `nix develop` — a devShell with SBCL and every pinned test dependency on the
  ASDF source registry.
- `nix run .#test` — the pinned checkout test runner (`run-tests.lisp`).
- `nix flake check` — the checkout runner, a `cl-weave` machine-readable
  report, and a 100% expression-coverage gate, as reproducible derivations for
  `x86_64-linux`.
- `nix build .#docs` — builds this documentation site with MkDocs (Material)
  in `--strict` mode, so broken links fail the build.

See [Running the Test Suite](testing.md) for the complete verification paths,
including direct `sbcl --script run-tests.lisp` execution without Nix.

## Support

Use [Support](support.md) for the canonical support boundaries and what to
include in a request.

Use [private GitHub security advisories](https://github.com/nerima-lisp/cl-boundary-kit/security/advisories/new)
for vulnerability reporting. Do not put exploit details in a public issue.

## Project Operations

- Cookbook: [cookbook.md](cookbook.md)
- FAQ: [faq.md](faq.md)
- Architecture: [architecture.md](architecture.md)
- Verification: [compatibility.md](compatibility.md)
- Contributing: [contributing.md](contributing.md)
- Governance: [governance.md](governance.md)
- Code of Conduct: [code-of-conduct.md](code-of-conduct.md)
- Support: [support.md](support.md)
- Security: [security.md](security.md)
- Roadmap: [roadmap.md](roadmap.md)
- Release Process: [release-process.md](release-process.md)
- Pull request queue: <https://github.com/nerima-lisp/cl-boundary-kit/pulls>
- Issue tracker: <https://github.com/nerima-lisp/cl-boundary-kit/issues>
- Release notes: <https://github.com/nerima-lisp/cl-boundary-kit/releases>

## License

MIT. See [LICENSE](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/LICENSE).
