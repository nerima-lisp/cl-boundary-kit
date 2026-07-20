;;;; t/scheduler-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-scheduler-records-tasks-with-incrementing-ids"
  (let ((scheduler (make-test-scheduler)))
    (expect (= 1 (scheduler-schedule scheduler 5 (lambda () :a))) :to-be-truthy)
    (expect (= 2 (scheduler-schedule scheduler 10 (lambda () :b))) :to-be-truthy)
    (expect (equal (list (list :id 1 :delay 5) (list :id 2 :delay 10))
                   (test-scheduler-pending scheduler)) :to-be-truthy)))

(it "test-scheduler-run-pending-runs-tasks-in-order-and-clears-them"
  (let ((scheduler (make-test-scheduler))
        (log '()))
    (scheduler-schedule scheduler 1 (lambda () (push :first log) :first))
    (scheduler-schedule scheduler 2 (lambda () (push :second log) :second))
    (expect (equal (list :first :second) (test-scheduler-run-pending scheduler)) :to-be-truthy)
    (expect (equal (list :second :first) log) :to-be-truthy)
    (expect (null (test-scheduler-pending scheduler)) :to-be-truthy)))

(it "test-scheduler-run-pending-preserves-failed-and-unrun-tasks-on-error"
  (let ((scheduler (make-test-scheduler))
        (log '())
        (caught nil))
    (scheduler-schedule scheduler 1
                        (lambda ()
                          (push :first log)
                          (error "boom")))
    (scheduler-schedule scheduler 2
                        (lambda ()
                          (push :second log)
                          :second))
    (handler-case
        (test-scheduler-run-pending scheduler)
      (error (condition)
        (setf caught condition)))
    (expect caught :to-be-truthy)
    (expect (equal (list :first) log) :to-be-truthy)
    (expect (equal (list (list :id 1 :delay 1) (list :id 2 :delay 2))
                   (test-scheduler-pending scheduler)) :to-be-truthy)))

(it "test-scheduler-cancel-drops-a-pending-task"
  (let ((scheduler (make-test-scheduler)))
    (let ((id (scheduler-schedule scheduler 5 (lambda () :a))))
      (scheduler-schedule scheduler 5 (lambda () :b))
      (expect (eq t (scheduler-cancel scheduler id)) :to-be-truthy)
      (expect (null (scheduler-cancel scheduler id)) :to-be-truthy)
      (expect (equal (list (list :id 2 :delay 5))
                     (test-scheduler-pending scheduler)) :to-be-truthy))))

(it "scheduler-schedule-rejects-a-negative-delay-and-a-non-function-thunk"
  (let ((scheduler (make-test-scheduler)))
    (signals error
      (scheduler-schedule scheduler -1 (lambda () :a)))
    (signals error
      (scheduler-schedule scheduler 5 :not-a-function))))

(it "make-scheduler-wires-injected-collaborators"
  (let* ((events '())
         (scheduler (make-scheduler
                     :schedule-fn (lambda (delay thunk)
                                    (declare (ignore thunk))
                                    (push (list :schedule delay) events)
                                    42)
                     :cancel-fn (lambda (id) (push (list :cancel id) events) t))))
    (expect (= 42 (scheduler-schedule scheduler 3 (lambda () :a))) :to-be-truthy)
    (expect (eq t (scheduler-cancel scheduler 42)) :to-be-truthy)
    (expect (equal (list (list :cancel 42) (list :schedule 3)) events) :to-be-truthy)))

(it "make-scheduler-rejects-non-function-collaborators"
  (signals error
    (make-scheduler :schedule-fn :bad :cancel-fn (lambda (id) id))))

(it "recording-scheduler-records-schedule-and-cancel-without-the-thunk"
  (let ((scheduler (make-recording-scheduler)))
    (let ((id (scheduler-schedule scheduler 7 (lambda () :a))))
      (scheduler-cancel scheduler id)
      (expect (equal (recording-scheduler-calls scheduler)
                     (list (boundary-call-plist :schedule (list 7) :result id)
                           (boundary-call-plist :cancel (list id) :result t))) :to-be-truthy))))

(it "make-recording-scheduler-rejects-a-non-scheduler-delegate"
  (signals error
    (make-recording-scheduler :delegate :bad)))

(it "recording-scheduler-calls-signals-for-unsupported-scheduler-types"
  (signals error
    (recording-scheduler-calls (make-test-scheduler))))

(it "test-scheduler-accessors-signal-for-unsupported-scheduler-types"
  (signals error
    (test-scheduler-pending (make-recording-scheduler)))
  (signals error
    (test-scheduler-run-pending (make-recording-scheduler))))

(it "reset-recording-scheduler-calls-clears-history-and-returns-the-scheduler"
  (let ((scheduler (make-recording-scheduler)))
    (scheduler-schedule scheduler 1 (lambda () :a))
    (expect (= 1 (length (recording-scheduler-calls scheduler))) :to-be-truthy)
    (expect (eq scheduler (reset-recording-scheduler-calls scheduler)) :to-be-truthy)
    (expect (null (recording-scheduler-calls scheduler)) :to-be-truthy)))

(it "reset-recording-scheduler-calls-signals-for-unsupported-scheduler-types"
  (signals error
    (reset-recording-scheduler-calls (make-test-scheduler))))
