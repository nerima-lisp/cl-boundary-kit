;;;; t/api-executable-docs-cookbook-test.lisp

(in-package #:cl-boundary-kit/test)

(define-documentation-fresh-sbcl-tests
  (cookbook-compose-boundaries-snippet-is-executable
   "cookbook-compose-boundaries"
   :expected ("clock: 7")
   :forbidden ("@@CASE-FAIL cookbook-compose-boundaries@@"))
  (cookbook-recorded-boundary-snippet-is-executable
   "cookbook-recorded-boundary"
   :expected (":WRITE-FILE")
   :forbidden ("@@CASE-FAIL cookbook-recorded-boundary@@"))
  (cookbook-unsupported-operation-snippet-is-executable
   "cookbook-unsupported-operation"
   :expected ("operation: CL-BOUNDARY-KIT:ENVIRONMENT-SET")
   :forbidden ("@@CASE-FAIL cookbook-unsupported-operation@@")))
