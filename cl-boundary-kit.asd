;;;; cl-boundary-kit.asd

;;; This form comes first, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current. Saying it makes the
;;; file self-contained.
(in-package #:asdf-user)

;;; Metadata keys are in the org's canonical order (PACKAGE_STANDARD.md,
;;; "asd の書き方"): :description :long-description :author :maintainer
;;; :license :version :homepage :bug-tracker :source-control :depends-on
;;; :pathname :serial :components :in-order-to.
(asdf:defsystem "cl-boundary-kit"
  :description "Explicit boundary abstractions for Common Lisp"
  :long-description "Protocol-first boundary abstractions, fakes, and recording test doubles for explicit filesystem, environment, clock, random, process, network, and logging effects."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "2.0.1"
  :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
  :depends-on (:asdf :cl-host-kit)
  :pathname "src"
  :serial t
  :components ((:file "package")
    (:file "core")
    (:file "core-utilities")
    (:file "recording-boundary")
    (:file "protocols")
    (:file "filesystem-classes")
    (:file "filesystem-delete")
    (:file "filesystem-move")
    (:file "filesystem-directory-ops")
    (:file "filesystem-fakes-entries")
    (:file "filesystem-fakes-normalize" :depends-on ("filesystem-fakes-entries"))
    (:file "filesystem-fakes-helpers" :depends-on ("filesystem-fakes-normalize"))
    (:file "filesystem-fakes" :depends-on ("filesystem-fakes-helpers"))
    (:file "filesystem-read")
    (:file "filesystem-directory")
    (:file "filesystem-write")
    (:file "filesystem-store-cps")
    (:file "filesystem-store")
    (:file "filesystem-make")
    (:file "filesystem-recording-constructor")
    (:file "filesystem-probe")
    (:file "filesystem-path-exists")
    (:file "env-helpers")
    (:file "env-classes" :depends-on ("env-helpers"))
    (:file "clock")
    (:file "random")
    (:file "uuid")
    (:file "temp-path")
    (:file "args")
    (:file "host-info")
    (:file "sleeper")
    (:file "console")
    (:file "console-methods" :depends-on ("console"))
    (:file "system-data")
    (:file "system")
    (:file "kv")
    (:file "lock")
    (:file "semaphore")
    (:file "working-directory")
    (:file "dns")
    (:file "secret")
    (:file "feature-flags")
    (:file "cache")
    (:file "rate-limiter")
    (:file "scheduler")
    (:file "process")
    (:file "process-helpers" :depends-on ("process"))
    (:file "process-exec-capture" :depends-on ("process-helpers"))
    (:file "process-exec-lifecycle" :depends-on ("process-helpers"))
    (:file
      "process-exec-helpers"
      :depends-on
      ("process-exec-capture" "process-exec-lifecycle"))
    (:file "process-boundary-constructor")
    (:file "process-test-boundary")
    (:file "process-recording-boundary")
    (:file "process-recording")
    (:file "process-request")
    (:file "network-classes")
    (:file "network-helpers")
    (:file "network-constructors")
    (:file "network-test-boundary")
    (:file "network-recording-boundary")
    (:file "network-request")
    (:file "logging")
    (:file "metrics")
    (:file "publisher")
    (:file "subscriber")
    (:file "notifier")
    (:file "testing-helpers")
    (:file "testing-queries" :depends-on ("testing-helpers"))
    (:file "testing" :depends-on ("testing-queries"))
    (:file "testing-events"))
  ;; Without this, `asdf:test-system "cl-boundary-kit"` succeeds while running
  ;; zero tests.
  :in-order-to ((test-op (test-op "cl-boundary-kit/test"))))

(progn
  (asdf:defsystem "cl-boundary-kit/test-base"
    :description "Non-Prolog test support and regression tests for cl-boundary-kit"
    :depends-on (:cl-boundary-kit :cl-weave)
    :pathname "t"
    :serial t
    :components ((:file "package")
      (:file "helpers-matchers")
      (:file "helpers-test-macros")
      (:file "core-utilities-test")
      (:file "filesystem-test")
      (:file "filesystem-recording-test")
      (:file "filesystem-ops-test")
      (:file "env-test")
      (:file "env-native-test")
      (:file "env-recording-test")
      (:file "clock-test")
      (:file "random-test")
      (:file "uuid-test")
      (:file "temp-path-test")
      (:file "args-test")
      (:file "host-info-test")
      (:file "sleeper-test")
      (:file "console-test")
      (:file "system-test")
      (:file "kv-test")
      (:file "lock-test")
      (:file "semaphore-test")
      (:file "working-directory-test")
      (:file "dns-test")
      (:file "secret-test")
      (:file "feature-flags-test")
      (:file "cache-test")
      (:file "rate-limiter-test")
      (:file "scheduler-test")
      (:file "process-test")
      (:file "process-native-test")
      (:file "network-test")
      (:file "logging-test")
      (:file "metrics-test")
      (:file "publisher-test")
      (:file "subscriber-test")
      (:file "notifier-test")
      (:file "context-test")
      (:file "recording-test")
      (:file "testing-helpers-test")
      (:file "helpers-examples")
      (:file "helpers-api-doc")
      (:file "helpers-api-markdown")
      (:file "helpers-api-doc-search")
      (:file "helpers-api-fresh-sbcl")
      (:file "helpers-api-regression")
      (:file "api-test")
      (:file "api-doc-claims-foundation-test")
      (:file "api-doc-claims-readme-test")
      (:file "api-doc-links-foundation-test")
      (:file "api-doc-links-documents-test")
      (:file "api-doc-links-readme-test")
      (:file "api-executable-docs-readme-test")
      (:file "api-executable-docs-contributing-test")
      (:file "api-executable-docs-cookbook-test")
      (:file "coverage-completion-test")
      (:file "examples-test")
      (:file "examples-runtime-test")))
  (asdf:defsystem "cl-boundary-kit/test-prolog"
    :description "Prolog-backed test suite for cl-boundary-kit"
    :depends-on (:cl-boundary-kit/test-base :cl-prolog :cl-prolog/weave)
    :pathname "t"
    :serial t
    :components ((:file "prolog-boundary-invariants-test")
      (:file "prolog-advanced-test")
      (:file "property-invariants-test")))
  (asdf:defsystem "cl-boundary-kit/test"
    :description "Test system for cl-boundary-kit"
    :long-description "Regression tests for the cl-boundary-kit public API, documentation contracts, examples, and the documented checkout test runner."
    :version "2.0.1"
    :author "takeokunn <bararararatty@gmail.com>"
    :maintainer "takeokunn <bararararatty@gmail.com>"
    :license "MIT"
    :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
    :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
    :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
    :depends-on (:cl-boundary-kit/test-base :cl-boundary-kit/test-prolog)))
