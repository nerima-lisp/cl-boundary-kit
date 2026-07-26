;;;; src/filesystem-store-cps.lisp

(in-package #:cl-boundary-kit)

(defun %filesystem-store-file/cps (filesystem path content if-exists if-does-not-exist
                                   external-format)
  (%with-recording-filesystem-call
      (filesystem
       :write-file
       (list path
             :content content
             :if-exists if-exists
             :if-does-not-exist if-does-not-exist
             :external-format external-format))
    (funcall (%filesystem-write-file-fn filesystem)
             path
             content
             :if-exists if-exists
             :if-does-not-exist if-does-not-exist
             :external-format external-format)))
