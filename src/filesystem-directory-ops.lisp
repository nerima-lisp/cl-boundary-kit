;;;; src/filesystem-directory-ops.lisp

(in-package #:cl-boundary-kit)

(defun %ensure-directory-pathname (path)
  ;; A pathname built from a string without a trailing separator (e.g.
  ;; #P"/tmp/mydir") parses "mydir" as the NAME, so move any NAME/TYPE
  ;; component into the directory list once instead of round-tripping through
  ;; NAMESTRING on every directory operation.
  (if (or (pathname-name path) (pathname-type path))
      (make-pathname :directory (append (or (pathname-directory path) '(:relative))
                                        (list (file-namestring path)))
                     :name nil :type nil :version nil
                     :defaults path)
      path))

(defun %filesystem-directory-pathname (path)
  "Return PATH as a directory pathname (with a trailing separator).

Uses only portable Common Lisp string manipulation so this file loads without
UIOP (for example the examples bootstrap)."
  (%ensure-directory-pathname (pathname path)))

(defun %real-filesystem-make-directory (path)
  "Create the directory PATH on the real filesystem and return its pathname."
  (let ((directory (%filesystem-directory-pathname path)))
    (ensure-directories-exist directory)
    directory))

(defun %real-filesystem-directory-exists-p (path)
  "Return whether the directory PATH exists on the real filesystem."
  (not (null (probe-file (%filesystem-directory-pathname path)))))

(defun %real-filesystem-delete-directory (path)
  "Delete the empty directory PATH from the real filesystem, returning whether it
existed. Resolves UIOP:DELETE-EMPTY-DIRECTORY at call time via FIND-SYMBOL so
this file loads without UIOP present."
  (let ((directory (%filesystem-directory-pathname path)))
    (when (probe-file directory)
      (let ((deleter (and (find-package "UIOP")
                          (find-symbol "DELETE-EMPTY-DIRECTORY" "UIOP"))))
        (if deleter
            (progn (funcall deleter directory) t)
            (unsupported-operation 'filesystem-delete-directory
                                   "no host directory deletion function is available"))))))

(%define-recording-filesystem-operation filesystem-make-directory
    (filesystem path)
    :make-directory
    (list path)
    (funcall (%filesystem-make-directory-fn filesystem) path)
  "Create the directory PATH in FILESYSTEM and return its pathname.")

(%define-recording-filesystem-operation filesystem-directory-exists-p
    (filesystem path)
    :directory-exists-p
    (list path)
    (funcall (%filesystem-directory-exists-p-fn filesystem) path)
  "Return whether the directory PATH exists in FILESYSTEM.")

(%define-recording-filesystem-operation filesystem-delete-directory
    (filesystem path)
    :delete-directory
    (list path)
    (funcall (%filesystem-delete-directory-fn filesystem) path)
  "Delete the empty directory PATH from FILESYSTEM and return whether it existed.")
