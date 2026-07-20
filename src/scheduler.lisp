;;;; src/scheduler.lisp

(in-package #:cl-boundary-kit)

(defclass scheduler ()
  ((schedule-fn :initarg :schedule-fn :reader scheduler-schedule-fn)
   (cancel-fn :initarg :cancel-fn :reader scheduler-cancel-fn)))

(defclass test-scheduler (scheduler)
  ((tasks :initform '() :accessor %test-scheduler-tasks)
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

(defun test-scheduler-pending (scheduler)
  "Return the pending tasks of SCHEDULER as `(:id <id> :delay <delay>)` plists in
schedule order. Thunks are omitted because they are not meaningfully comparable."
  (unless (typep scheduler 'test-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (mapcar (lambda (task) (list :id (first task) :delay (second task)))
          (%ordered-test-scheduler-tasks scheduler)))

(defun test-scheduler-run-pending (scheduler)
  "Run every pending task of SCHEDULER in schedule order, clear the queue, and
return the list of thunk results."
  (unless (typep scheduler 'test-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (let ((tasks (%ordered-test-scheduler-tasks scheduler)))
    (setf (%test-scheduler-tasks scheduler) '())
    (mapcar (lambda (task) (funcall (third task))) tasks)))

(defun make-recording-scheduler (&key (delegate (make-test-scheduler)))
  "Create a scheduler that records calls while delegating to DELEGATE, which
defaults to a `make-test-scheduler`. Recorded `:schedule` calls carry the delay
but not the thunk, so the history stays comparable."
  (require-instance delegate 'scheduler "DELEGATE")
  (make-instance 'recording-scheduler :schedule-fn nil :cancel-fn nil :delegate delegate))

(defun recording-scheduler-calls (scheduler)
  "Return the recorded scheduler calls in call order."
  (unless (typep scheduler 'recording-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (%snapshot-recorded-calls (%recording-scheduler-calls scheduler)))

(defun reset-recording-scheduler-calls (scheduler)
  "Clear SCHEDULER's recorded call history and return SCHEDULER.

A recording scheduler otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep scheduler 'recording-scheduler)
    (error "Unsupported scheduler type: ~S" scheduler))
  (setf (%recording-scheduler-calls scheduler) nil)
  scheduler)

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
    id))

(defmethod scheduler-cancel ((scheduler test-scheduler) id)
  (let ((present (find id (%test-scheduler-tasks scheduler) :key #'first)))
    (setf (%test-scheduler-tasks scheduler)
          (remove id (%test-scheduler-tasks scheduler) :key #'first))
    (and present t)))

(defmethod scheduler-schedule ((scheduler recording-scheduler) delay thunk)
  (%validate-schedule-delay delay)
  (require-function thunk "THUNK")
  (let ((result (scheduler-schedule (recording-scheduler-delegate scheduler) delay thunk)))
    ;; Record the delay but not the thunk, so recorded calls stay comparable.
    (%record-call (%recording-scheduler-calls scheduler)
      :operation :schedule
      :arguments (list delay)
      :result result)
    result))

(defmethod scheduler-cancel ((scheduler recording-scheduler) id)
  (let ((result (scheduler-cancel (recording-scheduler-delegate scheduler) id)))
    (%record-call (%recording-scheduler-calls scheduler)
      :operation :cancel
      :arguments (list id)
      :result result)
    result))
