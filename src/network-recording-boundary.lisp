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

(defun reset-recording-network-calls (boundary)
  "Clear BOUNDARY's recorded call history and return BOUNDARY.

Recording/test network boundaries otherwise retain every call for the
object's whole lifetime; call this periodically to bound memory growth
instead of only being able to reclaim it by discarding the object."
  (typecase boundary
    (test-network-boundary
     (setf (%test-network-calls boundary) nil)
     boundary)
    (recording-network-boundary
     (setf (%recording-network-calls boundary) nil)
     boundary)
    (t
     (error "Unsupported network boundary type: ~S" boundary))))
