;;;; src/core.lisp

(in-package #:cl-boundary-kit)

(defstruct (boundary-context
            (:constructor %make-boundary-context (handlers)))
  handlers)

(defun %populate-boundary-context-handlers (handlers bindings)
  (when (oddp (length bindings))
    (error "Boundary context bindings must come in keyword/value pairs: ~S" bindings))
  (loop for (key value) on bindings by #'cddr
        do (unless (keywordp key)
             (error "Boundary context keys must be keywords: ~S" key))
        do (setf (gethash key handlers) value))
  handlers)

(defun make-boundary-context (&rest bindings)
  "Create a boundary context from keyword/value BINDINGS."
  (%make-boundary-context
   (%populate-boundary-context-handlers (make-hash-table :test 'eq) bindings)))

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

(defun boundary-context-keys (context)
  "Return the keys bound in CONTEXT, in no particular order."
  (require-instance context 'boundary-context "CONTEXT")
  (loop for key being the hash-keys of (boundary-context-handlers context)
        collect key))

(defun boundary-context-count (context)
  "Return the number of bindings in CONTEXT."
  (require-instance context 'boundary-context "CONTEXT")
  (hash-table-count (boundary-context-handlers context)))

(defun boundary-context-alist (context)
  "Return CONTEXT's bindings as a fresh alist of (key . value) pairs.

The pairs are in no particular order; sort by key if a stable order is needed.
Useful for inspecting or serializing a whole context at once."
  (require-instance context 'boundary-context "CONTEXT")
  (let ((pairs '()))
    (maphash (lambda (key value) (push (cons key value) pairs))
             (boundary-context-handlers context))
    pairs))

(defun boundary-context-with (context &rest bindings)
  "Return a new boundary context derived from CONTEXT with keyword/value
BINDINGS applied as overrides on top of CONTEXT's existing bindings."
  (require-instance context 'boundary-context "CONTEXT")
  (let ((handlers (make-hash-table :test 'eq)))
    (maphash (lambda (key value) (setf (gethash key handlers) value))
             (boundary-context-handlers context))
    (%make-boundary-context (%populate-boundary-context-handlers handlers bindings))))

(defun boundary-context-require (context key)
  "Return KEY from CONTEXT, signaling an error when KEY is absent.

Unlike `boundary-context-get`, this never silently substitutes a default, so it
is the fail-fast reader for wiring code that must not run with a missing
boundary."
  (require-instance context 'boundary-context "CONTEXT")
  (multiple-value-bind (value present)
      (gethash key (boundary-context-handlers context))
    (unless present
      (error "Boundary context has no binding for ~S; bound keys are ~S"
             key (boundary-context-keys context)))
    value))

(defun boundary-context-remove (context &rest keys)
  "Return a new boundary context derived from CONTEXT without KEYS.

CONTEXT is left unchanged. Removing a key that is absent is a no-op."
  (require-instance context 'boundary-context "CONTEXT")
  (let ((handlers (make-hash-table :test 'eq)))
    (maphash (lambda (key value)
               (unless (member key keys)
                 (setf (gethash key handlers) value)))
             (boundary-context-handlers context))
    (%make-boundary-context handlers)))

(defun boundary-context-merge (context other)
  "Return a new boundary context with OTHER's bindings layered over CONTEXT's.

Both inputs are left unchanged. When both contexts bind the same key, OTHER's
binding wins, matching the override semantics of `boundary-context-with`."
  (require-instance context 'boundary-context "CONTEXT")
  (require-instance other 'boundary-context "OTHER")
  (let ((handlers (make-hash-table :test 'eq)))
    (maphash (lambda (key value) (setf (gethash key handlers) value))
             (boundary-context-handlers context))
    (maphash (lambda (key value) (setf (gethash key handlers) value))
             (boundary-context-handlers other))
    (%make-boundary-context handlers)))

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
