;;;; src/process-test-boundary.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-test-process-boundary (&key results)
  "Create a test process boundary that returns RESULTS in order."
  (%make-process-boundary-data +test-process-boundary-type+
                               :run-fn nil
                               :results (%validate-test-process-results results)
                               :calls '()))
