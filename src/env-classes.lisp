;;;; src/env-classes.lisp

(in-package #:cl-boundary-kit)

(defclass env-boundary ()
  ((kind :initarg :kind
         :reader environment-kind)
   (get-fn :initarg :get-fn
           :initform nil
           :reader environment-get-fn)
   (set-fn :initarg :set-fn
           :initform nil
           :reader environment-set-fn)
   (unset-fn :initarg :unset-fn
             :initform nil
             :reader environment-unset-fn)
   (list-fn :initarg :list-fn
            :initform nil
            :reader environment-list-fn)
   (delegate :initarg :delegate :initform nil)
   (calls :initarg :calls
          :initform nil
          :accessor %environment-calls)))

(defun %make-native-environment (options)
  (let ((get-fn (%plist-value options :get-fn #'%native-environment-get))
        (set-fn (%plist-value options :set-fn #'%native-environment-set))
        (unset-fn (%plist-value options :unset-fn #'%native-environment-unset))
        (list-fn (%plist-value options :list-fn #'%native-environment-list)))
    (require-function get-fn "GET-FN")
    (require-optional-function set-fn "SET-FN")
    (require-optional-function unset-fn "UNSET-FN")
    (require-function list-fn "LIST-FN")
    (%make-env-boundary
     :kind :native
     :get-fn get-fn
     :set-fn set-fn
     :unset-fn unset-fn
     :list-fn list-fn)))

(%define-plist-constructor make-environment
    "Create a native environment boundary from plist OPTIONS."
    %make-native-environment)

(defun %make-test-environment (options)
  (let ((table (%seed-environment-bindings
                (%plist-value options :initial-values nil))))
    (%make-env-boundary
     :kind :test
     :get-fn (lambda (name)
               (gethash name table))
     :set-fn (lambda (name value)
               (setf (gethash name table) value))
     :unset-fn (lambda (name)
                 (remhash name table))
     :list-fn (lambda ()
                (%sorted-environment-entries-from-table table)))))

(%define-plist-constructor make-test-environment
    "Create a deterministic test environment boundary from plist OPTIONS."
    %make-test-environment)

(defun %make-recording-environment (options)
  ;; Default to a native delegate, matching every sibling recording
  ;; constructor (make-recording-filesystem -> make-filesystem,
  ;; make-recording-process-boundary -> make-process-boundary): a caller
  ;; asking for "no delegate" expects the real environment, not a fake
  ;; that always reports missing/nil bindings.
  (let ((delegate (%plist-value options :delegate (make-environment))))
    (require-instance delegate 'env-boundary "DELEGATE")
    ;; Copy the delegate's own collaborators (transitively raw even when
    ;; DELEGATE is itself a recording environment) instead of routing calls
    ;; through the delegate's public ENVIRONMENT-GET/-SET/-LIST functions.
    ;; Recursing through those would re-enter the delegate's own recording
    ;; path when it is a :TEST-kind environment, double-recording every
    ;; call: once here, once on the delegate's own history.
    (%make-env-boundary
     :kind :recording
     :delegate delegate
     :get-fn (environment-get-fn delegate)
     :set-fn (environment-set-fn delegate)
     :unset-fn (environment-unset-fn delegate)
     :list-fn (environment-list-fn delegate))))

(%define-plist-constructor make-recording-environment
    "Create a recording environment boundary from plist OPTIONS."
    %make-recording-environment)

(%define-recording-environment-operation environment-get
    (environment name &optional default)
    :get
    (list name)
    (%environment-value-from-call
     (%environment-values (environment-get-fn environment) name)
     default)
  "Return the value bound to NAME in ENVIRONMENT or DEFAULT.")

(%define-recording-environment-operation environment-present-p
    (environment name)
    :present-p
    (list name)
    (%environment-presence-from-call
     (%environment-values (environment-get-fn environment) name))
  "Return true when NAME is bound in ENVIRONMENT.")

(%define-recording-environment-operation environment-list
    (environment)
    :list
    nil
    (funcall (environment-list-fn environment))
  "Return the bindings visible in ENVIRONMENT.")

(%define-recording-environment-operation environment-set
    (environment name value)
    :set
    (list name value)
    (let ((setter (environment-set-fn environment)))
      (if setter
          (funcall setter name value)
          (unsupported-operation 'environment-set
                                 "native environment mutation is unavailable")))
  "Bind NAME to VALUE in ENVIRONMENT and return VALUE.")

(%define-recording-environment-operation environment-unset
    (environment name)
    :unset
    (list name)
    (let ((unsetter (environment-unset-fn environment)))
      (if unsetter
          (and (funcall unsetter name) t)
          (unsupported-operation 'environment-unset
                                 "native environment mutation is unavailable")))
  "Remove NAME from ENVIRONMENT and return whether it was bound.")

(defun call-with-environment-variable (environment name value thunk)
  "Temporarily bind NAME to VALUE in ENVIRONMENT for the duration of THUNK.

Sets NAME to VALUE, calls THUNK, and then restores NAME's previous value (or
unsets it when it was absent) in an `unwind-protect` cleanup, so a non-local exit
still restores it. Returns THUNK's value. Requires an environment that supports
`environment-set` (and `environment-unset` when NAME was absent). A recording
environment records the set and the restoring set or unset."
  (require-function thunk "THUNK")
  (let* ((present (environment-present-p environment name))
         (previous (and present (environment-get environment name))))
    (environment-set environment name value)
    (unwind-protect (funcall thunk)
      (if present
          (environment-set environment name previous)
          (environment-unset environment name)))))

(define-predicate-guarded-call-log recording-environment-calls reset-recording-environment-calls
    (environment (require-instance environment 'env-boundary "ENVIRONMENT")
     %recording-or-test-environment-p (%environment-calls environment)
     (environment-kind environment))
    "environment")

