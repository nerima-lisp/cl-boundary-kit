;;;; cl-boundary-kit.asd

(asdf:defsystem "cl-boundary-kit"
  :description "Explicit boundary abstractions for Common Lisp"
  :long-description "Protocol-first boundary abstractions, fakes, and recording test doubles for explicit filesystem, environment, clock, random, process, network, and logging effects."
  :version "0.2.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/takeokunn/cl-boundary-kit"
  :bug-tracker "https://github.com/takeokunn/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/takeokunn/cl-boundary-kit")
  :depends-on (:asdf)
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "core")
   (:file "core-utilities")
   (:file "recording-boundary")
   (:file "protocols")
   (:file "filesystem-classes")
   (:file "filesystem-fakes-helpers")
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
   (:file "process")
   (:file "process-helpers" :depends-on ("process"))
   (:file "process-exec-helpers" :depends-on ("process-helpers"))
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
   (:file "testing-helpers")
   (:file "testing" :depends-on ("testing-helpers"))))

(asdf:defsystem "cl-boundary-kit/test"
  :description "Test system for cl-boundary-kit"
  :long-description "Regression tests for the cl-boundary-kit public API, documentation contracts, examples, and the documented checkout test runner."
  :version "0.2.0"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :homepage "https://github.com/takeokunn/cl-boundary-kit"
  :bug-tracker "https://github.com/takeokunn/cl-boundary-kit/issues"
  :source-control (:git "https://github.com/takeokunn/cl-boundary-kit")
  :depends-on (:cl-boundary-kit :cl-prolog :cl-prolog/weave :cl-weave)
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "prolog-boundary-invariants")
   (:file "filesystem-test")
   (:file "env-test")
   (:file "env-native-test")
   (:file "env-recording-test")
   (:file "clock-test")
   (:file "random-test")
   (:file "process-test")
   (:file "network-test")
   (:file "logging-test")
   (:file "context-test")
   (:file "recording-test")
   (:file "property-invariants-test")
   (:file "testing-helpers-test")
   (:file "examples-test-helpers")
   (:file "api-test-helpers-doc")
   (:file "api-test-helpers-markdown")
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
   (:file "examples-test")
   (:file "examples-runtime-test")))
