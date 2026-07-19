;;;; src/filesystem-recording-constructor.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-recording-filesystem (&key delegate)
  "Create a filesystem boundary that records calls before returning DELEGATE results."
  (let ((delegate (%require-filesystem (or delegate (make-filesystem)) "DELEGATE")))
    (%make-filesystem-data
     +recording-filesystem-type+
     :read-file-fn (getf delegate :read-file-fn)
     :write-file-fn (getf delegate :write-file-fn)
     :probe-file-fn (getf delegate :probe-file-fn)
     :list-directory-fn (getf delegate :list-directory-fn)
     :path-exists-p-fn (getf delegate :path-exists-p-fn)
     :calls (list nil)
     :delegate delegate)))
