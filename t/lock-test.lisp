;;;; t/lock-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "lock"
  (it "make-lock-invokes-its-injected-collaborators"
    (let* ((events '())
           (lock (make-lock :acquire-fn (lambda () (push :acquire events))
                            :release-fn (lambda () (push :release events)))))
      (expect (lock-acquire lock) :to-be t)
      (expect (lock-release lock) :to-be t)
      (expect events :to-equal (list :release :acquire))))

  (it "make-lock-rejects-non-function-collaborators"
    (signals error
      (make-lock :acquire-fn :bad :release-fn (lambda () t)))))

(describe "test lock"
  (it "test-lock-tracks-held-state"
    (let ((lock (make-test-lock)))
      (expect (test-lock-held-p lock) :to-be-null)
      (lock-acquire lock)
      (expect (test-lock-held-p lock) :to-be t)
      (lock-release lock)
      (expect (test-lock-held-p lock) :to-be-null)))

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
      (expect (test-lock-held-p lock) :to-be t)
      (lock-release lock)
      (expect (test-lock-held-p lock) :to-be t)
      (lock-release lock)
      (expect (test-lock-held-p lock) :to-be-null)))

  (it "test-lock-held-p-signals-for-unsupported-lock-types"
    (signals error
      (test-lock-held-p (make-recording-lock)))))

(describe "recording lock"
  (it "recording-lock-records-acquire-and-release"
    (let ((lock (make-recording-lock)))
      (lock-acquire lock)
      (lock-release lock)
      (expect (recording-lock-calls lock)
              :to-have-recorded-calls (list (boundary-call-plist :acquire '() :result t)
                                            (boundary-call-plist :release '() :result t)))))

  (it "make-recording-lock-rejects-a-non-lock-delegate"
    (signals error
      (make-recording-lock :delegate :bad)))

  (it-each ((recording-lock-calls)
            (reset-recording-lock-calls))
      "~A signals for unsupported lock types"
      (operation)
    (expect (lambda () (funcall operation (make-test-lock))) :to-throw "Unsupported lock type"))

  (deftest-reset-recording-clears-history
      "reset-recording-lock-calls-clears-history-and-returns-the-lock"
      (lock (make-recording-lock))
      (recording-lock-calls reset-recording-lock-calls)
    (lock-acquire lock)))

(describe "call-with-lock"
  (it "call-with-lock-acquires-runs-and-releases"
    (let ((lock (make-recording-lock)))
      (expect (call-with-lock lock (lambda () :result)) :to-be :result)
      (expect (recording-lock-calls lock) :to-have-recorded-operations (list :acquire :release))))

  (it "call-with-lock-releases-even-when-the-thunk-signals"
    (let ((lock (make-test-lock)))
      (signals error
        (call-with-lock lock (lambda () (error "boom"))))
      ;; The lock was released despite the error, so it can be acquired again.
      (expect (test-lock-held-p lock) :to-be-null)
      (expect (lock-acquire lock) :to-be t)))

  (it "call-with-lock-rejects-a-non-function-thunk"
    (signals error
      (call-with-lock (make-test-lock) :bad))))
