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

;; NIL class guard: %NETWORK-CALLS is a type-dispatched generic whose
;; fallback method already rejects non-recording/test boundaries, so an
;; extra TYPEP guard here would be redundant.
(define-recording-call-log recording-network-calls reset-recording-network-calls
    (boundary nil %network-calls) "network")
