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
  (let ((responses (test-network-boundary-responses network-boundary)))
    (unless responses
      (error "Test network boundary has no remaining responses for request ~S" request))
    (let ((response (first responses)))
      (setf (test-network-boundary-responses network-boundary) (rest responses))
      (%record-network-call network-boundary request timeout response)
      response)))

(defun %recording-network-response (network-boundary request timeout)
  (let ((result (network-boundary-request (recording-network-boundary-delegate network-boundary)
                                          request
                                          :timeout timeout)))
    (%record-network-call network-boundary request timeout result)
    result))
