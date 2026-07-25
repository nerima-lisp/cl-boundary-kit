;;;; src/scheduler.lisp

(in-package #:cl-boundary-kit)

(defclass scheduler ()
  ((schedule-fn :initarg :schedule-fn :reader scheduler-schedule-fn)
   (cancel-fn :initarg :cancel-fn :reader scheduler-cancel-fn)))

(defclass test-scheduler (scheduler)
  ((tasks :initform '() :accessor %test-scheduler-tasks)
   (pending-task-ids :initform (make-hash-table :test 'eql)
                     :accessor %test-scheduler-pending-task-ids)
   (cancelled-task-ids :initform (make-hash-table :test 'eql)
                       :accessor %test-scheduler-cancelled-task-ids)
   (next-id :initform 1 :accessor %test-scheduler-next-id)))

(defclass recording-scheduler (scheduler)
  ((delegate :initarg :delegate :reader recording-scheduler-delegate)
   (calls :initform '() :accessor %recording-scheduler-calls)))

(defun %validate-schedule-delay (delay)
  (unless (and (realp delay) (>= delay 0))
    (error "SCHEDULER-SCHEDULE delay must be a non-negative real number: ~S" delay))
  delay)

(defun make-scheduler (&key schedule-fn cancel-fn)
  "Create a scheduler boundary from the injected collaborator functions.

`scheduler-schedule` calls SCHEDULE-FN with a delay and a thunk and should return
a task id, while `scheduler-cancel` calls CANCEL-FN with a task id and should
return whether it was still pending. Wire these to a real timer facility at the
application edge; both collaborators are validated at construction time."
  (require-function schedule-fn "SCHEDULE-FN")
  (require-function cancel-fn "CANCEL-FN")
  (make-instance 'scheduler :schedule-fn schedule-fn :cancel-fn cancel-fn))

(defun make-test-scheduler ()
  "Create an in-memory scheduler that records scheduled tasks without running them.

`scheduler-schedule` stores a task and returns an incrementing id;
`scheduler-cancel` drops a pending task. Inspect the queue with
`test-scheduler-pending` and fire it deterministically with
`test-scheduler-run-pending`, so tests control exactly when deferred work runs."
  (make-instance 'test-scheduler :schedule-fn nil :cancel-fn nil))

(defun %ordered-test-scheduler-tasks (scheduler)
  (reverse (%test-scheduler-tasks scheduler)))

(defun %test-scheduler-task-cancelled-p (scheduler task)
  (gethash (first task) (%test-scheduler-cancelled-task-ids scheduler)))

(defun %test-scheduler-task-pending-p (scheduler task)
  (gethash (first task) (%test-scheduler-pending-task-ids scheduler)))

(defun %test-scheduler-live-tasks (scheduler)
  (remove-if (lambda (task)
               (or (%test-scheduler-task-cancelled-p scheduler task)
                   (not (%test-scheduler-task-pending-p scheduler task))))
             (%ordered-test-scheduler-tasks scheduler)))

(defun test-scheduler-pending (scheduler)
  "Return the pending tasks of SCHEDULER as `(:id <id> :delay <delay>)` plists in
schedule order. Thunks are omitted because they are not meaningfully comparable."
  (unless (typep scheduler 'test-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (mapcar (lambda (task) (list :id (first task) :delay (second task)))
          (%test-scheduler-live-tasks scheduler)))

(defun %requeue-remaining-scheduler-tasks (scheduler task tasks)
  ;; A task that errors, plus every task still queued after it, goes back onto
  ;; SCHEDULER as pending so TEST-SCHEDULER-RUN-PENDING's contract holds even
  ;; though this scheduler already popped them off; the caller re-signals the
  ;; original error once this returns.
  (setf (%test-scheduler-tasks scheduler) (reverse (cons task tasks)))
  (setf (gethash (first task) (%test-scheduler-pending-task-ids scheduler)) t)
  (loop for remaining in tasks do
    (setf (gethash (first remaining) (%test-scheduler-pending-task-ids scheduler)) t))
  (clrhash (%test-scheduler-cancelled-task-ids scheduler)))

(defun test-scheduler-run-pending (scheduler)
  "Run pending tasks of SCHEDULER in schedule order and return their results.

Successfully completed tasks are removed. If a task signals an error, that task
and the tasks after it remain pending, and the original error is re-signaled."
  (unless (typep scheduler 'test-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (let ((tasks (%test-scheduler-live-tasks scheduler))
        (results '()))
    (setf (%test-scheduler-tasks scheduler) '())
    (clrhash (%test-scheduler-pending-task-ids scheduler))
    (clrhash (%test-scheduler-cancelled-task-ids scheduler))
    (loop
      (when (endp tasks)
        (return (nreverse results)))
      (let ((task (pop tasks)))
        (handler-case
            (push (funcall (third task)) results)
          (error (condition)
            (%requeue-remaining-scheduler-tasks scheduler task tasks)
            (error condition)))))))

(define-recording-boundary-constructor make-recording-scheduler recording-scheduler scheduler (make-test-scheduler)
  "Create a scheduler that records calls while delegating to DELEGATE, which
defaults to a `make-test-scheduler`. Recorded `:schedule` calls carry the delay
but not the thunk, so the history stays comparable."
  :schedule-fn nil :cancel-fn nil)

(define-recording-call-log recording-scheduler-calls reset-recording-scheduler-calls
    (scheduler recording-scheduler %recording-scheduler-calls) "scheduler")

(defmethod scheduler-schedule ((scheduler scheduler) delay thunk)
  (%validate-schedule-delay delay)
  (require-function thunk "THUNK")
  (funcall (scheduler-schedule-fn scheduler) delay thunk))

(defmethod scheduler-cancel ((scheduler scheduler) id)
  (funcall (scheduler-cancel-fn scheduler) id))

(defmethod scheduler-schedule ((scheduler test-scheduler) delay thunk)
  (%validate-schedule-delay delay)
  (require-function thunk "THUNK")
  (let ((id (%test-scheduler-next-id scheduler)))
    (setf (%test-scheduler-next-id scheduler) (1+ id))
    (push (list id delay thunk) (%test-scheduler-tasks scheduler))
    (setf (gethash id (%test-scheduler-pending-task-ids scheduler)) t)
    id))

(defmethod scheduler-cancel ((scheduler test-scheduler) id)
  (when (gethash id (%test-scheduler-pending-task-ids scheduler))
    (unless (gethash id (%test-scheduler-cancelled-task-ids scheduler))
      (setf (gethash id (%test-scheduler-cancelled-task-ids scheduler)) t)
      t)))

(define-recording-delegate-method scheduler-schedule (scheduler recording-scheduler recording-scheduler-delegate %recording-scheduler-calls)
    ((delay thunk) (delay thunk)) :schedule (list delay) ;; Record the delay but not the thunk, so recorded calls stay comparable.
  (%validate-schedule-delay delay)
  (require-function thunk "THUNK"))

(define-recording-delegate-method scheduler-cancel (scheduler recording-scheduler recording-scheduler-delegate %recording-scheduler-calls)
    ((id) (id)) :cancel (list id))
