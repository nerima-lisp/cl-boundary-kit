;;;; src/working-directory.lisp

(in-package #:cl-boundary-kit)

(defclass working-directory ()
  ((get-fn :initarg :get-fn :reader working-directory-get-fn)
   (set-fn :initarg :set-fn :reader working-directory-set-fn)))

(defclass test-working-directory (working-directory)
  ((current :initarg :current :accessor %test-working-directory-current)))

(defclass recording-working-directory (working-directory)
  ((delegate :initarg :delegate :reader recording-working-directory-delegate)
   (calls :initform '() :accessor %recording-working-directory-calls)))

(defun %validate-working-directory-path (path)
  (unless (or (pathnamep path) (stringp path))
    (error "Working directory path must be a pathname or string: ~S" path))
  (pathname path))

(defun make-working-directory (&key
                                 (get-fn (lambda () *default-pathname-defaults*))
                                 (set-fn (lambda (path)
                                           (setf *default-pathname-defaults* path))))
  "Create a working-directory boundary from GET-FN and SET-FN.

`working-directory-get` calls GET-FN with no arguments and `working-directory-set`
calls SET-FN with the requested pathname. The defaults read and update
`*default-pathname-defaults*`, the process-wide base Common Lisp resolves
relative pathnames against, so the default path touches real process state.
Both collaborators are validated at construction time."
  (require-function get-fn "GET-FN")
  (require-function set-fn "SET-FN")
  (make-instance 'working-directory :get-fn get-fn :set-fn set-fn))

(defun make-test-working-directory (&key (initial #P"/"))
  "Create an in-memory working-directory fake starting at INITIAL.

`working-directory-set` updates the stored directory and returns it, and
`working-directory-get` returns the current stored directory, so tests can drive
directory-dependent code without changing the real process directory."
  (make-instance 'test-working-directory
                 :get-fn nil :set-fn nil
                 :current (%validate-working-directory-path initial)))

(defun make-recording-working-directory (&key (delegate (make-test-working-directory)))
  "Create a working-directory boundary that records calls while delegating to DELEGATE.

DELEGATE defaults to a `make-test-working-directory`, so recording never changes
the real process directory unless you pass a delegate that does."
  (require-instance delegate 'working-directory "DELEGATE")
  (make-instance 'recording-working-directory
                 :get-fn nil :set-fn nil
                 :delegate delegate))

(define-recording-call-log recording-working-directory-calls reset-recording-working-directory-calls
    (working-directory recording-working-directory %recording-working-directory-calls)
    "working directory")

(defun call-with-working-directory (working-directory path thunk)
  "Temporarily set WORKING-DIRECTORY to PATH for the duration of THUNK, then
restore the previous directory in an `unwind-protect` cleanup so a non-local exit
still restores it. Return THUNK's value. A recording working directory records
both directory changes."
  (require-function thunk "THUNK")
  (let ((previous (working-directory-get working-directory)))
    (working-directory-set working-directory path)
    (unwind-protect (funcall thunk)
      (working-directory-set working-directory previous))))

(defmethod working-directory-get ((working-directory working-directory))
  (funcall (working-directory-get-fn working-directory)))

(defmethod working-directory-set ((working-directory working-directory) path)
  (funcall (working-directory-set-fn working-directory)
           (%validate-working-directory-path path)))

(defmethod working-directory-get ((working-directory test-working-directory))
  (%test-working-directory-current working-directory))

(defmethod working-directory-set ((working-directory test-working-directory) path)
  (setf (%test-working-directory-current working-directory)
        (%validate-working-directory-path path)))

(defmethod working-directory-get ((working-directory recording-working-directory))
  (let ((result (working-directory-get (recording-working-directory-delegate working-directory))))
    (%record-call (%recording-working-directory-calls working-directory)
      :operation :get
      :arguments '()
      :result result)
    result))

(defmethod working-directory-set ((working-directory recording-working-directory) path)
  (let* ((normalized (%validate-working-directory-path path))
         (result (working-directory-set (recording-working-directory-delegate working-directory)
                                        normalized)))
    (%record-call (%recording-working-directory-calls working-directory)
      :operation :set
      :arguments (list normalized)
      :result result)
    result))
