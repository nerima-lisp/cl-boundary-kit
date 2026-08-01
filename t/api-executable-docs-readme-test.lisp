;;;; t/api-executable-docs-readme-test.lisp

(in-package #:cl-boundary-kit/test)

(define-documentation-fresh-sbcl-tests
   (readme-installation-snippet-loads-system-from-a-checkout
    "readme-installation"
    :forbidden ("@@CASE-FAIL readme-installation@@"))
   (readme-installation-and-quick-start-flow-is-executable
    "readme-installation-and-quick-start"
    :forbidden ("@@CASE-FAIL readme-installation-and-quick-start@@"))
   (readme-testing-section-repl-snippet-is-executable
    "readme-testing-repl"
    :expected ("0 failures")
    :forbidden ("@@CASE-FAIL readme-testing-repl@@")))

(it "readme-testing-section-repl-snippet-uses-documented-test-runner"
  (let* ((snippet (single-document-fenced-code-block
                   "docs/src/project/development.md" "## Running the Test Suite" nil "lisp"))
         (testing-doc (repository-file-string "docs/src/project/development.md")))
    (expect (not (null (search "(asdf:load-system :cl-boundary-kit/test)" snippet))) :to-be-truthy)
    (expect (not (null (search "(cl-boundary-kit/test:run-tests)" snippet))) :to-be-truthy)
    (expect (not (null (search "successful completion with `0 failures`" testing-doc))) :to-be-truthy)
    (expect (not (null (search "documented REPL runner" testing-doc))) :to-be-truthy)))
