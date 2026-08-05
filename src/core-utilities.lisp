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

(defmacro define-list-validator (name parameter noun &optional element-spec)
  "Define NAME as a validator that signals an error naming NOUN unless PARAMETER
is a list, and returns PARAMETER unchanged.

ELEMENT-SPEC, when supplied, additionally checks every element. It has the same
shape as DEFINE-SCALAR-VALIDATOR's trailing arguments -- (ELEMENT PREDICATE
DESCRIPTION ELEMENT-NOUN) -- where PREDICATE is a form written in terms of
ELEMENT and ELEMENT-NOUN names a single element in its error message."
  (destructuring-bind (&optional element predicate description element-noun) element-spec
    `(defun ,name (,parameter)
       (unless (listp ,parameter)
         (error ,(format nil "~A must be a list: ~~S" noun) ,parameter))
       ,@(when element-spec
           `((dolist (,element ,parameter)
               (unless ,predicate
                 (error ,(format nil "~A must be ~A: ~~S" element-noun description)
                        ,element)))))
       ,parameter)))

(defmacro define-name-validator (name parameter noun)
  "Define NAME as a validator that signals an error naming NOUN unless PARAMETER
is a non-nil symbol or a string, and returns PARAMETER unchanged."
  `(defun ,name (,parameter)
     (unless (or (stringp ,parameter) (and (symbolp ,parameter) ,parameter))
       (error ,(format nil "~A must be a non-nil symbol or a string: ~~S" noun) ,parameter))
     ,parameter))

(defmacro define-scalar-validator (name parameter predicate description noun)
  "Define NAME as a validator that signals an error unless PREDICATE holds for
PARAMETER, and returns PARAMETER unchanged.

PREDICATE is a form written in terms of PARAMETER, so it can be any test rather
than a single function. DESCRIPTION completes the message NOUN must be
DESCRIPTION. NOUN is either a string, naming the value in every message, or a
symbol, which becomes a second required parameter of NAME supplying that name at
run time."
  (let ((extra (unless (stringp noun) (list noun))))
    `(defun ,name (,parameter ,@extra)
       (unless ,predicate
         (error ,(if (stringp noun)
                     (format nil "~A must be ~A: ~~S" noun description)
                     (format nil "~~A must be ~A: ~~S" description))
                ,@extra
                ,parameter))
       ,parameter)))

(defmacro define-plist-accessor (name parameter key &optional docstring)
  "Define NAME as a reader returning KEY's value from the PARAMETER plist argument."
  `(progn
     (declaim (inline ,name))
     (defun ,name (,parameter)
       ,@(when docstring (list docstring))
       (getf ,parameter ,key))))

(defmacro define-recording-boundary-constructor
    (name recording-class base-class default-delegate-form docstring &rest extra-initargs)
  "Define NAME as a constructor for RECORDING-CLASS that validates its DELEGATE
keyword argument (defaulting to DEFAULT-DELEGATE-FORM) against BASE-CLASS, then
wraps it in RECORDING-CLASS with EXTRA-INITARGS spliced ahead of :DELEGATE
DELEGATE. DOCSTRING becomes NAME's docstring."
  `(defun ,name (&key (delegate ,default-delegate-form))
     ,docstring
     (require-instance delegate ',base-class "DELEGATE")
     (make-instance ',recording-class ,@extra-initargs :delegate delegate)))

(defmacro %record-call (storage &rest initargs)
  ;; Copy each value form before storing so a caller that destructively edits
  ;; an :ARGUMENTS or :RESULT value it still holds a reference to (e.g.
  ;; NREVERSE on a returned list, SETF GETF on a returned plist) cannot
  ;; corrupt the boundary's own history. INITARGS keys are always literal
  ;; keywords, so only the value forms need copying -- copying values while
  ;; building CALL's spine, rather than deep-copying the already-fresh CALL
  ;; list afterward, avoids re-consing that spine a second time.
  `(let ((call (list ,@(loop for (key form) on initargs by #'cddr
                              collect key
                              collect `(%copy-boundary-value ,form)))))
     (push call ,storage)
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

(defun %hash-table-get-present (table key default)
  "Return (VALUES value t) when KEY is present in TABLE, else (VALUES DEFAULT nil)."
  (multiple-value-bind (value present) (gethash key table)
    (if present
        (values value t)
        (values default nil))))

(defun %sorted-hash-keys (table)
  ;; Compute each key's PRINC-TO-STRING once, here, and carry it alongside
  ;; the key for the sort key -- SORT's :KEY function can otherwise re-run
  ;; the same string conversion per comparison (O(n log n) calls) rather
  ;; than once per entry. See %SORTED-TEST-DIRECTORY-ENTRIES-IN for the
  ;; same fix applied to filesystem fake directory listings.
  (let ((keys '()))
    (maphash (lambda (key value)
               (declare (ignore value))
               (push (cons key (princ-to-string key)) keys))
             table)
    (mapcar #'car (sort keys #'string< :key #'cdr))))

(defun %emit-boundary-event (emit-fn event)
  "Call EMIT-FN with a defensive copy of EVENT and return EVENT."
  (funcall emit-fn (%copy-boundary-event event))
  event)

(defmacro define-emit-event-boundary-dispatch (class)
  "Generate the classes and CLOS plumbing shared by every emit-style event boundary.

An emit boundary sinks each event three ways depending on its concrete class:
the plain CLASS forwards through its own emit-fn, TEST-<CLASS> buffers the event
in memory, and RECORDING-<CLASS> buffers it and then forwards to its delegate.
This macro emits the whole boundary once, deriving every name from CLASS:

  * CLASS itself, holding the EMIT-FN slot read by <CLASS>-EMIT-FN;
  * TEST-<CLASS> and RECORDING-<CLASS>, each holding an event buffer accessed by
    %<CLASS>-EVENTS, with RECORDING-<CLASS> also holding the DELEGATE slot read
    by RECORDING-<CLASS>-DELEGATE;
  * a %<CLASS>-EVENTS base method that rejects unsupported boundary types (the
    reader itself is the slot accessor on the test/recording classes);
  * the %RESET-<CLASS>-EVENTS generic that clears a buffer's history; and
  * the %<CLASS>-EMIT-EVENT generic implementing the three-way sink above."
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
       (defclass ,class ()
         ((emit-fn :initarg :emit-fn :reader ,emit-fn)))

       (defclass ,test-class (,class)
         ((events :initform '() :accessor ,events)))

       (defclass ,recording-class (,class)
         ((delegate :initarg :delegate :reader ,delegate)
          (events :initform '() :accessor ,events)))

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
         ;; No copy for the delegate call: whichever ,EMIT-EVENT method
         ;; handles EVENT next (plain/test/recording) always makes its own
         ;; defensive copy before storing or forwarding it further, so a copy
         ;; made here just to hand off would be discarded unused.
         (,emit-event (,delegate ,class) event)
         event))))

(defun plist-remove-keys (plist keys)
  ;; KEYS is always a short, fixed list of keywords at every call site here,
  ;; so a linear MEMBER scan avoids allocating a hash-table per call.
  (let ((filtered '()))
    (do-plist (key value plist :result (nreverse filtered))
      (unless (member key keys :test #'eq)
        (push key filtered)
        (push value filtered)))))
