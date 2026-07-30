;;;; t/api-executable-docs-contributing-test.lisp

(in-package #:cl-boundary-kit/test)

(define-documentation-fresh-sbcl-tests
  (contributing-local-setup-install-snippet-loads-system-from-a-checkout
   "contributing-installation"
   :forbidden ("@@CASE-FAIL contributing-installation@@")))

(it "contributing-local-setup-install-snippet-matches-readme-installation-snippet"
  (expect (string=
       (single-document-fenced-code-block "docs/src/installation.md" "# Installation" "## Nix" "lisp")
       (nth-document-fenced-code-block "docs/src/contributing.md"
                                       "## Local Setup"
                                       "## Change Guidelines"
                                       "lisp"
                                       0)) :to-be-truthy))

(it "contributing-local-setup-repl-snippet-matches-readme-testing-snippet"
  (expect (string=
       (single-document-fenced-code-block "docs/src/testing.md" "# Running the Test Suite" nil "lisp")
       (nth-document-fenced-code-block "docs/src/contributing.md"
                                       "## Local Setup"
                                       "## Change Guidelines"
                                       "lisp"
                                       1)) :to-be-truthy))

(define-document-search-tests (contributing-local-setup-documents-documented-test-runner-expectation :file "docs/src/contributing.md" :contains ("documented REPL runner" "`(asdf:load-system :cl-boundary-kit/test)`" "`(cl-boundary-kit/test:run-tests)`" "`0 failures`" "stable verification path")) (contributing-documents-the-code-of-conduct :file "docs/src/contributing.md" :contains ("code-of-conduct.md" "## Communication Expectations")) (contributing-documents-governance-expectations :file "docs/src/contributing.md" :contains ("governance.md" "decision criteria")) (contributing-documents-architecture-expectations :file "docs/src/contributing.md" :contains ("architecture.md" "layering model")) (contributing-documents-support-routing :file "docs/src/contributing.md" :contains ("support.md" "security")) (contributing-documents-faq-and-release-expectations :file "docs/src/contributing.md" :contains ("faq.md" "release-process.md")) (contributing-documents-documentation-contract-maintenance :file "docs/src/contributing.md" :contains ("compatibility.md" "cookbook.md" "supported usage pattern changes" "checked workflow" "release evidence" "verification, release, cookbook, and other documentation stays" "aligned with executable verification")))
