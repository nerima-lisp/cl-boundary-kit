;;;; src/filesystem-fakes.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-test-filesystem (&key initial-files)
  "Create an in-memory filesystem seeded from INITIAL-FILES."
  (let ((files (make-hash-table :test #'equalp))
        (directories (make-hash-table :test #'equalp))
        (directory-counts (%make-test-directory-counts))
        (call-box (list nil)))
    (%seed-test-filesystem-files files directory-counts initial-files)
    (%instantiate-test-filesystem files directories directory-counts call-box)))
