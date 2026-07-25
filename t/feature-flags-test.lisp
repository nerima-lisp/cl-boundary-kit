;;;; t/feature-flags-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-feature-flags-reports-enabled-and-disabled-flags"
  (let ((flags (make-test-feature-flags :enabled '(:a "b"))))
    (expect (eq t (feature-enabled-p flags :a)) :to-be-truthy)
    (expect (eq t (feature-enabled-p flags "b")) :to-be-truthy)
    (expect (null (feature-enabled-p flags :c)) :to-be-truthy)))

(it "test-feature-flags-defaults-to-all-off"
  (let ((flags (make-test-feature-flags)))
    (expect (null (feature-enabled-p flags :anything)) :to-be-truthy)))

(it "feature-enabled-p-rejects-an-invalid-name"
  (signals error
    (feature-enabled-p (make-test-feature-flags) nil)))

(it "make-test-feature-flags-rejects-a-non-list-enabled-value"
  (signals error
    (make-test-feature-flags :enabled :not-a-list)))

(it "make-feature-flags-wires-an-injected-enabled-fn"
  (let ((flags (make-feature-flags
                :enabled-fn (lambda (name) (eq name :on)))))
    (expect (eq t (feature-enabled-p flags :on)) :to-be-truthy)
    (expect (null (feature-enabled-p flags :off)) :to-be-truthy)))

(it "feature-enabled-p-coerces-a-truthy-backend-result-to-t"
  (let ((flags (make-feature-flags :enabled-fn (lambda (name) (declare (ignore name)) 42))))
    (expect (eq t (feature-enabled-p flags :x)) :to-be-truthy)))

(it "make-feature-flags-rejects-a-non-function-enabled-fn"
  (signals error
    (make-feature-flags :enabled-fn :bad)))

(it "recording-feature-flags-records-checks"
  (let* ((delegate (make-test-feature-flags :enabled '(:a)))
         (flags (make-recording-feature-flags :delegate delegate)))
    (feature-enabled-p flags :a)
    (feature-enabled-p flags :b)
    (expect (equal (recording-feature-flag-calls flags)
                   (list (boundary-call-plist :enabled-p (list :a) :result t)
                         (boundary-call-plist :enabled-p (list :b) :result nil))) :to-be-truthy)))

(it "make-recording-feature-flags-rejects-a-non-feature-flags-delegate"
  (signals error
    (make-recording-feature-flags :delegate :bad)))

(it-each ((recording-feature-flag-calls)
          (reset-recording-feature-flag-calls))
    "~A signals for unsupported feature-flags types"
    (operation)
  (expect (lambda () (funcall operation (make-test-feature-flags)))
          :to-signal-message-containing "Unsupported feature flags type"))

(it "reset-recording-feature-flag-calls-clears-history-and-returns-the-flags"
  (let ((flags (make-recording-feature-flags)))
    (feature-enabled-p flags :a)
    (expect (= 1 (length (recording-feature-flag-calls flags))) :to-be-truthy)
    (expect (eq flags (reset-recording-feature-flag-calls flags)) :to-be-truthy)
    (expect (null (recording-feature-flag-calls flags)) :to-be-truthy)))

(it "test-feature-flags-enumerates-enabled-flags-sorted"
  ;; Sorted by PRINC-TO-STRING under STRING<, so uppercased keyword names
  ;; (:BETA, :GAMMA) sort before the lowercase string "alpha".
  (let ((flags (make-test-feature-flags :enabled '(:beta "alpha" :gamma))))
    (expect (equal (list :beta :gamma "alpha") (feature-flags-enabled flags)) :to-be-truthy))
  (expect (null (feature-flags-enabled (make-test-feature-flags))) :to-be-truthy))

(it "native-feature-flags-enabled-is-unsupported-without-an-enabled-list-fn"
  (signals cl-boundary-kit:unsupported-boundary-operation
    (feature-flags-enabled (make-feature-flags :enabled-fn (lambda (n) (declare (ignore n)) nil)))))

(it "native-feature-flags-enabled-uses-an-injected-list-fn"
  (let ((flags (make-feature-flags :enabled-fn (lambda (n) (declare (ignore n)) t)
                                   :enabled-list-fn (lambda () (list :a :b)))))
    (expect (equal (list :a :b) (feature-flags-enabled flags)) :to-be-truthy)))

(it "recording-feature-flags-records-the-enumeration"
  (let ((flags (make-recording-feature-flags
                :delegate (make-test-feature-flags :enabled '(:a)))))
    (feature-flags-enabled flags)
    (expect (equal (list (boundary-call-plist :enabled-list '() :result (list :a)))
                   (recording-feature-flag-calls flags)) :to-be-truthy)))

(it "call-if-feature-enabled-picks-the-branch-by-the-flag"
  (let ((flags (make-test-feature-flags :enabled '(:new-path))))
    (expect (eq :new (call-if-feature-enabled flags :new-path (lambda () :new))) :to-be-truthy)
    ;; Off -> falls back to the disabled thunk.
    (expect (eq :old (call-if-feature-enabled flags :other (lambda () :new) (lambda () :old))) :to-be-truthy)
    ;; Off, no disabled thunk -> NIL.
    (expect (null (call-if-feature-enabled flags :other (lambda () :new))) :to-be-truthy)))

(it "call-if-feature-enabled-rejects-non-function-thunks"
  (signals error
    (call-if-feature-enabled (make-test-feature-flags) :a :bad))
  (signals error
    (call-if-feature-enabled (make-test-feature-flags) :a (lambda () :ok) :bad)))
