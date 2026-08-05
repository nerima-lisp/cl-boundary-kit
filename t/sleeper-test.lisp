;;;; t/sleeper-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "make-sleeper"
  (it "make-sleeper-invokes-its-sleep-function-and-returns-the-seconds"
    (let* ((recorded '())
           (sleeper (make-sleeper :sleep-fn (lambda (seconds) (push seconds recorded)))))
      (expect (sleeper-sleep sleeper 3) :to-be 3)
      (expect recorded :to-equal '(3))))

  (it "make-sleeper-rejects-a-non-function-sleep-fn"
    (signals error
      (make-sleeper :sleep-fn :bad)))

  ;; The test above supplies an explicit :SLEEP-FN; exercise the &KEY default
  ;; (CL:SLEEP itself) too, with a zero duration so the test stays instant.
  (it "make-sleeper-defaults-to-cl-sleep"
    (let ((sleeper (make-sleeper)))
      (expect (sleeper-sleep sleeper 0) :to-be 0))))

(describe "test-sleeper"
  (it "test-sleeper-returns-the-requested-seconds-without-blocking"
    (let ((sleeper (make-test-sleeper)))
      (expect (sleeper-sleep sleeper 5) :to-be 5)
      (expect (sleeper-sleep sleeper 0.5d0) :to-be 0.5d0)))

  (it "sleeper-sleep-rejects-negative-and-non-real-durations"
    (let ((sleeper (make-test-sleeper)))
      (signals error
        (sleeper-sleep sleeper -1))
      (signals error
        (sleeper-sleep sleeper :nope)))))

(describe "recording-sleeper"
  (it "recording-sleeper-records-requested-durations"
    (let ((sleeper (make-recording-sleeper)))
      (expect (sleeper-sleep sleeper 5) :to-be 5)
      (expect (sleeper-sleep sleeper 0.25d0) :to-be 0.25d0)
      (expect (recording-sleeper-calls sleeper) :to-have-recorded-calls (list (boundary-call-plist :sleep (list 5) :result 5)
                           (boundary-call-plist :sleep (list 0.25d0) :result 0.25d0)))))

  (it "make-recording-sleeper-rejects-a-non-sleeper-delegate"
    (signals error
      (make-recording-sleeper :delegate :bad)))

  (it-each ((recording-sleeper-calls)
            (reset-recording-sleeper-calls))
      "~A signals for unsupported sleeper types"
      (operation)
    (expect (lambda () (funcall operation (make-test-sleeper))) :to-throw "Unsupported sleeper type"))

  (deftest-reset-recording-clears-history
      "reset-recording-sleeper-calls-clears-history-and-returns-the-sleeper"
      (sleeper (make-recording-sleeper))
      (recording-sleeper-calls reset-recording-sleeper-calls)
    (sleeper-sleep sleeper 1)))

