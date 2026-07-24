;;;; src/core-utilities.lisp

(in-package #:cl-boundary-kit)

(define-condition unsupported-boundary-operation (error)
  ((operation :initarg :operation :reader unsupported-boundary-operation-operation)
   (detail :initarg :detail :reader unsupported-boundary-operation-detail))
  (:report (lambda (condition stream)
             (format stream "~A is unsupported: ~A"
                     (unsupported-boundary-operation-operation condition)
                     (unsupported-boundary-operation-detail condition)))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setf (documentation 'unsupported-boundary-operation 'type)
        "Condition signaled when a boundary operation is unavailable.")
  (setf (documentation 'unsupported-boundary-operation-operation 'function)
        "Return the operation name attached to an UNSUPPORTED-BOUNDARY-OPERATION.")
  (setf (documentation 'unsupported-boundary-operation-detail 'function)
        "Return the explanatory detail attached to an UNSUPPORTED-BOUNDARY-OPERATION."))

(defun unsupported-operation (operation &optional detail)
  (error 'unsupported-boundary-operation
         :operation operation
         :detail (or detail "not implemented on this platform")))

(defun normalize-command (command arguments)
  (etypecase command
    (string (cons command (copy-list arguments)))
    (list (append command (copy-list arguments)))))

(defmacro do-plist ((key value plist &key result) &body body)
  `(loop for (,key ,value) on ,plist by #'cddr
         do (progn ,@body)
         finally (return ,result)))

(defmacro define-runtime-function (name lambda-list &body body)
  `(progn
     (defun ,name ,lambda-list
       ,@body)
     ',name))

(defmacro %record-call (storage &rest initargs)
  ;; Copy before storing so a caller that destructively edits an
  ;; :ARGUMENTS or :RESULT value it still holds a reference to (e.g. NREVERSE
  ;; on a returned list, SETF GETF on a returned plist) cannot corrupt the
  ;; boundary's own history.
  `(let ((call (list ,@initargs)))
     (push (%copy-boundary-value call) ,storage)
     call))

(defun %copy-boundary-value (value)
  "Return a defensive copy of common mutable boundary payload structure."
  (labels ((copy-value (object)
             (typecase object
               (cons
                (cons (copy-value (car object))
                      (copy-value (cdr object))))
               (string
                (copy-seq object))
               (bit-vector
                (copy-seq object))
               (vector
                (let ((copy (copy-seq object)))
                  (dotimes (index (length copy) copy)
                    (setf (aref copy index) (copy-value (aref copy index))))))
               (t object))))
    (copy-value value)))

(defun %snapshot-recorded-calls (calls)
  "Return CALLS oldest-first as an independent snapshot.

CALLS is stored newest-first. Both the returned spine and mutable structures
inside each call are freshly copied, so destructive edits to the snapshot
cannot corrupt the boundary history."
  (loop for call in calls
        collect (%copy-boundary-value call) into snapshot
        finally (return (nreverse snapshot))))

(defun %copy-boundary-event (event)
  "Return an independent snapshot of EVENT."
  (%copy-boundary-value event))

(defun %snapshot-boundary-events (events)
  "Return EVENTS oldest-first as independent event snapshots."
  (loop for event in events
        collect (%copy-boundary-event event) into snapshot
        finally (return (nreverse snapshot))))

(defun %sorted-hash-keys (table)
  (let ((keys '()))
    (maphash (lambda (key value)
               (declare (ignore value))
               (push key keys))
             table)
    (sort keys #'string< :key #'princ-to-string)))

(defun %emit-boundary-event (emit-fn event)
  "Call EMIT-FN with a defensive copy of EVENT and return EVENT."
  (funcall emit-fn (%copy-boundary-event event))
  event)

(defmacro define-emit-event-boundary-dispatch (class)
  "Generate the CLOS plumbing shared by every emit-style event boundary.

An emit boundary sinks each event three ways depending on its concrete class:
the plain CLASS forwards through its own emit-fn, TEST-<CLASS> buffers the event
in memory, and RECORDING-<CLASS> buffers it and then forwards to its delegate.
This macro emits that dispatch once, deriving every name from CLASS:

  * a %<CLASS>-EVENTS base method that rejects unsupported boundary types (the
    reader itself is the slot accessor defined on the test/recording classes);
  * the %RESET-<CLASS>-EVENTS generic that clears a buffer's history; and
  * the %<CLASS>-EMIT-EVENT generic implementing the three-way sink above.

CLASS, TEST-<CLASS>, and RECORDING-<CLASS> must already be defined, along with
the <CLASS>-EMIT-FN and RECORDING-<CLASS>-DELEGATE readers."
  (let* ((name (symbol-name class))
         (package (symbol-package class))
         (test-class (intern (format nil "TEST-~A" name) package))
         (recording-class (intern (format nil "RECORDING-~A" name) package))
         (events (intern (format nil "%~A-EVENTS" name) package))
         (reset-events (intern (format nil "%RESET-~A-EVENTS" name) package))
         (emit-event (intern (format nil "%~A-EMIT-EVENT" name) package))
         (emit-fn (intern (format nil "~A-EMIT-FN" name) package))
         (delegate (intern (format nil "RECORDING-~A-DELEGATE" name) package))
         (unsupported (format nil "Unsupported ~A type: ~~S" (string-downcase name))))
    `(progn
       (defmethod ,events ((,class ,class))
         (error ,unsupported ,class))

       (defgeneric ,reset-events (,class))
       (defmethod ,reset-events ((,class ,class))
         (error ,unsupported ,class))
       (defmethod ,reset-events ((,class ,test-class))
         (setf (,events ,class) nil))
       (defmethod ,reset-events ((,class ,recording-class))
         (setf (,events ,class) nil))

       (defgeneric ,emit-event (,class event))
       (defmethod ,emit-event ((,class ,class) event)
         (%emit-boundary-event (,emit-fn ,class) event))
       (defmethod ,emit-event ((,class ,test-class) event)
         (push (%copy-boundary-event event) (,events ,class))
         event)
       (defmethod ,emit-event ((,class ,recording-class) event)
         (push (%copy-boundary-event event) (,events ,class))
         (,emit-event (,delegate ,class) (%copy-boundary-event event))
         event))))

(defun plist-remove-keys (plist keys)
  (let ((filtered '())
        (removed-keys (make-hash-table :test 'eq)))
    (dolist (key keys)
      (setf (gethash key removed-keys) t))
    (do-plist (key value plist :result (nreverse filtered))
      (unless (gethash key removed-keys)
        (push key filtered)
        (push value filtered)))))
