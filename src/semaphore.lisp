;;;; src/semaphore.lisp

(in-package #:cl-boundary-kit)

(defclass semaphore ()
  ((acquire-fn :initarg :acquire-fn :reader semaphore-acquire-fn)
   (release-fn :initarg :release-fn :reader semaphore-release-fn)
   (available-fn :initarg :available-fn :reader semaphore-available-fn)))

(defclass test-semaphore (semaphore)
  ((permits :initarg :permits :accessor %test-semaphore-permits)))

(defclass recording-semaphore (semaphore)
  ((delegate :initarg :delegate :reader recording-semaphore-delegate)
   (calls :initform '() :accessor %recording-semaphore-calls)))

(defun %validate-semaphore-permits (permits)
  (unless (and (integerp permits) (>= permits 0))
    (error "Semaphore permits must be a non-negative integer: ~S" permits))
  permits)

(defun make-semaphore (&key acquire-fn release-fn available-fn)
  "Create a semaphore boundary from the injected collaborator functions.

`semaphore-acquire` calls ACQUIRE-FN, `semaphore-release` calls RELEASE-FN, and
`semaphore-available` calls AVAILABLE-FN, each with no arguments. Wire these to a
real host counting semaphore at the application edge; every collaborator is
validated at construction time."
  (require-function acquire-fn "ACQUIRE-FN")
  (require-function release-fn "RELEASE-FN")
  (require-function available-fn "AVAILABLE-FN")
  (make-instance 'semaphore
                 :acquire-fn acquire-fn
                 :release-fn release-fn
                 :available-fn available-fn))

(defun make-test-semaphore (&key (permits 1))
  "Create an in-memory counting semaphore fake starting with PERMITS permits.

`semaphore-acquire` consumes one permit and signals when none remain (surfacing
what would otherwise block), `semaphore-release` returns one permit, and
`semaphore-available` returns the current permit count."
  (make-instance 'test-semaphore
                 :acquire-fn nil :release-fn nil :available-fn nil
                 :permits (%validate-semaphore-permits permits)))

(define-recording-boundary-constructor make-recording-semaphore
    recording-semaphore semaphore (make-test-semaphore)
  "Create a semaphore that records calls while delegating to DELEGATE, which
defaults to a single-permit `make-test-semaphore`."
  :acquire-fn nil :release-fn nil :available-fn nil)

(define-recording-call-log recording-semaphore-calls reset-recording-semaphore-calls
    (semaphore recording-semaphore %recording-semaphore-calls) "semaphore")

(defun call-with-semaphore (semaphore thunk)
  "Acquire a permit from SEMAPHORE, call THUNK, and release the permit even if THUNK
signals; return THUNK's value.

The release runs in an `unwind-protect` cleanup, so a non-local exit out of THUNK
still returns the permit. Works with any semaphore, and a recording semaphore
records the acquire and release."
  (require-function thunk "THUNK")
  (semaphore-acquire semaphore)
  (unwind-protect (funcall thunk)
    (semaphore-release semaphore)))

(defmethod semaphore-acquire ((semaphore semaphore))
  (funcall (semaphore-acquire-fn semaphore))
  t)

(defmethod semaphore-release ((semaphore semaphore))
  (funcall (semaphore-release-fn semaphore))
  t)

(defmethod semaphore-available ((semaphore semaphore))
  (funcall (semaphore-available-fn semaphore)))

(defmethod semaphore-acquire ((semaphore test-semaphore))
  (let ((permits (%test-semaphore-permits semaphore)))
    (unless (plusp permits)
      (error "Test semaphore has no permits available; an acquire would block"))
    (decf (%test-semaphore-permits semaphore))
    t))

(defmethod semaphore-release ((semaphore test-semaphore))
  (incf (%test-semaphore-permits semaphore))
  t)

(defmethod semaphore-available ((semaphore test-semaphore))
  (%test-semaphore-permits semaphore))

(define-recording-delegate-method semaphore-acquire
    (semaphore recording-semaphore recording-semaphore-delegate %recording-semaphore-calls)
    (() ()) :acquire '())

(define-recording-delegate-method semaphore-release
    (semaphore recording-semaphore recording-semaphore-delegate %recording-semaphore-calls)
    (() ()) :release '())

(define-recording-delegate-method semaphore-available
    (semaphore recording-semaphore recording-semaphore-delegate %recording-semaphore-calls)
    (() ()) :available '())
