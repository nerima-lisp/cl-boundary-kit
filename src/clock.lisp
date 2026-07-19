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

(defun make-fake-clock (&key (start 0) (monotonic-start start))
  "Create a mutable fake clock starting at START and MONOTONIC-START."
  (make-instance 'fake-clock
                 :now-fn (lambda () start)
                 :monotonic-fn (lambda () monotonic-start)
                 :current-time start
                 :monotonic-time monotonic-start))

(defun advance-fake-clock (clock delta &key (monotonic-delta delta))
  "Advance fake CLOCK by DELTA and its monotonic value by MONOTONIC-DELTA."
  (check-type clock fake-clock)
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
