;;;; src/system-data.lisp

(in-package #:cl-boundary-kit)

(defclass system-boundary ()
  ((exit-fn :initarg :exit-fn :reader system-boundary-exit-fn)))

(defclass test-system-boundary (system-boundary)
  ((exit-codes :initform '() :accessor %test-system-exit-codes)))

(defclass recording-system-boundary (system-boundary)
  ((delegate :initarg :delegate :reader recording-system-boundary-delegate)
   (calls :initform '() :accessor %recording-system-calls)))
