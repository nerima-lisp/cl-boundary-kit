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

;;; Regression: MAKE-RECORDING-ENVIRONMENT's default delegate (when :DELEGATE
;;; is omitted) used to be (MAKE-TEST-ENVIRONMENT), an always-empty fake --
;;; unlike every sibling recording constructor, which defaults to the real
;;; native boundary (MAKE-RECORDING-FILESYSTEM -> MAKE-FILESYSTEM,
;;; MAKE-RECORDING-PROCESS-BOUNDARY -> MAKE-PROCESS-BOUNDARY). A caller
;;; expecting parity with those siblings would silently observe only
;;; missing/nil bindings.
(it "make-recording-environment-defaults-to-a-native-delegate"
  (let ((env (make-recording-environment)))
    (expect (equal (environment-get env "PATH" "missing")
               (environment-get (make-environment) "PATH" "missing"))
            :to-be-truthy)))

;;; Regression: RECORDING-ENVIRONMENT-CALLS performed no kind check at all,
;;; unlike every sibling accessor (RECORDING-FILESYSTEM-CALLS,
;;; RECORDING-PROCESS-CALLS, RECORDING-NETWORK-CALLS), which all signal on
;;; an unsupported boundary type.
(it "recording-environment-calls-signals-for-unsupported-environment-types"
  (signals-error-message-contains "Unsupported environment type"
      (recording-environment-calls (make-environment))))
