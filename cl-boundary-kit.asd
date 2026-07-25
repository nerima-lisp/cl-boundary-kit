;;;; cl-boundary-kit.asd

(asdf:defsystem "cl-boundary-kit"
  :description "Explicit boundary abstractions for Common Lisp"
  :long-description "Protocol-first boundary abstractions, fakes, and recording test doubles for explicit filesystem, environment, clock, random, process, network, and logging effects."
  :version "0.6.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
  :depends-on (:asdf :cl-log-kit)
  :pathname "src"
  :serial t
  :components
  ((:file "package")
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
   (:file "process-exec-helpers"
    :depends-on ("process-exec-capture" "process-exec-lifecycle"))
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
   (:file "logging-kit-adapter")
   (:file "metrics")
   (:file "publisher")
   (:file "subscriber")
   (:file "notifier")
   (:file "testing-helpers")
   (:file "testing-queries" :depends-on ("testing-helpers"))
   (:file "testing" :depends-on ("testing-queries"))
   (:file "testing-events")))

;; A separate system, not a CL-BOUNDARY-KIT component: CL-PROCESS-KIT itself
;; depends on CL-BOUNDARY-KIT (it builds on this system's boundary
;; abstractions for its own injectable clock/sleeper hooks), so folding
;; CL-PROCESS-KIT into CL-BOUNDARY-KIT's own :DEPENDS-ON would create an
;; ASDF circular dependency. Load this system explicitly to get
;; PROCESS-KIT-RUN-FN.
(asdf:defsystem "cl-boundary-kit/process-kit"
  :description "cl-process-kit-backed :run-fn for cl-boundary-kit process boundaries"
  :version "0.6.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
  :depends-on (:cl-boundary-kit :cl-process-kit)
  :pathname "src"
  :components ((:file "process-kit-adapter")))

;; A separate, optional system: the core is deliberately dependency-light, so
;; JSON serialization of recorded call histories lives here rather than folding
;; CL-JSON-KIT into the core :DEPENDS-ON. Load this system to get
;; RECORDING-CALLS-TO-JSON.
(asdf:defsystem "cl-boundary-kit/json"
  :description "cl-json-kit-backed JSON serialization of cl-boundary-kit recorded call histories"
  :version "0.6.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
  :depends-on (:cl-boundary-kit :cl-json-kit)
  :pathname "src"
  :components ((:file "json-adapter")))

(asdf:defsystem "cl-boundary-kit/test"
  :description "Test system for cl-boundary-kit"
  :long-description "Regression tests for the cl-boundary-kit public API, documentation contracts, examples, and the documented checkout test runner."
  :version "0.6.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-boundary-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-boundary-kit")
  :depends-on (:cl-boundary-kit "cl-boundary-kit/process-kit" "cl-boundary-kit/json"
               :cl-prolog :cl-prolog/weave :cl-weave)
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "matchers")
   (:file "prolog-boundary-invariants")
   (:file "prolog-advanced-test")
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
   (:file "process-kit-adapter-test")
   (:file "json-adapter-test")
   (:file "network-test")
   (:file "logging-test")
   (:file "logging-kit-adapter-test")
   (:file "metrics-test")
   (:file "publisher-test")
   (:file "subscriber-test")
   (:file "notifier-test")
   (:file "context-test")
   (:file "recording-test")
   (:file "property-invariants-test")
   (:file "testing-helpers-test")
   (:file "examples-test-helpers")
   (:file "api-test-helpers-doc")
   (:file "api-test-helpers-markdown")
   (:file "api-test-helpers-doc-search")
   (:file "api-test-helpers-fresh-sbcl")
   (:file "api-test-helpers-regression")
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
