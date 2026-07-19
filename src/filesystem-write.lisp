;;;; src/filesystem-write.lisp

(in-package #:cl-boundary-kit)

(defun %call-with-filesystem-output-stream (path if-exists if-does-not-exist external-format thunk)
  (let ((stream (if external-format
                    (open path
                          :direction :output
                          :if-exists if-exists
                          :if-does-not-exist if-does-not-exist
                          :external-format external-format)
                    (open path
                          :direction :output
                          :if-exists if-exists
                          :if-does-not-exist if-does-not-exist))))
    (unwind-protect
         (funcall thunk stream)
      (when stream
        (close stream)))))

(defun %real-filesystem-write-file (path content &key if-exists if-does-not-exist external-format)
  (let ((if-exists (or if-exists :supersede))
        (if-does-not-exist (or if-does-not-exist :create)))
    (%call-with-filesystem-output-stream
     path
     if-exists
     if-does-not-exist
     external-format
     (lambda (stream)
       (write-string content stream))))
  t)
