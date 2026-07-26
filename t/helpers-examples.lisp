;;;; t/helpers-examples.lisp

(in-package #:cl-boundary-kit/test)

(defparameter +example-process-timeout+ 10)

(defun example-path-name (path)
  (subseq path (length "examples/")))

(defun readme-example-paths ()
  (let ((examples-doc (repository-file-string "docs/src/examples.md")))
    (sort (markdown-example-paths examples-doc) #'string<)))

(defun %run-example (name)
  (let ((*standard-output* (make-string-output-stream))
        (*error-output* (make-string-output-stream))
        (*package* *package*)
        (*readtable* *readtable*)
        (*default-pathname-defaults* *default-pathname-defaults*))
    (load (repository-pathname (format nil "examples/~A" name)))
    (concatenate 'string
                 (get-output-stream-string *standard-output*)
                 (get-output-stream-string *error-output*))))

(defun run-example-in-fresh-sbcl (path &key (timeout +example-process-timeout+))
  (let ((sbcl-program (namestring sb-ext:*runtime-pathname*))
        (example-path (namestring (repository-pathname path))))
    (uiop:run-program (list sbcl-program "--script" example-path)
                      :directory (repository-root)
                      :timeout timeout
                      :output :string
                      :error-output :string
                      :ignore-error-status t)))
