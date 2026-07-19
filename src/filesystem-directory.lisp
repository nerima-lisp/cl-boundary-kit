;;;; src/filesystem-directory.lisp

(in-package #:cl-boundary-kit)

(defun %real-filesystem-list-directory (directory)
  (directory (merge-pathnames (make-pathname :name :wild :type :wild :version :wild)
                              (pathname directory))))

(%define-recording-filesystem-operation filesystem-list-directory
    (filesystem directory)
    :list-directory
    (list directory)
    (funcall (%filesystem-list-directory-fn filesystem) directory)
  "Return the entries visible under DIRECTORY in FILESYSTEM.")
