;;;; t/env-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test environment"
  (it "test-environment-reads-and-writes"
    (let ((env (make-test-environment :initial-values '(("A" . "1")
                                                         ("EMPTY" . nil)))))
      (with-soft-assertions
        (expect (environment-get env "A") :to-equal "1")
        (expect (environment-present-p env "A") :to-be-truthy)
        (expect (environment-set env "B" "2") :to-equal "2")
        (expect (environment-get env "B") :to-equal "2")
        (expect (environment-present-p env "B") :to-be-truthy)
        (expect (environment-get env "EMPTY" "fallback") :to-be-null)
        (expect (environment-present-p env "EMPTY") :to-be-truthy)
        (expect (environment-present-p env "MISSING") :to-be-null)
        (expect (environment-get env "MISSING" "fallback") :to-equal "fallback")
        (expect (some (lambda (pair) (equal pair '("A" . "1")))
                  (environment-list env)) :to-be-truthy))))

  (it "test-environment-accepts-plist-initial-values"
    (let ((env (make-test-environment :initial-values '("A" "1" "EMPTY" nil))))
      (with-soft-assertions
        (expect (environment-get env "A") :to-equal "1")
        (expect (environment-present-p env "A") :to-be-truthy)
        (expect (environment-get env "EMPTY" "fallback") :to-be-null)
        (expect (environment-present-p env "EMPTY") :to-be-truthy)
        (let ((entries (environment-list env)))
          (expect entries :to-equal '(("A" . "1") ("EMPTY" . nil)))
          (expect (some (lambda (pair) (equal pair '("A" . "1"))) entries) :to-be-truthy)
          (expect (some (lambda (pair) (equal pair '("EMPTY" . nil))) entries) :to-be-truthy)))))

  (it "test-environment-list-is-sorted-by-name"
    (let ((env (make-test-environment :initial-values '(("Z" . "last")
                                                         ("A" . "first")
                                                         ("M" . nil)))))
      (expect (environment-list env)
              :to-equal '(("A" . "first")
                          ("M" . nil)
                          ("Z" . "last")))))

  (it "test-environment-rejects-odd-initial-values"
    (signals error
      (make-test-environment :initial-values '("A" "1" "BROKEN"))))

  (it "test-environment-unset-removes-a-binding-and-reports-presence"
    (let ((env (make-test-environment :initial-values '(("HOME" . "/tmp")))))
      (expect (environment-present-p env "HOME") :to-be t)
      (expect (environment-unset env "HOME") :to-be t)
      (expect (environment-present-p env "HOME") :to-be-null)
      ;; Unsetting an absent variable reports NIL.
      (expect (environment-unset env "HOME") :to-be-null))))

(describe "recording environment"
  (it "recording-environment-records-unset-calls"
    (let ((env (make-recording-environment
                :delegate (make-test-environment :initial-values '(("HOME" . "/tmp"))))))
      (environment-unset env "HOME")
      (expect (recording-environment-calls env)
              :to-have-recorded-calls
              (list (cl-boundary-kit:boundary-call-plist :unset (list "HOME") :result t))))))

(describe "native environment"
  (it "native-environment-unset-is-unsupported-without-an-unset-fn"
    (signals-unsupported-boundary-operation
        (cl-boundary-kit:environment-unset "native environment mutation is unavailable")
      (environment-unset (make-environment :unset-fn nil) "ANY")))

  (it "native-environment-unset-uses-an-injected-unset-fn"
    (let* ((removed '())
           (env (make-environment
                 :unset-fn (lambda (name) (push name removed) t))))
      (expect (environment-unset env "X") :to-be t)
      (expect removed :to-equal '("X"))))

  (it "make-environment-rejects-an-odd-length-option-list"
    (expect (lambda () (make-environment :get-fn)) :to-throw "Option list ended after")))

(describe "call-with-environment-variable"
  (it "call-with-environment-variable-restores-a-previously-present-value"
    (let ((env (make-test-environment :initial-values '(("MODE" . "prod")))))
      (let ((seen (call-with-environment-variable env "MODE" "test"
                                                  (lambda () (environment-get env "MODE")))))
        (expect seen :to-equal "test"))
      ;; Restored to the previous value.
      (expect (environment-get env "MODE") :to-equal "prod")))

  (it "call-with-environment-variable-unsets-a-previously-absent-value"
    (let ((env (make-test-environment)))
      (call-with-environment-variable env "TEMP" "x" (lambda () :ok))
      (expect (environment-present-p env "TEMP") :to-be-null)))

  (it "call-with-environment-variable-restores-even-when-the-thunk-signals"
    (let ((env (make-test-environment :initial-values '(("MODE" . "prod")))))
      (signals error
        (call-with-environment-variable env "MODE" "test" (lambda () (error "boom"))))
      (expect (environment-get env "MODE") :to-equal "prod")))

  (it "call-with-environment-variable-rejects-a-non-function-thunk"
    (signals error
      (call-with-environment-variable (make-test-environment) "X" "y" :bad))))

