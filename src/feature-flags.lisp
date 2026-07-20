;;;; src/feature-flags.lisp

(in-package #:cl-boundary-kit)

(defclass feature-flags ()
  ((enabled-fn :initarg :enabled-fn :reader feature-flags-enabled-fn)
   (enabled-list-fn :initarg :enabled-list-fn :initform nil :reader feature-flags-enabled-list-fn)))

(defclass test-feature-flags (feature-flags)
  ((enabled :initarg :enabled :reader test-feature-flags-enabled)))

(defclass recording-feature-flags (feature-flags)
  ((delegate :initarg :delegate :reader recording-feature-flags-delegate)
   (calls :initform '() :accessor %recording-feature-flag-calls)))

(defun %validate-feature-name (name)
  (unless (or (stringp name) (and (symbolp name) name))
    (error "Feature flag name must be a non-nil symbol or a string: ~S" name))
  name)

(defun %validate-enabled-feature-names (enabled)
  (unless (listp enabled)
    (error "Enabled feature flags must be a list: ~S" enabled))
  (dolist (name enabled enabled)
    (%validate-feature-name name)))

(defun make-feature-flags (&key enabled-fn enabled-list-fn)
  "Create a feature-flags boundary backed by ENABLED-FN.

`feature-enabled-p` calls ENABLED-FN with a flag name and returns whether it is
on. `feature-flags-enabled` calls the optional ENABLED-LIST-FN with no arguments
and should return the currently-enabled flag names, or signals an
unsupported-operation when it is omitted. Wire the collaborators to a real flag
backend at the application edge; they are validated at construction time."
  (require-function enabled-fn "ENABLED-FN")
  (require-optional-function enabled-list-fn "ENABLED-LIST-FN")
  (make-instance 'feature-flags :enabled-fn enabled-fn :enabled-list-fn enabled-list-fn))

(defun make-test-feature-flags (&key enabled)
  "Create an in-memory feature-flags fake whose ENABLED flags are on.

ENABLED is a list of flag names (symbols or strings) that are on; every other
flag is off. Names are compared with `equal`."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (name (%validate-enabled-feature-names enabled))
      (setf (gethash name table) t))
    (make-instance 'test-feature-flags :enabled-fn nil :enabled table)))

(defun make-recording-feature-flags (&key (delegate (make-test-feature-flags)))
  "Create a feature-flags boundary that records checks while delegating to
DELEGATE, which defaults to an all-off `make-test-feature-flags`."
  (require-instance delegate 'feature-flags "DELEGATE")
  (make-instance 'recording-feature-flags :enabled-fn nil :delegate delegate))

(defun recording-feature-flag-calls (flags)
  "Return the recorded feature-flag calls in call order."
  (unless (typep flags 'recording-feature-flags)
    (error "Unsupported feature flags type: ~S" flags))
  (%snapshot-recorded-calls (%recording-feature-flag-calls flags)))

(defun reset-recording-feature-flag-calls (flags)
  "Clear FLAGS's recorded call history and return FLAGS.

A recording feature-flags boundary otherwise retains every call for the object's
whole lifetime; call this periodically to bound memory growth instead of only
being able to reclaim it by discarding the object."
  (unless (typep flags 'recording-feature-flags)
    (error "Unsupported feature flags type: ~S" flags))
  (setf (%recording-feature-flag-calls flags) nil)
  flags)

(defun call-if-feature-enabled (flags name thunk &optional disabled-thunk)
  "If feature NAME is enabled in FLAGS, call THUNK and return its value; otherwise
call DISABLED-THUNK (when supplied) and return its value, or return NIL.

Checks the flag through `feature-enabled-p`, so it works with any feature-flags
boundary and a recording one records the check. This is the feature-gated
counterpart of `call-if-allowed`, expressing the common \"new path when on, old
path when off\" pattern."
  (require-function thunk "THUNK")
  (when disabled-thunk
    (require-function disabled-thunk "DISABLED-THUNK"))
  (if (feature-enabled-p flags name)
      (funcall thunk)
      (when disabled-thunk (funcall disabled-thunk))))

(defmethod feature-enabled-p ((flags feature-flags) name)
  (%validate-feature-name name)
  (and (funcall (feature-flags-enabled-fn flags) name) t))

(defmethod feature-flags-enabled ((flags feature-flags))
  (let ((list-fn (feature-flags-enabled-list-fn flags)))
    (if list-fn
        (funcall list-fn)
        (unsupported-operation 'feature-flags-enabled
                               "feature flag enumeration is unavailable"))))

(defmethod feature-flags-enabled ((flags test-feature-flags))
  (sort (loop for name being the hash-keys of (test-feature-flags-enabled flags)
              collect name)
        #'string<
        :key #'princ-to-string))

(defmethod feature-enabled-p ((flags test-feature-flags) name)
  (%validate-feature-name name)
  (values (gethash name (test-feature-flags-enabled flags))))

(defmethod feature-enabled-p ((flags recording-feature-flags) name)
  (%validate-feature-name name)
  (let ((result (feature-enabled-p (recording-feature-flags-delegate flags) name)))
    (%record-call (%recording-feature-flag-calls flags)
      :operation :enabled-p
      :arguments (list name)
      :result result)
    result))

(defmethod feature-flags-enabled ((flags recording-feature-flags))
  (let ((result (feature-flags-enabled (recording-feature-flags-delegate flags))))
    (%record-call (%recording-feature-flag-calls flags)
      :operation :enabled-list
      :arguments '()
      :result result)
    result))
