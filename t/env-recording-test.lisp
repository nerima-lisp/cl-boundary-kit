;;;; t/env-recording-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "recording environment delegation"
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
          (expect calls :to-be-null)))))

  (it "make-recording-environment-rejects-non-environment-delegate"
    (signals error
      (make-recording-environment :delegate :bad)))

  (it "make-recording-environment-defaults-to-a-native-delegate"
    (let ((env (make-recording-environment)))
      (expect (environment-get env "PATH" "missing")
              :to-equal (environment-get (make-environment) "PATH" "missing")))))

(describe "recording environment call history"
  (it-each ((recording-environment-calls)
            (reset-recording-environment-calls))
      "~A signals for unsupported environment types"
      (operation)
    (expect (lambda () (funcall operation (make-environment))) :to-throw "Unsupported environment type"))

  (it "recording-environment-does-not-double-record-a-self-recording-delegate"
    (let* ((delegate (make-test-environment))
           (env (make-recording-environment :delegate delegate)))
      (environment-set env "A" "1")
      (environment-get env "A")
      (expect (recording-environment-calls env) :to-have-length 2)
      (expect (recording-environment-calls delegate) :to-have-length 0)))

  (it "recording-environment-supports-nesting-without-double-recording"
    (let* ((inner-delegate (make-test-environment :initial-values (list "A" "1")))
           (inner (make-recording-environment :delegate inner-delegate))
           (outer (make-recording-environment :delegate inner)))
      (expect (environment-get outer "A") :to-equal "1")
      (expect (recording-environment-calls outer) :to-have-length 1)
      (expect (recording-environment-calls inner) :to-have-length 0)
      (expect (recording-environment-calls inner-delegate) :to-have-length 0)))

  (deftest-reset-recording-clears-history
      "reset-recording-environment-calls-clears-history-and-returns-the-environment"
      (env (make-test-environment))
      (recording-environment-calls reset-recording-environment-calls)
    (environment-set env "A" "1")))
