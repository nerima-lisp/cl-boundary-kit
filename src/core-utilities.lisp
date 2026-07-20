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
               (vector
                (let ((copy (copy-seq object)))
                  (dotimes (index (length copy) copy)
                    (setf (aref copy index) (copy-value (aref copy index))))))
               (t object))))
    (copy-value value)))

(defun %snapshot-recorded-calls (calls)
  "Return CALLS oldest-first as an independent snapshot.

CALLS is stored newest-first.  Both the returned spine and each call plist's
mutable structure is freshly copied, so a caller that destructively edits the
snapshot (for example SETF GETF or NREVERSE on a returned call's value)
cannot corrupt the boundary's own history."
  (mapcar #'%copy-boundary-value (reverse calls)))

(defun %copy-boundary-event (event)
  "Return an independent snapshot of EVENT."
  (%copy-boundary-value event))

(defun %snapshot-boundary-events (events)
  "Return EVENTS oldest-first as independent event snapshots."
  (mapcar #'%copy-boundary-event (reverse events)))

(defun %emit-boundary-event (emit-fn event)
  "Call EMIT-FN with a defensive copy of EVENT and return EVENT."
  (funcall emit-fn (%copy-boundary-event event))
  event)

(defun plist-remove-keys (plist keys)
  (let ((filtered '()))
    (do-plist (key value plist :result (nreverse filtered))
      (unless (member key keys :test #'eq)
        (push key filtered)
        (push value filtered)))))
