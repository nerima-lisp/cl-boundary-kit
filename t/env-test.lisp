;;;; t/env-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-environment-reads-and-writes"
  (let ((env (make-test-environment :initial-values '(("A" . "1")
                                                       ("EMPTY" . nil)))))
    (expect (string= (environment-get env "A") "1") :to-be-truthy)
    (expect (environment-present-p env "A") :to-be-truthy)
    (expect (string= (environment-set env "B" "2") "2") :to-be-truthy)
    (expect (string= (environment-get env "B") "2") :to-be-truthy)
    (expect (environment-present-p env "B") :to-be-truthy)
    (expect (null (environment-get env "EMPTY" "fallback")) :to-be-truthy)
    (expect (environment-present-p env "EMPTY") :to-be-truthy)
    (expect (null (environment-present-p env "MISSING")) :to-be-truthy)
    (expect (string= (environment-get env "MISSING" "fallback") "fallback") :to-be-truthy)
    (expect (some (lambda (pair) (equal pair '("A" . "1")))
              (environment-list env)) :to-be-truthy)))

(it "test-environment-accepts-plist-initial-values"
  (let ((env (make-test-environment :initial-values '("A" "1" "EMPTY" nil))))
    (expect (string= (environment-get env "A") "1") :to-be-truthy)
    (expect (environment-present-p env "A") :to-be-truthy)
    (expect (null (environment-get env "EMPTY" "fallback")) :to-be-truthy)
    (expect (environment-present-p env "EMPTY") :to-be-truthy)
    (let ((entries (environment-list env)))
      (expect (equal '(("A" . "1") ("EMPTY" . nil)) entries) :to-be-truthy)
      (expect (some (lambda (pair) (equal pair '("A" . "1"))) entries) :to-be-truthy)
      (expect (some (lambda (pair) (equal pair '("EMPTY" . nil))) entries) :to-be-truthy))))

(it "test-environment-list-is-sorted-by-name"
  (let ((env (make-test-environment :initial-values '(("Z" . "last")
                                                       ("A" . "first")
                                                       ("M" . nil)))))
    (expect (equal '(("A" . "first")
                 ("M" . nil)
                 ("Z" . "last"))
               (environment-list env)) :to-be-truthy)))

(it "test-environment-rejects-odd-initial-values"
  (signals error
    (make-test-environment :initial-values '("A" "1" "BROKEN"))))

(it "test-environment-unset-removes-a-binding-and-reports-presence"
  (let ((env (make-test-environment :initial-values '(("HOME" . "/tmp")))))
    (expect (eq t (environment-present-p env "HOME")) :to-be-truthy)
    (expect (eq t (environment-unset env "HOME")) :to-be-truthy)
    (expect (null (environment-present-p env "HOME")) :to-be-truthy)
    ;; Unsetting an absent variable reports NIL.
    (expect (null (environment-unset env "HOME")) :to-be-truthy)))

(it "recording-environment-records-unset-calls"
  (let ((env (make-recording-environment
              :delegate (make-test-environment :initial-values '(("HOME" . "/tmp"))))))
    (environment-unset env "HOME")
    (expect (equal (recording-environment-calls env)
                   (list (cl-boundary-kit:boundary-call-plist :unset (list "HOME") :result t)))
            :to-be-truthy)))

(it "native-environment-unset-is-unsupported-without-an-unset-fn"
  (signals-unsupported-boundary-operation
      (cl-boundary-kit:environment-unset "native environment mutation is unavailable")
    (environment-unset (make-environment) "ANY")))

(it "native-environment-unset-uses-an-injected-unset-fn"
  (let* ((removed '())
         (env (make-environment
               :unset-fn (lambda (name) (push name removed) t))))
    (expect (eq t (environment-unset env "X")) :to-be-truthy)
    (expect (equal '("X") removed) :to-be-truthy)))

(it "call-with-environment-variable-restores-a-previously-present-value"
  (let ((env (make-test-environment :initial-values '(("MODE" . "prod")))))
    (let ((seen (call-with-environment-variable env "MODE" "test"
                                                (lambda () (environment-get env "MODE")))))
      (expect (string= "test" seen) :to-be-truthy))
    ;; Restored to the previous value.
    (expect (string= "prod" (environment-get env "MODE")) :to-be-truthy)))

(it "call-with-environment-variable-unsets-a-previously-absent-value"
  (let ((env (make-test-environment)))
    (call-with-environment-variable env "TEMP" "x" (lambda () :ok))
    (expect (null (environment-present-p env "TEMP")) :to-be-truthy)))

(it "call-with-environment-variable-restores-even-when-the-thunk-signals"
  (let ((env (make-test-environment :initial-values '(("MODE" . "prod")))))
    (signals error
      (call-with-environment-variable env "MODE" "test" (lambda () (error "boom"))))
    (expect (string= "prod" (environment-get env "MODE")) :to-be-truthy)))

(it "call-with-environment-variable-rejects-a-non-function-thunk"
  (signals error
    (call-with-environment-variable (make-test-environment) "X" "y" :bad)))

(it "make-environment-rejects-an-odd-length-option-list"
  (signals-error-message-contains "Option list ended after"
    (make-environment :get-fn)))
