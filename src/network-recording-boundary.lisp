;;;; src/network-recording-boundary.lisp

(in-package #:cl-boundary-kit)

(defun make-recording-network-boundary (&key delegate
                                             (request-redactor-fn #'%redact-network-value)
                                             (response-redactor-fn #'%redact-network-value))
  "Create a network boundary that records sanitized calls while delegating to DELEGATE."
  (require-instance delegate 'network-boundary "DELEGATE")
  (require-function request-redactor-fn "REQUEST-REDACTOR-FN")
  (require-function response-redactor-fn "RESPONSE-REDACTOR-FN")
  (make-instance 'recording-network-boundary
                 :request-fn (network-boundary-request-fn delegate)
                 :delegate delegate
                 :request-redactor-fn request-redactor-fn
                 :response-redactor-fn response-redactor-fn))

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
