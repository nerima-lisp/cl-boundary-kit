;;;; t/env-recording-test.lisp

(in-package #:cl-boundary-kit/test)

(it "recording-environment-records"
  (let ((env (make-recording-environment :delegate (make-test-environment))))
    (let ((get-result (environment-get env "A" "fallback"))
          (present-result (environment-present-p env "A"))
          (list-result (environment-list env)))
      (let ((calls (recording-environment-calls env)))
        (assert-recorded-call-sequence
         calls
         (list (boundary-call-plist :get (list "A") :result get-result)
               (boundary-call-plist :present-p (list "A") :result present-result)
               (boundary-call-plist :list nil :result list-result)))))))

(it "recording-environment-propagates-unsupported-set"
  (let ((env (make-recording-environment :delegate (make-environment))))
    (signals-unsupported-boundary-operation
        (environment-set "native environment mutation is unavailable")
      (environment-set env "A" "1")
      (let ((calls (recording-environment-calls env)))
        (expect (null calls) :to-be-truthy)))))

(it "make-recording-environment-rejects-non-environment-delegate"
  (signals error
    (make-recording-environment :delegate :bad)))
