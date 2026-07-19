;;;; src/recording-boundary.lisp

(in-package #:cl-boundary-kit)

(defclass recording-boundary ()
  ((handler :initarg :handler :reader recording-boundary-handler)
   (calls :initform '() :accessor %recording-boundary-calls)))

(defun %recording-boundary-invoke/cps (boundary operation args continuation)
  (funcall continuation
           (apply (recording-boundary-handler boundary) operation args)))

(defun make-recording-boundary (&key (handler (lambda (&rest args)
                                                (declare (ignore args))
                                                nil)))
  "Create a generic recording boundary that delegates to HANDLER."
  (require-function handler "HANDLER")
  (make-instance 'recording-boundary :handler handler))

(defun recording-boundary-calls (boundary)
  "Return the recorded calls captured by BOUNDARY in call order."
  (require-instance boundary 'recording-boundary "BOUNDARY")
  (%snapshot-recorded-calls (%recording-boundary-calls boundary)))

(defun recording-boundary-invoke (boundary operation &rest args)
  "Invoke OPERATION on BOUNDARY with ARGS and record the interaction."
  (require-instance boundary 'recording-boundary "BOUNDARY")
  (%recording-boundary-invoke/cps
   boundary
   operation
   args
   (lambda (result)
     (%record-call (%recording-boundary-calls boundary)
       :operation operation
       :arguments args
       :result result)
     result)))
