;;;; t/sleeper-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-sleeper-invokes-its-sleep-function-and-returns-the-seconds"
  (let* ((recorded '())
         (sleeper (make-sleeper :sleep-fn (lambda (seconds) (push seconds recorded)))))
    (expect (= 3 (sleeper-sleep sleeper 3)) :to-be-truthy)
    (expect (equal '(3) recorded) :to-be-truthy)))

(it "make-sleeper-rejects-a-non-function-sleep-fn"
  (signals error
    (make-sleeper :sleep-fn :bad)))

(it "test-sleeper-returns-the-requested-seconds-without-blocking"
  (let ((sleeper (make-test-sleeper)))
    (expect (= 5 (sleeper-sleep sleeper 5)) :to-be-truthy)
    (expect (= 0.5d0 (sleeper-sleep sleeper 0.5d0)) :to-be-truthy)))

(it "sleeper-sleep-rejects-negative-and-non-real-durations"
  (let ((sleeper (make-test-sleeper)))
    (signals error
      (sleeper-sleep sleeper -1))
    (signals error
      (sleeper-sleep sleeper :nope))))

(it "recording-sleeper-records-requested-durations"
  (let ((sleeper (make-recording-sleeper)))
    (expect (= 5 (sleeper-sleep sleeper 5)) :to-be-truthy)
    (expect (= 0.25d0 (sleeper-sleep sleeper 0.25d0)) :to-be-truthy)
    (expect (equal (recording-sleeper-calls sleeper)
                   (list (boundary-call-plist :sleep (list 5) :result 5)
                         (boundary-call-plist :sleep (list 0.25d0) :result 0.25d0))) :to-be-truthy)))

(it "make-recording-sleeper-rejects-a-non-sleeper-delegate"
  (signals error
    (make-recording-sleeper :delegate :bad)))

(it "recording-sleeper-calls-signals-for-unsupported-sleeper-types"
  (signals error
    (recording-sleeper-calls (make-test-sleeper))))

(it "reset-recording-sleeper-calls-clears-history-and-returns-the-sleeper"
  (let ((sleeper (make-recording-sleeper)))
    (sleeper-sleep sleeper 1)
    (expect (= 1 (length (recording-sleeper-calls sleeper))) :to-be-truthy)
    (expect (eq sleeper (reset-recording-sleeper-calls sleeper)) :to-be-truthy)
    (expect (null (recording-sleeper-calls sleeper)) :to-be-truthy)))

(it "reset-recording-sleeper-calls-signals-for-unsupported-sleeper-types"
  (signals error
    (reset-recording-sleeper-calls (make-test-sleeper))))
