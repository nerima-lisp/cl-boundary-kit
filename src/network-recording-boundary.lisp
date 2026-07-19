;;;; src/network-recording-boundary.lisp

(in-package #:cl-boundary-kit)

(defun make-recording-network-boundary (&key delegate)
  "Create a network boundary that records requests while delegating to DELEGATE."
  (require-instance delegate 'network-boundary "DELEGATE")
  (make-instance 'recording-network-boundary
                 :request-fn (network-boundary-request-fn delegate)
                 :delegate delegate))

(defun recording-network-calls (boundary)
  "Return the recorded network calls in request order."
  (%snapshot-recorded-calls (%network-calls boundary)))
