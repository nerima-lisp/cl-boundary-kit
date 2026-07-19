;;;; src/network-helpers.lisp

(in-package #:cl-boundary-kit)

(declaim (ftype (function (t t &key (:timeout t)) t) network-boundary-request))

(defun %validate-test-network-responses (responses)
  (unless (listp responses)
    (error "Test network boundary responses must be a list: ~S" responses))
  responses)

(defun %record-network-call (boundary request timeout result)
  (typecase boundary
    (test-network-boundary
     (%record-call (%test-network-calls boundary)
       :request request :timeout timeout :result result))
    (recording-network-boundary
     (%record-call (%recording-network-calls boundary)
       :request request :timeout timeout :result result))
    (t
     (error "Unsupported network boundary type: ~S" boundary))))

(defun %test-network-response (network-boundary request timeout)
  ;; No recording here: NETWORK-BOUNDARY-REQUEST applies it externally for
  ;; every :TEST/:RECORDING kind, so a recording boundary wrapping this
  ;; delegate can dispatch straight to this raw effect without re-entering
  ;; the delegate's own recording path and double-recording the call.
  (declare (ignore timeout))
  (let ((responses (test-network-boundary-responses network-boundary)))
    (unless responses
      (error "Test network boundary has no remaining responses for request ~S" request))
    (let ((response (first responses)))
      (setf (test-network-boundary-responses network-boundary) (rest responses))
      response)))
