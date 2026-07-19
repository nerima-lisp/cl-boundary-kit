;;;; src/filesystem-directory.lisp

(in-package #:cl-boundary-kit)

(defun %ensure-directory-pathname (path)
  ;; A pathname built from a string without a trailing separator (e.g.
  ;; #P"/tmp/mydir") parses "mydir" as the NAME, so merging a wild
  ;; name/type onto it directly would list the *parent* directory instead.
  ;; Move any NAME/TYPE component into the directory list first.
  (if (or (pathname-name path) (pathname-type path))
      (make-pathname :directory (append (or (pathname-directory path) '(:relative))
                                        (list (file-namestring path)))
                     :name nil :type nil :version nil
                     :defaults path)
      path))

(defun %real-filesystem-list-directory (directory)
  (directory (merge-pathnames (make-pathname :name :wild :type :wild :version :wild)
                              (%ensure-directory-pathname (pathname directory)))))

(%define-recording-filesystem-operation filesystem-list-directory
    (filesystem directory)
    :list-directory
    (list directory)
    (funcall (%filesystem-list-directory-fn filesystem) directory)
  "Return the entries visible under DIRECTORY in FILESYSTEM.")
