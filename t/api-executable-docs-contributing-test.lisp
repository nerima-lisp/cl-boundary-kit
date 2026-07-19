;;;; t/api-executable-docs-contributing-test.lisp

(in-package #:cl-boundary-kit/test)

(define-documentation-fresh-sbcl-tests
  (contributing-local-setup-install-snippet-loads-system-from-a-checkout
   "contributing-installation"
   :forbidden ("@@CASE-FAIL contributing-installation@@")))

(it "contributing-local-setup-install-snippet-matches-readme-installation-snippet"
  (expect (string=
       (first-readme-fenced-code-block "## Installation" "## Quick Start" "lisp")
       (nth-document-fenced-code-block "CONTRIBUTING.md"
                                       "## Local Setup"
                                       "## Change Guidelines"
                                       "lisp"
                                       0)) :to-be-truthy))

(it "contributing-local-setup-repl-snippet-matches-readme-testing-snippet"
  (expect (string=
       (first-readme-fenced-code-block "## Testing" "## Compatibility" "lisp")
       (nth-document-fenced-code-block "CONTRIBUTING.md"
                                       "## Local Setup"
                                       "## Change Guidelines"
                                       "lisp"
                                       1)) :to-be-truthy))

(define-document-search-tests
  (contributing-local-setup-documents-documented-test-runner-expectation
   :file "CONTRIBUTING.md"
   :contains ("documented REPL runner"
              "`(asdf:load-system :cl-boundary-kit/test)`"
              "`(cl-boundary-kit/test:run-tests)`"
              "`0 failures`"
              "stable verification path"))
  (contributing-documents-the-code-of-conduct
   :file "CONTRIBUTING.md"
   :contains ("CODE_OF_CONDUCT.md"
              "## Communication Expectations"))
  (contributing-documents-governance-expectations
   :file "CONTRIBUTING.md"
   :contains ("GOVERNANCE.md"
              "decision criteria"))
  (contributing-documents-architecture-expectations
   :file "CONTRIBUTING.md"
   :contains ("ARCHITECTURE.md"
              "layering model"))
  (contributing-documents-support-routing
   :file "CONTRIBUTING.md"
   :contains ("SUPPORT.md"
              "security"))
  (contributing-documents-faq-and-release-expectations
   :file "CONTRIBUTING.md"
   :contains ("FAQ.md"
              "RELEASE.md"))
  (contributing-documents-documentation-contract-maintenance
   :file "CONTRIBUTING.md"
   :contains ("CHANGELOG.md"
              "deprecated, removed, or changed in a breaking way"
              "migration guidance"
              "COMPATIBILITY.md"
              "COOKBOOK.md"
              "supported usage pattern changes"
              "verification scope"
              "release evidence"
              "compatibility, release, cookbook, and other policy documents stay"
              "aligned with executable verification")))
