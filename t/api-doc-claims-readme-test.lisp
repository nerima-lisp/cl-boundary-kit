;;;; t/api-doc-claims-readme-test.lisp

(in-package #:cl-boundary-kit/test)

;; Every case here used to be a :SECTION lookup within README.md. Now that
;; README is a lean landing page, each checks the docs/src page(s) that took
;; over as the authoritative source for that content (verified equal to the
;; former README prose where the underlying subsystem docs did not already
;; carry an equivalent, purpose-written sentence of their own).
(define-document-search-tests
  (:cases (readme-document-search-shared-cases))
  (readme-api-overview-documents-composition-and-condition-contracts
   :file "docs/src/guide/composition.md"
   :contains ("records the operation, arguments, and returned"
              "preserving explicit `nil` results"
              "without adding a partial call"
              "intentionally unavailable"
              "silently emulating behavior"
              "failed operation and its detail"))
  (readme-process-and-network-sections-document-explicit-nil-result-contracts
   :file "docs/src/guide/process-network-and-dns.md"
   :contains ("explicit `nil` result"
              "responses from test queues or delegates"))
  (readme-filesystem-environment-and-logging-sections-document-stateful-test-double-contracts
   :haystack (concatenate 'string
                          (repository-file-string "docs/src/guide/filesystem-and-environment.md")
                          (repository-file-string "docs/src/guide/observability.md"))
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
   :haystack (concatenate 'string
                          (repository-file-string "docs/src/guide/time-and-randomness.md")
                          (repository-file-string "docs/src/guide/testing-helpers.md"))
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
  (readme-stability-policy-documents-the-public-contract :haystack (concatenate (quote string) (repository-file-string "docs/src/reference/stability-policy.md") (repository-file-string "docs/src/reference/repository-layout.md")) :contains ("exported symbols listed across the [Guide](../guide/composition.md) pages define" "`examples/*.lisp`" "`asdf:load-system :cl-boundary-kit/test`" "`cl-boundary-kit/test:run-tests`" "cookbook.md" "faq.md" "architecture.md" "compatibility.md" "release-process.md" "regression-checked usage contracts" "Internal helpers" "checked verification workflows"))
  (readme-contributing-and-governance-sections-document-contract-maintenance :file "docs/src/project/contributing.md" :contains ("documented public behavior" "executable tests" "relevant examples" "README.md" "checked workflow" "release evidence")))
