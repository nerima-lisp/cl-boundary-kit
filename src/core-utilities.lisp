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
    (string (cons command arguments))
    (list (append command arguments))))

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
  ;; COPY-TREE before storing so a caller that destructively edits an
  ;; :ARGUMENTS or :RESULT value it still holds a reference to (e.g. NREVERSE
  ;; on a returned list, SETF GETF on a returned plist) cannot corrupt the
  ;; boundary's own history; only cons structure is copied, so atoms like
  ;; pathnames stay shared.
  `(let ((call (list ,@initargs)))
     (push (copy-tree call) ,storage)
     call))

(defun %snapshot-recorded-calls (calls)
  "Return CALLS oldest-first as an independent snapshot.

CALLS is stored newest-first.  Both the returned spine and each call plist's
cons structure are freshly copied, so a caller that destructively edits the
snapshot (for example SETF GETF or NREVERSE on a returned call's value)
cannot corrupt the boundary's own history."
  (mapcar #'copy-tree (reverse calls)))

(defun plist-remove-keys (plist keys)
  (let ((filtered '()))
    (do-plist (key value plist :result (nreverse filtered))
      (unless (member key keys)
        (push key filtered)
        (push value filtered)))))
