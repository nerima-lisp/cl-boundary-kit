;;;; src/core.lisp

(in-package #:cl-boundary-kit)

(defstruct (boundary-context
            (:constructor %make-boundary-context (handlers)))
  handlers)

(defun make-boundary-context (&rest bindings)
  "Create a boundary context from keyword/value BINDINGS."
  (when (oddp (length bindings))
    (error "Boundary context bindings must come in keyword/value pairs: ~S" bindings))
  (let ((handlers (make-hash-table :test 'eq)))
    (loop for (key value) on bindings by #'cddr
          do (unless (keywordp key)
               (error "Boundary context keys must be keywords: ~S" key))
          do (setf (gethash key handlers) value))
    (%make-boundary-context handlers)))

(defun require-instance (value type name)
  (unless (typep value type)
    (error "~A must be a ~S: ~S" name type value))
  value)

(defun boundary-context-get (context key &optional default)
  "Return KEY from CONTEXT, or DEFAULT when KEY is absent."
  (require-instance context 'boundary-context "CONTEXT")
  (gethash key (boundary-context-handlers context) default))

(defun boundary-context-present-p (context key)
  "Return true when CONTEXT contains a binding for KEY."
  (require-instance context 'boundary-context "CONTEXT")
  (nth-value 1 (gethash key (boundary-context-handlers context))))

(defun require-function (value name)
  (unless (functionp value)
    (error "~A must be a function: ~S" name value))
  value)

(defun require-optional-function (value name)
  (when value
    (require-function value name))
  value)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setf (documentation 'boundary-context 'type)
        "Mapping from keyword boundary identifiers to boundary instances."))
