;;;; src/filesystem-delete.lisp

(in-package #:cl-boundary-kit)

(defun %real-filesystem-delete-file (path)
  "Delete PATH from the real filesystem, returning whether it existed.

Returns T when PATH existed and was deleted, and NIL when it was already absent,
matching the delete contract shared with `kv-delete` and `cache-evict`."
  (when (probe-file path)
    (delete-file path)
    t))

(%define-recording-filesystem-operation filesystem-delete-file
    (filesystem path)
    :delete-file
    (list path)
    (funcall (%filesystem-delete-file-fn filesystem) path)
  "Delete PATH from FILESYSTEM and return whether it existed.")
