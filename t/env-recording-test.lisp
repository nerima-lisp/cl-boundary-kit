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
  (let ((env (make-recording-environment :delegate (make-environment :set-fn nil))))
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
(it-each ((recording-environment-calls)
          (reset-recording-environment-calls))
    "~A signals for unsupported environment types"
    (operation)
  (expect (lambda () (funcall operation (make-environment)))
          :to-signal-message-containing "Unsupported environment type"))

;;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
;;; double-record every call -- once on the wrapper, once on the delegate's
;;; own history -- because the recording dispatch recursed through the
;;; delegate's public ENVIRONMENT-GET/-SET/-LIST functions, re-entering the
;;; delegate's own recording path. Only the wrapper should record.
(it "recording-environment-does-not-double-record-a-self-recording-delegate"
  (let* ((delegate (make-test-environment))
         (env (make-recording-environment :delegate delegate)))
    (environment-set env "A" "1")
    (environment-get env "A")
    (expect (= (length (recording-environment-calls env)) 2) :to-be-truthy)
    (expect (= (length (recording-environment-calls delegate)) 0) :to-be-truthy)))

(it "recording-environment-supports-nesting-without-double-recording"
  (let* ((inner-delegate (make-test-environment :initial-values (list "A" "1")))
         (inner (make-recording-environment :delegate inner-delegate))
         (outer (make-recording-environment :delegate inner)))
    (expect (string= (environment-get outer "A") "1") :to-be-truthy)
    (expect (= (length (recording-environment-calls outer)) 1) :to-be-truthy)
    (expect (= (length (recording-environment-calls inner)) 0) :to-be-truthy)
    (expect (= (length (recording-environment-calls inner-delegate)) 0) :to-be-truthy)))

(deftest-reset-recording-clears-history
    "reset-recording-environment-calls-clears-history-and-returns-the-environment"
    (env (make-test-environment))
    (recording-environment-calls reset-recording-environment-calls)
  (environment-set env "A" "1"))

