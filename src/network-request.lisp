;;;; src/network-request.lisp

(in-package #:cl-boundary-kit)

(defgeneric %network-boundary-request (network-boundary request timeout))

(defmacro define-network-boundary-request-method (specializer
                                                  (network-boundary request timeout)
                                                  &body body)
  `(defmethod %network-boundary-request ((,network-boundary ,specializer)
                                         ,request
                                         ,timeout)
     ,@body))

(define-network-boundary-request-method test-network-boundary
    (network-boundary request timeout)
  (%test-network-response network-boundary request timeout))

(define-network-boundary-request-method recording-network-boundary
    (network-boundary request timeout)
  (%recording-network-response network-boundary request timeout))

(defmethod %network-boundary-request ((network-boundary network-boundary) request timeout)
  (funcall (network-boundary-request-fn network-boundary) request :timeout timeout))

(defmethod %network-boundary-request ((network-boundary t) request timeout)
  (declare (ignore request timeout))
  (error "Unsupported network boundary type: ~S" network-boundary))

(defun network-boundary-request (network-boundary request &key timeout)
  "Execute REQUEST against NETWORK-BOUNDARY and return the response."
  (%network-boundary-request network-boundary request timeout))
