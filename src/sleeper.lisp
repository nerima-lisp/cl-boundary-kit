;;;; src/sleeper.lisp

(in-package #:cl-boundary-kit)

(defclass sleeper ()
  ((sleep-fn :initarg :sleep-fn :reader sleeper-sleep-fn)))

(defclass test-sleeper (sleeper) ())

(defclass recording-sleeper (sleeper)
  ((delegate :initarg :delegate :reader recording-sleeper-delegate)
   (calls :initform '() :accessor %recording-sleeper-calls)))

(defun %validate-sleep-seconds (seconds)
  (unless (and (realp seconds) (>= seconds 0))
    (error "SLEEPER-SLEEP seconds must be a non-negative real number: ~S" seconds))
  seconds)

(defun make-sleeper (&key (sleep-fn #'sleep))
  "Create a sleeper boundary backed by SLEEP-FN.

SLEEP-FN is called with the requested number of seconds. The default blocks the
current thread with `cl:sleep`, so this is the one path that produces a real
delay."
  (require-function sleep-fn "SLEEP-FN")
  (make-instance 'sleeper :sleep-fn sleep-fn))

(defun make-test-sleeper ()
  "Create a non-blocking sleeper for deterministic tests.

`sleeper-sleep` validates and returns the requested number of seconds without
ever delaying, so tests can drive time-dependent code without waiting. Wrap it
in `make-recording-sleeper` to assert on the requested durations."
  (make-instance 'test-sleeper :sleep-fn nil))

(defun make-recording-sleeper (&key (delegate (make-test-sleeper)))
  "Create a sleeper that records requested durations while delegating to DELEGATE.

DELEGATE defaults to a non-blocking `make-test-sleeper`, so recording a sleeper
in tests never introduces a real delay unless you pass a blocking delegate."
  (require-instance delegate 'sleeper "DELEGATE")
  (make-instance 'recording-sleeper :sleep-fn nil :delegate delegate))

(defun recording-sleeper-calls (sleeper)
  "Return the recorded sleeper calls in call order."
  (unless (typep sleeper 'recording-sleeper)
    (error "Unsupported sleeper type: ~S" sleeper))
  (%snapshot-recorded-calls (%recording-sleeper-calls sleeper)))

(defun reset-recording-sleeper-calls (sleeper)
  "Clear SLEEPER's recorded call history and return SLEEPER.

A recording sleeper otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep sleeper 'recording-sleeper)
    (error "Unsupported sleeper type: ~S" sleeper))
  (setf (%recording-sleeper-calls sleeper) nil)
  sleeper)

(defmethod sleeper-sleep ((sleeper sleeper) seconds)
  (%validate-sleep-seconds seconds)
  (funcall (sleeper-sleep-fn sleeper) seconds)
  seconds)

(defmethod sleeper-sleep ((sleeper test-sleeper) seconds)
  (%validate-sleep-seconds seconds)
  seconds)

(defmethod sleeper-sleep ((sleeper recording-sleeper) seconds)
  (%validate-sleep-seconds seconds)
  (let ((result (sleeper-sleep (recording-sleeper-delegate sleeper) seconds)))
    (%record-call (%recording-sleeper-calls sleeper)
      :operation :sleep
      :arguments (list seconds)
      :result result)
    result))
