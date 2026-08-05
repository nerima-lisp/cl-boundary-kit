;;;; t/feature-flags-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test feature flags"
  (it "test-feature-flags-reports-enabled-and-disabled-flags"
    (let ((flags (make-test-feature-flags :enabled '(:a "b"))))
      (expect (feature-enabled-p flags :a) :to-be t)
      (expect (feature-enabled-p flags "b") :to-be t)
      (expect (feature-enabled-p flags :c) :to-be-null)))

  (it "test-feature-flags-defaults-to-all-off"
    (let ((flags (make-test-feature-flags)))
      (expect (feature-enabled-p flags :anything) :to-be-null)))

  (it "feature-enabled-p-rejects-an-invalid-name"
    (signals error
      (feature-enabled-p (make-test-feature-flags) nil)))

  (it "make-test-feature-flags-rejects-a-non-list-enabled-value"
    (signals error
      (make-test-feature-flags :enabled :not-a-list)))

  (it "test-feature-flags-enumerates-enabled-flags-sorted"
    ;; Sorted by PRINC-TO-STRING under STRING<, so uppercased keyword names
    ;; (:BETA, :GAMMA) sort before the lowercase string "alpha".
    (let ((flags (make-test-feature-flags :enabled '(:beta "alpha" :gamma))))
      (expect (feature-flags-enabled flags) :to-equal (list :beta :gamma "alpha")))
    (expect (feature-flags-enabled (make-test-feature-flags)) :to-be-null)))

(describe "native feature flags"
  (it "make-feature-flags-wires-an-injected-enabled-fn"
    (let ((flags (make-feature-flags
                  :enabled-fn (lambda (name) (eq name :on)))))
      (expect (feature-enabled-p flags :on) :to-be t)
      (expect (feature-enabled-p flags :off) :to-be-null)))

  (it "feature-enabled-p-coerces-a-truthy-backend-result-to-t"
    (let ((flags (make-feature-flags :enabled-fn (lambda (name) (declare (ignore name)) 42))))
      (expect (feature-enabled-p flags :x) :to-be t)))

  (it "make-feature-flags-rejects-a-non-function-enabled-fn"
    (signals error
      (make-feature-flags :enabled-fn :bad)))

  (it "native-feature-flags-enabled-is-unsupported-without-an-enabled-list-fn"
    (signals cl-boundary-kit:unsupported-boundary-operation
      (feature-flags-enabled (make-feature-flags :enabled-fn (lambda (n) (declare (ignore n)) nil)))))

  (it "native-feature-flags-enabled-uses-an-injected-list-fn"
    (let ((flags (make-feature-flags :enabled-fn (lambda (n) (declare (ignore n)) t)
                                     :enabled-list-fn (lambda () (list :a :b)))))
      (expect (feature-flags-enabled flags) :to-equal (list :a :b)))))

(describe "recording feature flags"
  (it "recording-feature-flags-records-checks"
    (let* ((delegate (make-test-feature-flags :enabled '(:a)))
           (flags (make-recording-feature-flags :delegate delegate)))
      (feature-enabled-p flags :a)
      (feature-enabled-p flags :b)
      (expect (recording-feature-flag-calls flags)
              :to-have-recorded-calls (list (boundary-call-plist :enabled-p (list :a) :result t)
                                            (boundary-call-plist :enabled-p (list :b) :result nil)))))

  (it "make-recording-feature-flags-rejects-a-non-feature-flags-delegate"
    (signals error
      (make-recording-feature-flags :delegate :bad)))

  (it-each ((recording-feature-flag-calls)
            (reset-recording-feature-flag-calls))
      "~A signals for unsupported feature-flags types"
      (operation)
    (expect (lambda () (funcall operation (make-test-feature-flags))) :to-throw "Unsupported feature flags type"))

  (deftest-reset-recording-clears-history
      "reset-recording-feature-flag-calls-clears-history-and-returns-the-flags"
      (flags (make-recording-feature-flags))
      (recording-feature-flag-calls reset-recording-feature-flag-calls)
    (feature-enabled-p flags :a))

  (it "recording-feature-flags-records-the-enumeration"
    (let ((flags (make-recording-feature-flags
                  :delegate (make-test-feature-flags :enabled '(:a)))))
      (feature-flags-enabled flags)
      (expect (recording-feature-flag-calls flags)
              :to-have-recorded-calls
              (list (boundary-call-plist :enabled-list '() :result (list :a)))))))

(describe "call-if-feature-enabled"
  (it "call-if-feature-enabled-picks-the-branch-by-the-flag"
    (let ((flags (make-test-feature-flags :enabled '(:new-path))))
      (expect (call-if-feature-enabled flags :new-path (lambda () :new)) :to-be :new)
      ;; Off -> falls back to the disabled thunk.
      (expect (call-if-feature-enabled flags :other (lambda () :new) (lambda () :old)) :to-be :old)
      ;; Off, no disabled thunk -> NIL.
      (expect (call-if-feature-enabled flags :other (lambda () :new)) :to-be-null)))

  (it "call-if-feature-enabled-rejects-non-function-thunks"
    (signals error
      (call-if-feature-enabled (make-test-feature-flags) :a :bad))
    (signals error
      (call-if-feature-enabled (make-test-feature-flags) :a (lambda () :ok) :bad))))

