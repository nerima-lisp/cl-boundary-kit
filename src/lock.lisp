;;;; src/lock.lisp

(in-package #:cl-boundary-kit)

(defclass lock ()
  ((acquire-fn :initarg :acquire-fn :reader lock-acquire-fn)
   (release-fn :initarg :release-fn :reader lock-release-fn)))

(defclass test-lock (lock)
  ((reentrant :initarg :reentrant :reader test-lock-reentrant-p)
   (depth :initform 0 :accessor %test-lock-depth)))

(defclass recording-lock (lock)
  ((delegate :initarg :delegate :reader recording-lock-delegate)
   (calls :initform '() :accessor %recording-lock-calls)))

(defun make-lock (&key acquire-fn release-fn)
  "Create a lock boundary from the injected ACQUIRE-FN and RELEASE-FN.

`lock-acquire` calls ACQUIRE-FN and `lock-release` calls RELEASE-FN, each with no
arguments. Wire these to a real host mutex (for example a bordeaux-threads lock)
at the application edge; both collaborators are validated at construction time."
  (require-function acquire-fn "ACQUIRE-FN")
  (require-function release-fn "RELEASE-FN")
  (make-instance 'lock :acquire-fn acquire-fn :release-fn release-fn))

(defun make-test-lock (&key reentrant)
  "Create an in-memory lock fake that tracks whether it is held.

`lock-acquire` marks the lock held and `lock-release` marks it free. A
non-reentrant test lock signals on a second acquire before release (surfacing a
self-deadlock) and on a release while free; a `:reentrant` test lock instead
counts acquire depth and only frees on the matching release. Inspect the held
state through `test-lock-held-p`."
  (make-instance 'test-lock
                 :acquire-fn nil
                 :release-fn nil
                 :reentrant reentrant))

(defun test-lock-held-p (lock)
  "Return true when the test LOCK is currently held."
  (unless (typep lock 'test-lock)
    (error "Unsupported lock type: ~S" lock))
  (plusp (%test-lock-depth lock)))

(define-recording-boundary-constructor make-recording-lock recording-lock lock (make-test-lock)
  "Create a lock that records acquire/release calls while delegating to DELEGATE.

DELEGATE defaults to a non-reentrant `make-test-lock`."
  :acquire-fn nil :release-fn nil)

(define-recording-call-log recording-lock-calls reset-recording-lock-calls
    (lock recording-lock %recording-lock-calls) "lock")

(defun call-with-lock (lock thunk)
  "Acquire LOCK, call THUNK, and release LOCK even if THUNK signals; return THUNK's value.

The release runs in an `unwind-protect` cleanup, so a non-local exit out of THUNK
still frees the lock. Works with any lock, and a recording lock records the
acquire and release."
  (require-function thunk "THUNK")
  (lock-acquire lock)
  (unwind-protect (funcall thunk)
    (lock-release lock)))

(defmethod lock-acquire ((lock lock))
  (funcall (lock-acquire-fn lock))
  t)

(defmethod lock-release ((lock lock))
  (funcall (lock-release-fn lock))
  t)

(defmethod lock-acquire ((lock test-lock))
  (when (and (not (test-lock-reentrant-p lock))
             (plusp (%test-lock-depth lock)))
    (error "Test lock is already held; a second acquire would self-deadlock"))
  (incf (%test-lock-depth lock))
  t)

(defmethod lock-release ((lock test-lock))
  (unless (plusp (%test-lock-depth lock))
    (error "Test lock is not held; nothing to release"))
  (decf (%test-lock-depth lock))
  t)

(define-recording-delegate-method lock-acquire
    (lock recording-lock recording-lock-delegate %recording-lock-calls)
    (() ()) :acquire '())

(define-recording-delegate-method lock-release
    (lock recording-lock recording-lock-delegate %recording-lock-calls)
    (() ()) :release '())
