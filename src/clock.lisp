;;;; src/clock.lisp

(in-package #:cl-boundary-kit)

(defclass clock ()
  ((now-fn :initarg :now-fn :reader clock-now-fn)
   (monotonic-fn :initarg :monotonic-fn :reader clock-monotonic-fn)))

(defclass fake-clock (clock)
  ((current-time :initarg :current-time :accessor fake-clock-current-time)
   (monotonic-time :initarg :monotonic-time :accessor fake-clock-monotonic-time)))

(defun make-clock (&key
                     (now-fn #'get-universal-time)
                     (monotonic-fn #'get-internal-real-time))
  "Create a clock boundary backed by NOW-FN and MONOTONIC-FN."
  (require-function now-fn "NOW-FN")
  (require-function monotonic-fn "MONOTONIC-FN")
  (make-instance 'clock :now-fn now-fn :monotonic-fn monotonic-fn))

(defun %validate-clock-time (value name)
  ;; Every sibling fake/test constructor validates its numeric inputs at
  ;; construction time (make-deterministic-random-source's modulus,
  ;; make-test-random-source's queued values); a fake clock seeded with a
  ;; non-number instead failed silently at construction and only surfaced a
  ;; confusing TYPE-ERROR later, deep inside whatever arithmetic a caller did
  ;; with CLOCK-NOW's result.
  (unless (realp value)
    (error "~A must be a real number: ~S" name value))
  value)

(defun make-fake-clock (&key (start 0) (monotonic-start start))
  "Create a mutable fake clock starting at START and MONOTONIC-START."
  (%validate-clock-time start "START")
  (%validate-clock-time monotonic-start "MONOTONIC-START")
  ;; NOW-FN/MONOTONIC-FN must read the mutable slots (not close over the
  ;; initial START/MONOTONIC-START values), so CLOCK-NOW-FN/CLOCK-MONOTONIC-FN
  ;; -- the public readers inherited from CLOCK -- stay consistent with
  ;; ADVANCE-FAKE-CLOCK instead of returning frozen construction-time values.
  (let ((clock (make-instance 'fake-clock
                              :now-fn nil
                              :monotonic-fn nil
                              :current-time start
                              :monotonic-time monotonic-start)))
    (setf (slot-value clock 'now-fn) (lambda () (fake-clock-current-time clock)))
    (setf (slot-value clock 'monotonic-fn) (lambda () (fake-clock-monotonic-time clock)))
    clock))

(defun advance-fake-clock (clock delta &key (monotonic-delta delta))
  "Advance fake CLOCK by DELTA and its monotonic value by MONOTONIC-DELTA."
  (check-type clock fake-clock)
  (%validate-clock-time delta "DELTA")
  (%validate-clock-time monotonic-delta "MONOTONIC-DELTA")
  (incf (fake-clock-current-time clock) delta)
  (incf (fake-clock-monotonic-time clock) monotonic-delta)
  clock)

(defmethod clock-now ((clock clock))
  (funcall (clock-now-fn clock)))

(defmethod clock-monotonic ((clock clock))
  (funcall (clock-monotonic-fn clock)))

(defmethod clock-now ((clock fake-clock))
  (fake-clock-current-time clock))

(defmethod clock-monotonic ((clock fake-clock))
  (fake-clock-monotonic-time clock))
