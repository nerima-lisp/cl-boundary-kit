;;;; src/process-boundary-constructor.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-process-boundary (&key (run-fn #'%real-process-run))
  "Create a process boundary backed by RUN-FN."
  (let ((runner (require-function run-fn "RUN-FN")))
    (%make-process-boundary-data +process-boundary-type+
                                 :run-fn runner)))
