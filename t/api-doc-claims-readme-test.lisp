;;;; t/api-doc-claims-readme-test.lisp

(in-package #:cl-boundary-kit/test)

(define-readme-document-search-tests
  (:cases (readme-document-search-shared-cases))
  (readme-api-overview-documents-composition-and-condition-contracts
   :section ("## API Overview" "## Examples")
   :contains ("records the operation, arguments, and returned"
              "preserving explicit `nil` results"
              "without adding a partial call"
              "intentionally unavailable"
              "silently emulating behavior"
              "failed operation and its detail"))
  (readme-process-and-network-sections-document-explicit-nil-result-contracts
   :section ("### Process" "### Logging")
   :contains ("explicit `nil` result"
              "responses from test queues or delegates"))
  (readme-filesystem-environment-and-logging-sections-document-stateful-test-double-contracts
   :section ("### Filesystem" "### Testing Helpers")
   :contains ("state-backed fake that accepts `:initial-files` as"
              "Missing reads and unsupported write-mode combinations signal explicitly"
              "recording filesystems require a `filesystem` delegate"
              "Custom environment getters may return two values"
              "present `nil`"
              "`environment-list` view is sorted by variable name"
              "Recording environments also require an `environment` delegate"
              "`logger-log` returns the emitted event object"
              "attempted event stays"
              "`recording-log-events`"
              "recording loggers require a `logger` delegate"))
  (readme-clock-random-and-testing-helper-sections-document-deterministic-testing-contracts
   :section ("### Clock" "## Examples")
   :contains ("`make-fake-clock` accepts an optional `:monotonic-start`"
              "`advance-fake-clock` accepts `:monotonic-delta`"
              "rejects non-function `:now-fn` and `:monotonic-fn` values"
              "Two sources created with the same seed produce the same sequence"
              "Deterministic sources reject non-positive limits"
              "`:modulus` must be an integer greater than 1"
              "queue-backed fake for tests"
              "signals when the"
              "queue is exhausted"
              "rejects values that do not satisfy the requested"
              "integer or real limit"
              "`assert-recorded-call` checks a recorder call list"
              "`assert-recorded-call-count` asserts how many matching calls were"
              "`assert-recorded-call-sequence` asserts ordered call history"
              "`:exact-length nil`"
              "Supplying `:result nil` asserts an explicit `nil` result"
              "`boundary-call-plist` builds the same plist shape used by the built-in"))
  (readme-stability-policy-documents-the-public-contract
   :section ("## Stability Policy" "## Design Non-Goals")
   :contains ("`## API Overview` define the supported library"
              "`examples/*.lisp`"
              "`asdf:load-system :cl-boundary-kit/test`"
              "`cl-boundary-kit/test:run-tests`"
              "`COOKBOOK.md`"
              "`FAQ.md`"
              "`ARCHITECTURE.md`"
              "`COMPATIBILITY.md`"
              "`RELEASE.md`"
              "executable documentation contract"
              "regression-checked usage contracts"
              "`CHANGELOG.md`"
              "explicitly"
              "migration guidance"))
  (readme-contributing-and-governance-sections-document-contract-maintenance
   :section ("## Contributing" "## Cookbook")
   :contains ("supported public contract"
              "executable tests"
              "relevant examples"
              "README.md"
              "CHANGELOG.md"
              "migration guidance"))
  (readme-contributing-and-governance-sections-document-contract-maintenance-governance
   :section ("## Governance" "## Code of Conduct")
   :contains ("checked-in documentation"
              "examples"
              "executable verification"
              "roadmap intent alone"))
  (readme-faq-and-support-sections-document-routing-expectations-support
   :section ("## Support" "## Security")
   :contains ("SUPPORT.md"
              "private security route"
              "exact exported API"
              "minimal"
              "Common Lisp implementation/platform"))
  )
