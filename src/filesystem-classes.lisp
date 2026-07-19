;;;; src/filesystem-classes.lisp

(in-package #:cl-boundary-kit)

(defconstant +filesystem-type+ :filesystem)
(defconstant +test-filesystem-type+ :test)
(defconstant +recording-filesystem-type+ :recording)

(defun %make-filesystem-data (type &key read-file-fn write-file-fn probe-file-fn list-directory-fn path-exists-p-fn files calls delegate)
  (list :type type
        :read-file-fn read-file-fn
        :write-file-fn write-file-fn
        :probe-file-fn probe-file-fn
        :list-directory-fn list-directory-fn
        :path-exists-p-fn path-exists-p-fn
        :files files
        :calls calls
        :delegate delegate))

(defun %filesystem-type (filesystem)
  (getf filesystem :type))

(defun %filesystem-read-file-fn (filesystem)
  (getf filesystem :read-file-fn))

(defun %filesystem-write-file-fn (filesystem)
  (getf filesystem :write-file-fn))

(defun %filesystem-probe-file-fn (filesystem)
  (getf filesystem :probe-file-fn))

(defun %filesystem-list-directory-fn (filesystem)
  (getf filesystem :list-directory-fn))

(defun %filesystem-path-exists-p-fn (filesystem)
  (getf filesystem :path-exists-p-fn))

(defun %filesystem-calls-box (filesystem)
  (getf filesystem :calls))

(defun %require-filesystem (filesystem &optional (name "FILESYSTEM"))
  (unless (listp filesystem)
    (error "~A must be a filesystem: ~S" name filesystem))
  (unless (%filesystem-type filesystem)
    (error "~A must be a filesystem: ~S" name filesystem))
  filesystem)

(defun %recording-filesystem-call (filesystem operation arguments thunk)
  (let ((result (funcall thunk)))
    (%record-call (car (%filesystem-calls-box filesystem))
      :operation operation
      :arguments arguments
      :result result)
    result))

(defun %recording-filesystem-p (filesystem)
  (eq (%filesystem-type filesystem) +recording-filesystem-type+))

(defmacro %with-recording-filesystem-call ((filesystem operation arguments) &body body)
  `(let ((filesystem (%require-filesystem ,filesystem)))
     (if (%recording-filesystem-p filesystem)
         (%recording-filesystem-call filesystem ,operation ,arguments
                                     (lambda () ,@body))
         (progn ,@body))))

(defmacro %define-recording-filesystem-operation (name lambda-list operation arguments direct-form &optional docstring)
  `(defun ,name ,lambda-list
     ,@(when docstring (list docstring))
     (let ((filesystem (%require-filesystem filesystem)))
       (%with-recording-filesystem-call (filesystem ,operation ,arguments)
         ,direct-form))))

(defun recording-filesystem-calls (filesystem)
  "Return the recorded filesystem calls in call order."
  (let ((filesystem (%require-filesystem filesystem)))
    (if (member (%filesystem-type filesystem)
                (list +test-filesystem-type+ +recording-filesystem-type+)
                :test #'eq)
        (%snapshot-recorded-calls (car (%filesystem-calls-box filesystem)))
        (error "Unsupported filesystem type: ~S" (%filesystem-type filesystem)))))
