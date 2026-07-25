;;;; t/lock-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-lock-invokes-its-injected-collaborators"
  (let* ((events '())
         (lock (make-lock :acquire-fn (lambda () (push :acquire events))
                          :release-fn (lambda () (push :release events)))))
    (expect (eq t (lock-acquire lock)) :to-be-truthy)
    (expect (eq t (lock-release lock)) :to-be-truthy)
    (expect (equal (list :release :acquire) events) :to-be-truthy)))

(it "make-lock-rejects-non-function-collaborators"
  (signals error
    (make-lock :acquire-fn :bad :release-fn (lambda () t))))

(it "test-lock-tracks-held-state"
  (let ((lock (make-test-lock)))
    (expect (null (test-lock-held-p lock)) :to-be-truthy)
    (lock-acquire lock)
    (expect (eq t (test-lock-held-p lock)) :to-be-truthy)
    (lock-release lock)
    (expect (null (test-lock-held-p lock)) :to-be-truthy)))

(it "non-reentrant-test-lock-signals-on-self-deadlock-and-underflow"
  (let ((lock (make-test-lock)))
    (lock-acquire lock)
    (signals error
      (lock-acquire lock))
    (lock-release lock)
    (signals error
      (lock-release lock))))

(it "reentrant-test-lock-counts-acquire-depth"
  (let ((lock (make-test-lock :reentrant t)))
    (lock-acquire lock)
    (lock-acquire lock)
    (expect (eq t (test-lock-held-p lock)) :to-be-truthy)
    (lock-release lock)
    (expect (eq t (test-lock-held-p lock)) :to-be-truthy)
    (lock-release lock)
    (expect (null (test-lock-held-p lock)) :to-be-truthy)))

(it "test-lock-held-p-signals-for-unsupported-lock-types"
  (signals error
    (test-lock-held-p (make-recording-lock))))

(it "recording-lock-records-acquire-and-release"
  (let ((lock (make-recording-lock)))
    (lock-acquire lock)
    (lock-release lock)
    (expect (equal (recording-lock-calls lock)
                   (list (boundary-call-plist :acquire '() :result t)
                         (boundary-call-plist :release '() :result t))) :to-be-truthy)))

(it "make-recording-lock-rejects-a-non-lock-delegate"
  (signals error
    (make-recording-lock :delegate :bad)))

(it-each ((recording-lock-calls)
          (reset-recording-lock-calls))
    "~A signals for unsupported lock types"
    (operation)
  (expect (lambda () (funcall operation (make-test-lock)))
          :to-signal-message-containing "Unsupported lock type"))

(deftest-reset-recording-clears-history
    "reset-recording-lock-calls-clears-history-and-returns-the-lock"
    (lock (make-recording-lock))
    (recording-lock-calls reset-recording-lock-calls)
  (lock-acquire lock))

(it "call-with-lock-acquires-runs-and-releases"
  (let ((lock (make-recording-lock)))
    (expect (eq :result (call-with-lock lock (lambda () :result))) :to-be-truthy)
    (expect (equal (list :acquire :release)
                   (recorded-call-operations (recording-lock-calls lock))) :to-be-truthy)))

(it "call-with-lock-releases-even-when-the-thunk-signals"
  (let ((lock (make-test-lock)))
    (signals error
      (call-with-lock lock (lambda () (error "boom"))))
    ;; The lock was released despite the error, so it can be acquired again.
    (expect (null (test-lock-held-p lock)) :to-be-truthy)
    (expect (eq t (lock-acquire lock)) :to-be-truthy)))

(it "call-with-lock-rejects-a-non-function-thunk"
  (signals error
    (call-with-lock (make-test-lock) :bad)))
