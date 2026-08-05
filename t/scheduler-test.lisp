;;;; t/scheduler-test.lisp

(in-package #:cl-boundary-kit/test)

;; Rebound by the TEST-SCHEDULER group's BEFORE-EACH, so each case gets a
;; scheduler with an empty pending queue and a fresh id counter.
(defvar *test-scheduler* nil)

(describe "test-scheduler"
  (before-each
    (setf *test-scheduler* (make-test-scheduler)))

  (it "test-scheduler-records-tasks-with-incrementing-ids"
    (expect (scheduler-schedule *test-scheduler* 5 (lambda () :a)) :to-be 1)
    (expect (scheduler-schedule *test-scheduler* 10 (lambda () :b)) :to-be 2)
    (expect (test-scheduler-pending *test-scheduler*) :to-equal (list (list :id 1 :delay 5) (list :id 2 :delay 10))))

  (it "test-scheduler-run-pending-runs-tasks-in-order-and-clears-them"
    (let ((log '()))
      (scheduler-schedule *test-scheduler* 1 (lambda () (push :first log) :first))
      (scheduler-schedule *test-scheduler* 2 (lambda () (push :second log) :second))
      (expect (test-scheduler-run-pending *test-scheduler*) :to-equal (list :first :second))
      (expect log :to-equal (list :second :first))
      (expect (test-scheduler-pending *test-scheduler*) :to-be-null)))

  (it "test-scheduler-run-pending-preserves-failed-and-unrun-tasks-on-error"
    (let ((log '())
          (caught nil))
      (scheduler-schedule *test-scheduler* 1
                          (lambda ()
                            (push :first log)
                            (error "boom")))
      (scheduler-schedule *test-scheduler* 2
                          (lambda ()
                            (push :second log)
                            :second))
      (handler-case
          (test-scheduler-run-pending *test-scheduler*)
        (error (condition)
          (setf caught condition)))
      (expect caught :to-be-truthy)
      (expect log :to-equal (list :first))
      (expect (test-scheduler-pending *test-scheduler*) :to-equal (list (list :id 1 :delay 1) (list :id 2 :delay 2)))))

  (it "test-scheduler-cancel-drops-a-pending-task"
    (let ((id (scheduler-schedule *test-scheduler* 5 (lambda () :a))))
      (scheduler-schedule *test-scheduler* 5 (lambda () :b))
      (expect (scheduler-cancel *test-scheduler* id) :to-be t)
      (expect (scheduler-cancel *test-scheduler* id) :to-be-null)
      (expect (test-scheduler-pending *test-scheduler*) :to-equal (list (list :id 2 :delay 5)))))

  (it "scheduler-schedule-rejects-a-negative-delay-and-a-non-function-thunk"
    (signals error
      (scheduler-schedule *test-scheduler* -1 (lambda () :a)))
    (signals error
      (scheduler-schedule *test-scheduler* 5 :not-a-function)))

  (it "test-scheduler-accessors-signal-for-unsupported-scheduler-types"
    (signals error
      (test-scheduler-pending (make-recording-scheduler)))
    (signals error
      (test-scheduler-run-pending (make-recording-scheduler)))))

(describe "make-scheduler"
  (it "make-scheduler-wires-injected-collaborators"
    (let* ((events '())
           (scheduler (make-scheduler
                       :schedule-fn (lambda (delay thunk)
                                      (declare (ignore thunk))
                                      (push (list :schedule delay) events)
                                      42)
                       :cancel-fn (lambda (id) (push (list :cancel id) events) t))))
      (expect (scheduler-schedule scheduler 3 (lambda () :a)) :to-be 42)
      (expect (scheduler-cancel scheduler 42) :to-be t)
      (expect events :to-equal (list (list :cancel 42) (list :schedule 3)))))

  (it "make-scheduler-rejects-non-function-collaborators"
    (signals error
      (make-scheduler :schedule-fn :bad :cancel-fn (lambda (id) id)))))

(describe "recording-scheduler"
  (it "recording-scheduler-records-schedule-and-cancel-without-the-thunk"
    (let ((scheduler (make-recording-scheduler)))
      (let ((id (scheduler-schedule scheduler 7 (lambda () :a))))
        (scheduler-cancel scheduler id)
        (expect (recording-scheduler-calls scheduler) :to-have-recorded-calls (list (boundary-call-plist :schedule (list 7) :result id)
                             (boundary-call-plist :cancel (list id) :result t))))))

  (it "make-recording-scheduler-rejects-a-non-scheduler-delegate"
    (signals error
      (make-recording-scheduler :delegate :bad)))

  (it-each ((recording-scheduler-calls)
            (reset-recording-scheduler-calls))
      "~A signals for unsupported scheduler types"
      (operation)
    (expect (lambda () (funcall operation (make-test-scheduler))) :to-throw "Unsupported scheduler type"))

  (deftest-reset-recording-clears-history
      "reset-recording-scheduler-calls-clears-history-and-returns-the-scheduler"
      (scheduler (make-recording-scheduler))
      (recording-scheduler-calls reset-recording-scheduler-calls)
    (scheduler-schedule scheduler 1 (lambda () :a))))
