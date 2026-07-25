;;;; t/system-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-system-boundary-invokes-its-exit-function-with-the-code"
  (let* ((requested '())
         (system (make-system-boundary
                  :exit-fn (lambda (code) (push code requested) :exited))))
    (expect (eq :exited (system-exit system 3)) :to-be-truthy)
    (expect (equal '(3) requested) :to-be-truthy)))

(it "make-system-boundary-defaults-the-exit-code-to-zero"
  (let* ((requested '())
         (system (make-system-boundary
                  :exit-fn (lambda (code) (push code requested)))))
    (system-exit system)
    (expect (equal '(0) requested) :to-be-truthy)))

(it "make-system-boundary-rejects-a-non-function-exit-fn"
  (signals error
    (make-system-boundary :exit-fn :bad)))

(it "test-system-boundary-records-exit-codes-without-terminating"
  (let ((system (make-test-system-boundary)))
    (expect (= 0 (system-exit system)) :to-be-truthy)
    (expect (= 2 (system-exit system 2)) :to-be-truthy)
    (expect (equal (list 0 2) (test-system-exit-codes system)) :to-be-truthy)))

(it "system-exit-rejects-negative-and-non-integer-codes"
  (let ((system (make-test-system-boundary)))
    (signals error
      (system-exit system -1))
    (signals error
      (system-exit system 1.5d0))))

(it "test-system-exit-codes-signals-for-unsupported-system-types"
  (signals error
    (test-system-exit-codes (make-recording-system-boundary))))

(it "recording-system-boundary-records-exit-requests"
  (let ((system (make-recording-system-boundary)))
    (expect (= 0 (system-exit system)) :to-be-truthy)
    (expect (= 1 (system-exit system 1)) :to-be-truthy)
    (expect (equal (recording-system-calls system)
                   (list (boundary-call-plist :exit (list 0) :result 0)
                         (boundary-call-plist :exit (list 1) :result 1))) :to-be-truthy)))

(it "make-recording-system-boundary-rejects-a-non-system-delegate"
  (signals error
    (make-recording-system-boundary :delegate :bad)))

(it-each ((recording-system-calls)
          (reset-recording-system-calls))
    "~A signals for unsupported system types"
    (operation)
  (expect (lambda () (funcall operation (make-test-system-boundary)))
          :to-signal-message-containing "Unsupported system boundary type"))

(it "reset-recording-system-calls-clears-history-and-returns-the-system"
  (let ((system (make-recording-system-boundary)))
    (system-exit system 0)
    (expect (= 1 (length (recording-system-calls system))) :to-be-truthy)
    (expect (eq system (reset-recording-system-calls system)) :to-be-truthy)
    (expect (null (recording-system-calls system)) :to-be-truthy)))

