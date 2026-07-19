;;;; src/filesystem-path-exists.lisp

(in-package #:cl-boundary-kit)

(%define-recording-filesystem-operation filesystem-path-exists-p
    (filesystem path)
    :path-exists-p
    (list path)
    (funcall (%filesystem-path-exists-p-fn filesystem) path)
  "Return true when PATH exists in FILESYSTEM.")
