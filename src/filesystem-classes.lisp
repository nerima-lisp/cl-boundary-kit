;;;; src/filesystem-classes.lisp

(in-package #:cl-boundary-kit)

(defconstant +filesystem-type+ :filesystem)
(defconstant +test-filesystem-type+ :test)
(defconstant +recording-filesystem-type+ :recording)

(defun %make-filesystem-data (type &key read-file-fn write-file-fn probe-file-fn list-directory-fn path-exists-p-fn delete-file-fn copy-file-fn rename-file-fn make-directory-fn directory-exists-p-fn delete-directory-fn files calls delegate)
  (list :type type
        :read-file-fn read-file-fn
        :write-file-fn write-file-fn
        :probe-file-fn probe-file-fn
        :list-directory-fn list-directory-fn
        :path-exists-p-fn path-exists-p-fn
        :delete-file-fn delete-file-fn
        :copy-file-fn copy-file-fn
        :rename-file-fn rename-file-fn
        :make-directory-fn make-directory-fn
        :directory-exists-p-fn directory-exists-p-fn
        :delete-directory-fn delete-directory-fn
        :files files
        :calls calls
        :delegate delegate))

(define-plist-accessor %filesystem-type filesystem :type)

(define-plist-accessor %filesystem-read-file-fn filesystem :read-file-fn)

(define-plist-accessor %filesystem-write-file-fn filesystem :write-file-fn)

(define-plist-accessor %filesystem-probe-file-fn filesystem :probe-file-fn)

(define-plist-accessor %filesystem-list-directory-fn filesystem :list-directory-fn)

(define-plist-accessor %filesystem-path-exists-p-fn filesystem :path-exists-p-fn)

(define-plist-accessor %filesystem-delete-file-fn filesystem :delete-file-fn)

(define-plist-accessor %filesystem-copy-file-fn filesystem :copy-file-fn)

(define-plist-accessor %filesystem-rename-file-fn filesystem :rename-file-fn)

(define-plist-accessor %filesystem-make-directory-fn filesystem :make-directory-fn)

(define-plist-accessor %filesystem-directory-exists-p-fn filesystem :directory-exists-p-fn)

(define-plist-accessor %filesystem-delete-directory-fn filesystem :delete-directory-fn)

(define-plist-accessor %filesystem-calls-box filesystem :calls)

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

(defun %recording-or-test-filesystem-p (filesystem)
  (let ((type (%filesystem-type filesystem)))
    (or (eq type +test-filesystem-type+)
        (eq type +recording-filesystem-type+))))

(defmacro %with-recording-filesystem-call ((filesystem operation arguments) &body body)
  ;; :TEST and :RECORDING filesystems both record onto their OWN calls box
  ;; around the same BODY, which always calls FILESYSTEM's own (possibly
  ;; delegate-copied, but never itself self-recording) collaborator
  ;; functions -- never a delegate's public FILESYSTEM-READ-FILE etc.
  `(let ((filesystem (%require-filesystem ,filesystem)))
     (if (%recording-or-test-filesystem-p filesystem)
         (%recording-filesystem-call filesystem ,operation ,arguments
                                     (lambda () ,@body))
         (progn ,@body))))

(defmacro %define-recording-filesystem-operation (name lambda-list operation arguments direct-form &optional docstring)
  `(defun ,name ,lambda-list
     ,@(when docstring (list docstring))
     (let ((filesystem (%require-filesystem filesystem)))
       (%with-recording-filesystem-call (filesystem ,operation ,arguments)
         ,direct-form))))

(define-predicate-guarded-call-log recording-filesystem-calls reset-recording-filesystem-calls
    (filesystem (%require-filesystem filesystem)
     %recording-or-test-filesystem-p (car (%filesystem-calls-box filesystem))
     (%filesystem-type filesystem))
    "filesystem")

