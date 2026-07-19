;;;; src/process-recording-boundary.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-recording-process-boundary (&key (delegate (make-process-boundary)))
  "Create a process boundary that records calls while delegating execution."
  (let ((process-delegate (%require-process-boundary delegate "DELEGATE")))
    (%make-process-boundary-data +recording-process-boundary-type+
                                 :run-fn (%process-runner process-delegate)
                                 :delegate process-delegate
                                 :calls '())))
