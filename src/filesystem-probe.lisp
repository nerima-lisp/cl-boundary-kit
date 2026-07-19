;;;; src/filesystem-probe.lisp

(in-package #:cl-boundary-kit)

(%define-recording-filesystem-operation filesystem-probe-file
    (filesystem path)
    :probe-file
    (list path)
    (funcall (%filesystem-probe-file-fn filesystem) path)
  "Return a pathname designator for PATH when it exists in FILESYSTEM, or NIL.")
