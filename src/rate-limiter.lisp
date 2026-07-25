;;;; src/rate-limiter.lisp

(in-package #:cl-boundary-kit)

(defclass rate-limiter ()
  ((allow-fn :initarg :allow-fn :reader rate-limiter-allow-fn)
   (available-fn :initarg :available-fn :reader rate-limiter-available-fn)))

(defclass test-rate-limiter (rate-limiter)
  ((capacity :initarg :capacity :reader test-rate-limiter-capacity)
   (refill-rate :initarg :refill-rate :reader test-rate-limiter-refill-rate)
   (now-fn :initarg :now-fn :reader test-rate-limiter-now-fn)
   (tokens :initarg :tokens :accessor %test-rate-limiter-tokens)
   (last-time :initarg :last-time :accessor %test-rate-limiter-last-time)))

(defclass recording-rate-limiter (rate-limiter)
  ((delegate :initarg :delegate :reader recording-rate-limiter-delegate)
   (calls :initform '() :accessor %recording-rate-limiter-calls)))

(defun %validate-rate-limiter-capacity (capacity)
  (unless (and (realp capacity) (> capacity 0))
    (error "Rate limiter capacity must be a positive real number: ~S" capacity))
  capacity)

(defun %validate-rate-limiter-refill-rate (refill-rate)
  (unless (and (realp refill-rate) (>= refill-rate 0))
    (error "Rate limiter refill rate must be a non-negative real number: ~S" refill-rate))
  refill-rate)

(defun make-rate-limiter (&key allow-fn available-fn)
  "Create a rate limiter boundary from the injected collaborator functions.

`rate-limiter-allow-p` calls ALLOW-FN (which should consume one unit of quota and
return whether it was permitted) and `rate-limiter-available` calls AVAILABLE-FN
(which should return the current quota count). Wire these to a real limiter, for
example a shared Redis token bucket, at the application edge; both collaborators
are validated at construction time."
  (require-function allow-fn "ALLOW-FN")
  (require-function available-fn "AVAILABLE-FN")
  (make-instance 'rate-limiter :allow-fn allow-fn :available-fn available-fn))

(defun make-test-rate-limiter (&key (capacity 1) (refill-rate 0) (now-fn (lambda () 0)))
  "Create an in-memory token-bucket rate limiter for deterministic tests.

The bucket starts full with CAPACITY tokens and refills at REFILL-RATE tokens per
unit of time returned by NOW-FN, never exceeding CAPACITY. `rate-limiter-allow-p`
consumes one token when at least one is available and otherwise reports that the
request is throttled. Pass `(lambda () (clock-now a-clock))` as NOW-FN to drive
refill from a fake clock, keeping the two boundaries decoupled."
  (%validate-rate-limiter-capacity capacity)
  (%validate-rate-limiter-refill-rate refill-rate)
  (require-function now-fn "NOW-FN")
  (make-instance 'test-rate-limiter
                 :allow-fn nil :available-fn nil
                 :capacity capacity
                 :refill-rate refill-rate
                 :now-fn now-fn
                 :tokens capacity
                 :last-time (funcall now-fn)))

(define-recording-boundary-constructor make-recording-rate-limiter recording-rate-limiter rate-limiter (make-test-rate-limiter)
  "Create a rate limiter that records calls while delegating to DELEGATE, which
defaults to a single-token `make-test-rate-limiter`."
  :allow-fn nil :available-fn nil)

(define-recording-call-log recording-rate-limiter-calls reset-recording-rate-limiter-calls
    (limiter recording-rate-limiter %recording-rate-limiter-calls) "rate limiter")

(defun %refill-test-rate-limiter (limiter)
  (let* ((now (funcall (test-rate-limiter-now-fn limiter)))
         (last-time (%test-rate-limiter-last-time limiter))
         (elapsed (- now last-time)))
    (when (> elapsed 0)
      (let* ((capacity (test-rate-limiter-capacity limiter))
             (refill-rate (test-rate-limiter-refill-rate limiter))
             (tokens (%test-rate-limiter-tokens limiter))
             (refilled (+ tokens (* elapsed refill-rate))))
        (setf (%test-rate-limiter-tokens limiter)
              (if (> refilled capacity) capacity refilled))
        (setf (%test-rate-limiter-last-time limiter) now)))))

(defun call-if-allowed (rate-limiter thunk &optional throttled-thunk)
  "If RATE-LIMITER permits, call THUNK and return its value; otherwise call
THROTTLED-THUNK (when supplied) and return its value, or return NIL.

Consumes one unit of quota through `rate-limiter-allow-p`, so it works with any
rate limiter and a recording rate limiter records the check. This is the
rate-limited-execution counterpart of the `call-with-*` helpers."
  (require-function thunk "THUNK")
  (when throttled-thunk
    (require-function throttled-thunk "THROTTLED-THUNK"))
  (if (rate-limiter-allow-p rate-limiter)
      (funcall thunk)
      (when throttled-thunk (funcall throttled-thunk))))

(defmethod rate-limiter-allow-p ((limiter rate-limiter))
  (and (funcall (rate-limiter-allow-fn limiter)) t))

(defmethod rate-limiter-available ((limiter rate-limiter))
  (funcall (rate-limiter-available-fn limiter)))

(defmethod rate-limiter-allow-p ((limiter test-rate-limiter))
  (%refill-test-rate-limiter limiter)
  (let ((tokens (%test-rate-limiter-tokens limiter)))
    (if (>= tokens 1)
      (progn (decf (%test-rate-limiter-tokens limiter)) t)
      nil)))

(defmethod rate-limiter-available ((limiter test-rate-limiter))
  (%refill-test-rate-limiter limiter)
  (floor (%test-rate-limiter-tokens limiter)))

(define-recording-delegate-method rate-limiter-allow-p (limiter recording-rate-limiter recording-rate-limiter-delegate %recording-rate-limiter-calls)
    (() ()) :allow-p '())

(define-recording-delegate-method rate-limiter-available (limiter recording-rate-limiter recording-rate-limiter-delegate %recording-rate-limiter-calls)
    (() ()) :available '())
