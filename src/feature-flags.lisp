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

(define-name-validator %validate-feature-name name "Feature flag name")

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

(define-recording-boundary-constructor make-recording-feature-flags recording-feature-flags feature-flags (make-test-feature-flags)
  "Create a feature-flags boundary that records checks while delegating to
DELEGATE, which defaults to an all-off `make-test-feature-flags`."
  :enabled-fn nil)

(define-recording-call-log recording-feature-flag-calls reset-recording-feature-flag-calls
    (flags recording-feature-flags %recording-feature-flag-calls) "feature flags")

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
  (%sorted-hash-keys (test-feature-flags-enabled flags)))

(defmethod feature-enabled-p ((flags test-feature-flags) name)
  (%validate-feature-name name)
  (values (gethash name (test-feature-flags-enabled flags))))

(define-recording-delegate-method feature-enabled-p (flags recording-feature-flags recording-feature-flags-delegate %recording-feature-flag-calls)
    ((name) (name)) :enabled-p (list name)
  (%validate-feature-name name))

(define-recording-delegate-method feature-flags-enabled (flags recording-feature-flags recording-feature-flags-delegate %recording-feature-flag-calls)
    (() ()) :enabled-list '())
