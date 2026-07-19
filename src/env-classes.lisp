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
   (list-fn :initarg :list-fn
            :initform nil
            :reader environment-list-fn)
   (delegate :initarg :delegate
             :initform nil
             :reader recording-environment-delegate)
   (calls :initarg :calls
          :initform nil
          :accessor %environment-calls)))

(defun %make-native-environment (options)
  (multiple-value-bind (get-fn get-supplied-p)
      (%plist-ref-values options :get-fn #'%native-environment-get)
    (declare (ignore get-supplied-p))
    (multiple-value-bind (set-fn set-supplied-p)
        (%plist-ref-values options :set-fn nil)
      (declare (ignore set-supplied-p))
      (multiple-value-bind (list-fn list-supplied-p)
          (%plist-ref-values options :list-fn #'%native-environment-list)
        (declare (ignore list-supplied-p))
        (require-function get-fn "GET-FN")
        (require-optional-function set-fn "SET-FN")
        (require-function list-fn "LIST-FN")
        (%make-env-boundary
         :kind :native
         :get-fn get-fn
         :set-fn set-fn
         :list-fn list-fn)))))

(%define-plist-constructor make-environment
    "Create a native environment boundary from plist OPTIONS."
    %make-native-environment)

(defun %make-test-environment (options)
  (multiple-value-bind (initial-values initial-values-supplied-p)
      (%plist-ref-values options :initial-values nil)
    (declare (ignore initial-values-supplied-p))
    (%seed-environment-bindings-cps
     initial-values
     (lambda (entries)
       (let ((state entries))
         (%make-env-boundary
          :kind :test
          :get-fn (lambda (name)
                    (let ((cell (%environment-entry-cell state name)))
                      (if cell
                          (values (cdr cell) t)
                          (values nil nil))))
          :set-fn (lambda (name value)
                    (setf state (%upsert-environment-entry state name value))
                    value)
          :list-fn (lambda ()
                     (%sorted-environment-entries state))))))))

(%define-plist-constructor make-test-environment
    "Create a deterministic test environment boundary from plist OPTIONS."
    %make-test-environment)

(defun %make-recording-environment (options)
  (multiple-value-bind (delegate delegate-supplied-p)
      (%plist-ref-values options :delegate (make-test-environment))
    (declare (ignore delegate-supplied-p))
    (require-instance delegate 'env-boundary "DELEGATE")
    (%make-env-boundary
     :kind :recording
     :delegate delegate
     :get-fn nil
     :set-fn nil
     :list-fn nil)))

(%define-plist-constructor make-recording-environment
    "Create a recording environment boundary from plist OPTIONS."
    %make-recording-environment)

(%define-recording-environment-operation environment-get
    (environment name &optional default)
    :get
    (list name)
    (environment-get (recording-environment-delegate environment) name default)
    (%environment-value-from-call
     (%environment-values (environment-get-fn environment) name)
     default)
  "Return the value bound to NAME in ENVIRONMENT or DEFAULT.")

(%define-recording-environment-operation environment-present-p
    (environment name)
    :present-p
    (list name)
    (environment-present-p (recording-environment-delegate environment) name)
    (%environment-presence-from-call
     (%environment-values (environment-get-fn environment) name))
  "Return true when NAME is bound in ENVIRONMENT.")

(%define-recording-environment-operation environment-list
    (environment)
    :list
    nil
    (environment-list (recording-environment-delegate environment))
    (funcall (environment-list-fn environment))
  "Return the bindings visible in ENVIRONMENT.")

(%define-recording-environment-operation environment-set
    (environment name value)
    :set
    (list name value)
    (environment-set (recording-environment-delegate environment) name value)
    (let ((setter (environment-set-fn environment)))
      (if setter
          (funcall setter name value)
          (unsupported-operation 'environment-set
                                 "native environment mutation is unavailable")))
  "Bind NAME to VALUE in ENVIRONMENT and return VALUE.")

(defun recording-environment-calls (environment)
  "Return the recorded environment calls in call order."
  (%with-environment (environment)
    (%snapshot-recorded-calls (%environment-calls environment))))
