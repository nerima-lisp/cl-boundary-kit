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

;; Dispatches straight to the delegate's own raw %NETWORK-BOUNDARY-REQUEST
;; method -- not through the public NETWORK-BOUNDARY-REQUEST below -- so a
;; self-recording (test-kind) delegate is never invoked through its own
;; recording path. NETWORK-BOUNDARY-REQUEST applies recording once,
;; externally, for both :TEST and :RECORDING kinds.
(define-network-boundary-request-method recording-network-boundary
    (network-boundary request timeout)
  (%network-boundary-request (recording-network-boundary-delegate network-boundary) request timeout))

(defmethod %network-boundary-request ((network-boundary network-boundary) request timeout)
  (funcall (network-boundary-request-fn network-boundary) request :timeout timeout))

(defmethod %network-boundary-request ((network-boundary t) request timeout)
  (declare (ignore request timeout))
  (error "Unsupported network boundary type: ~S" network-boundary))

(defun network-boundary-request (network-boundary request &key timeout)
  "Execute REQUEST against NETWORK-BOUNDARY and return the response."
  (if (or (typep network-boundary 'test-network-boundary)
          (typep network-boundary 'recording-network-boundary))
      (let ((result (%network-boundary-request network-boundary request timeout)))
        (%record-network-call network-boundary request timeout result)
        result)
      (%network-boundary-request network-boundary request timeout)))
