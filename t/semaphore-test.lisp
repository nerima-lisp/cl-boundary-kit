;;;; t/semaphore-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-semaphore-tracks-available-permits"
  (let ((sem (make-test-semaphore :permits 2)))
    (expect (= 2 (semaphore-available sem)) :to-be-truthy)
    (semaphore-acquire sem)
    (expect (= 1 (semaphore-available sem)) :to-be-truthy)
    (semaphore-release sem)
    (expect (= 2 (semaphore-available sem)) :to-be-truthy)))

(it "test-semaphore-signals-when-no-permits-remain"
  (let ((sem (make-test-semaphore :permits 1)))
    (semaphore-acquire sem)
    (signals error
      (semaphore-acquire sem))))

(it "test-semaphore-release-can-raise-the-permit-count"
  (let ((sem (make-test-semaphore :permits 0)))
    (semaphore-release sem)
    (expect (= 1 (semaphore-available sem)) :to-be-truthy)
    (expect (eq t (semaphore-acquire sem)) :to-be-truthy)))

(it "make-test-semaphore-rejects-invalid-permits"
  (signals error
    (make-test-semaphore :permits -1))
  (signals error
    (make-test-semaphore :permits 1.5d0)))

(it "make-semaphore-wires-injected-collaborators"
  (let* ((events '())
         (sem (make-semaphore
               :acquire-fn (lambda () (push :acquire events))
               :release-fn (lambda () (push :release events))
               :available-fn (lambda () 3))))
    (expect (eq t (semaphore-acquire sem)) :to-be-truthy)
    (expect (eq t (semaphore-release sem)) :to-be-truthy)
    (expect (= 3 (semaphore-available sem)) :to-be-truthy)
    (expect (equal (list :release :acquire) events) :to-be-truthy)))

(it "make-semaphore-rejects-non-function-collaborators"
  (signals error
    (make-semaphore :acquire-fn :bad
                    :release-fn (lambda () t)
                    :available-fn (lambda () 0))))

(it "recording-semaphore-records-operations"
  (let ((sem (make-recording-semaphore :delegate (make-test-semaphore :permits 1))))
    (semaphore-acquire sem)
    (semaphore-available sem)
    (semaphore-release sem)
    (expect (equal (recording-semaphore-calls sem)
                   (list (boundary-call-plist :acquire '() :result t)
                         (boundary-call-plist :available '() :result 0)
                         (boundary-call-plist :release '() :result t))) :to-be-truthy)))

(it "make-recording-semaphore-rejects-a-non-semaphore-delegate"
  (signals error
    (make-recording-semaphore :delegate :bad)))

(it "recording-semaphore-calls-signals-for-unsupported-semaphore-types"
  (signals error
    (recording-semaphore-calls (make-test-semaphore))))

(it "reset-recording-semaphore-calls-clears-history-and-returns-the-semaphore"
  (let ((sem (make-recording-semaphore)))
    (semaphore-available sem)
    (expect (= 1 (length (recording-semaphore-calls sem))) :to-be-truthy)
    (expect (eq sem (reset-recording-semaphore-calls sem)) :to-be-truthy)
    (expect (null (recording-semaphore-calls sem)) :to-be-truthy)))

(it "reset-recording-semaphore-calls-signals-for-unsupported-semaphore-types"
  (signals error
    (reset-recording-semaphore-calls (make-test-semaphore))))

(it "call-with-semaphore-acquires-runs-and-releases"
  (let ((sem (make-test-semaphore :permits 1)))
    (expect (eq :result (call-with-semaphore sem (lambda () :result))) :to-be-truthy)
    (expect (= 1 (semaphore-available sem)) :to-be-truthy)))

(it "call-with-semaphore-releases-even-when-the-thunk-signals"
  (let ((sem (make-test-semaphore :permits 1)))
    (signals error
      (call-with-semaphore sem (lambda () (error "boom"))))
    (expect (= 1 (semaphore-available sem)) :to-be-truthy)))

(it "call-with-semaphore-rejects-a-non-function-thunk"
  (signals error
    (call-with-semaphore (make-test-semaphore) :bad)))
