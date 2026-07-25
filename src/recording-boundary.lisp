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

(defun reset-recording-boundary-calls (boundary)
  "Clear BOUNDARY's recorded call history and return BOUNDARY.

A recording boundary otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only
being able to reclaim it by discarding the object."
  (require-instance boundary 'recording-boundary "BOUNDARY")
  (setf (%recording-boundary-calls boundary) nil)
  boundary)

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

(defmacro define-recording-call-log
    (calls-name reset-name (parameter class-name calls-accessor) noun &optional extra-doc)
  "Define CALLS-NAME and RESET-NAME as the standard recorded-calls reader and
history-reset pair shared by every recording boundary in this system.

CALLS-NAME returns CALLS-ACCESSOR's recorded calls, oldest first. RESET-NAME
clears them and returns PARAMETER. Both signal an error naming NOUN (e.g.
\"cache\" or \"rate limiter\") when PARAMETER is not a CLASS-NAME. Passing NIL for
CLASS-NAME skips that guard, for boundaries whose CALLS-ACCESSOR is itself a
type-dispatched generic that rejects unsupported arguments. EXTRA-DOC, when
supplied, is appended as a further paragraph on CALLS-NAME's docstring."
  (let* ((type-error-format (format nil "Unsupported ~A type: ~~S" noun))
         (parameter-name (string-upcase (symbol-name parameter)))
         (calls-doc (format nil "Return the recorded ~A calls in call order.~@[~%~%~A~]"
                             noun extra-doc))
         (reset-doc (format nil "Clear ~A's recorded call history and return ~:*~A.~
~%~%A recording ~A otherwise retains every call for the object's whole~
~%lifetime; call this periodically to bound memory growth instead of only~
~%being able to reclaim it by discarding the object."
                             parameter-name noun))
         (guard (when class-name
                  `((unless (typep ,parameter ',class-name)
                      (error ,type-error-format ,parameter))))))
    `(progn
       (defun ,calls-name (,parameter)
         ,calls-doc
         ,@guard
         (%snapshot-recorded-calls (,calls-accessor ,parameter)))
       (defun ,reset-name (,parameter)
         ,reset-doc
         ,@guard
         (setf (,calls-accessor ,parameter) nil)
         ,parameter))))

(defmacro define-predicate-guarded-call-log
    (calls-name reset-name (parameter normalize-form predicate accessor-form error-datum)
     noun &optional extra-doc)
  "Like DEFINE-RECORDING-CALL-LOG, for boundaries whose recording support is
decided by a runtime PREDICATE rather than membership in one class.

NORMALIZE-FORM is evaluated first and rebinds PARAMETER (typically validating
its broad boundary type); PREDICATE then selects the recording/test variants
that keep a call history. ACCESSOR-FORM is the history place, read by CALLS-NAME
and cleared by RESET-NAME. Both signal an error naming NOUN and reporting
ERROR-DATUM when PREDICATE rejects PARAMETER. EXTRA-DOC, when supplied, is
appended as a further paragraph on CALLS-NAME's docstring."
  (let ((error-format (format nil "Unsupported ~A type: ~~S" noun))
        (calls-doc (format nil "Return the recorded ~A calls in call order.~@[~%~%~A~]"
                           noun extra-doc))
        (reset-doc (format nil "Clear ~A's recorded call history and return ~:*~A.~
~%~%A recording ~A otherwise retains every call for the object's whole~
~%lifetime; call this periodically to bound memory growth instead of only~
~%being able to reclaim it by discarding the object."
                           (string-upcase (symbol-name parameter)) noun)))
    `(progn
       (defun ,calls-name (,parameter)
         ,calls-doc
         (let ((,parameter ,normalize-form))
           (if (,predicate ,parameter)
               (%snapshot-recorded-calls ,accessor-form)
               (error ,error-format ,error-datum))))
       (defun ,reset-name (,parameter)
         ,reset-doc
         (let ((,parameter ,normalize-form))
           (if (,predicate ,parameter)
               (progn (setf ,accessor-form nil) ,parameter)
               (error ,error-format ,error-datum)))))))

(defmacro define-recording-delegate-method
    (generic-name (instance-var recording-class delegate-accessor calls-accessor)
     (lambda-list call-args) operation arguments-form &body before)
  "Define a GENERIC-NAME method on RECORDING-CLASS that runs BEFORE (typically
argument validation), delegates to DELEGATE-ACCESSOR via CALL-ARGS (the bound
parameter names/keyword-pairs matching LAMBDA-LIST, for forwarding &optional
and &key defaults correctly), records the call onto CALLS-ACCESSOR under
OPERATION with ARGUMENTS-FORM, and returns the delegate's result.

Only fits the single-return-value \"call then record\" shape; a method that
returns multiple values (e.g. a present-p flag) is written by hand instead."
  `(defmethod ,generic-name ((,instance-var ,recording-class) ,@lambda-list)
     ,@before
     (let ((result (,generic-name (,delegate-accessor ,instance-var) ,@call-args)))
       (%record-call (,calls-accessor ,instance-var)
         :operation ,operation
         :arguments ,arguments-form
         :result result)
       result)))
