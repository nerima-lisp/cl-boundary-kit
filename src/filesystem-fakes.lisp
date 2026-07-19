;;;; src/filesystem-fakes.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-test-filesystem (&key initial-files)
  "Create an in-memory filesystem seeded from INITIAL-FILES."
  (let ((files (make-hash-table :test #'equalp))
        (call-box (list nil)))
    (%seed-test-filesystem-files files initial-files)
    (%instantiate-test-filesystem files call-box)))
