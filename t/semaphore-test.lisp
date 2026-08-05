;;;; t/semaphore-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test-semaphore"
  (it "test-semaphore-tracks-available-permits"
    (let ((sem (make-test-semaphore :permits 2)))
      (expect (semaphore-available sem) :to-be 2)
      (semaphore-acquire sem)
      (expect (semaphore-available sem) :to-be 1)
      (semaphore-release sem)
      (expect (semaphore-available sem) :to-be 2)))

  (it "test-semaphore-signals-when-no-permits-remain"
    (let ((sem (make-test-semaphore :permits 1)))
      (semaphore-acquire sem)
      (signals error
        (semaphore-acquire sem))))

  (it "test-semaphore-release-can-raise-the-permit-count"
    (let ((sem (make-test-semaphore :permits 0)))
      (semaphore-release sem)
      (expect (semaphore-available sem) :to-be 1)
      (expect (semaphore-acquire sem) :to-be t)))

  (it "make-test-semaphore-rejects-invalid-permits"
    (signals error
      (make-test-semaphore :permits -1))
    (signals error
      (make-test-semaphore :permits 1.5d0))))

(describe "make-semaphore"
  (it "make-semaphore-wires-injected-collaborators"
    (let* ((events '())
           (sem (make-semaphore
                 :acquire-fn (lambda () (push :acquire events))
                 :release-fn (lambda () (push :release events))
                 :available-fn (lambda () 3))))
      (expect (semaphore-acquire sem) :to-be t)
      (expect (semaphore-release sem) :to-be t)
      (expect (semaphore-available sem) :to-be 3)
      (expect events :to-equal (list :release :acquire))))

  (it "make-semaphore-rejects-non-function-collaborators"
    (signals error
      (make-semaphore :acquire-fn :bad
                      :release-fn (lambda () t)
                      :available-fn (lambda () 0)))))

(describe "recording-semaphore"
  (it "recording-semaphore-records-operations"
    (let ((sem (make-recording-semaphore :delegate (make-test-semaphore :permits 1))))
      (semaphore-acquire sem)
      (semaphore-available sem)
      (semaphore-release sem)
      (expect (recording-semaphore-calls sem) :to-have-recorded-calls (list (boundary-call-plist :acquire '() :result t)
                           (boundary-call-plist :available '() :result 0)
                           (boundary-call-plist :release '() :result t)))))

  (it "make-recording-semaphore-rejects-a-non-semaphore-delegate"
    (signals error
      (make-recording-semaphore :delegate :bad)))

  (it-each ((recording-semaphore-calls)
            (reset-recording-semaphore-calls))
      "~A signals for unsupported semaphore types"
      (operation)
    (expect (lambda () (funcall operation (make-test-semaphore))) :to-throw "Unsupported semaphore type"))

  (deftest-reset-recording-clears-history
      "reset-recording-semaphore-calls-clears-history-and-returns-the-semaphore"
      (sem (make-recording-semaphore))
      (recording-semaphore-calls reset-recording-semaphore-calls)
    (semaphore-available sem)))

(describe "call-with-semaphore"
  (it "call-with-semaphore-acquires-runs-and-releases"
    (let ((sem (make-test-semaphore :permits 1)))
      (expect (call-with-semaphore sem (lambda () :result)) :to-be :result)
      (expect (semaphore-available sem) :to-be 1)))

  (it "call-with-semaphore-releases-even-when-the-thunk-signals"
    (let ((sem (make-test-semaphore :permits 1)))
      (signals error
        (call-with-semaphore sem (lambda () (error "boom"))))
      (expect (semaphore-available sem) :to-be 1)))

  (it "call-with-semaphore-rejects-a-non-function-thunk"
    (signals error
      (call-with-semaphore (make-test-semaphore) :bad))))
