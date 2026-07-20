;;;; src/filesystem-move.lisp

(in-package #:cl-boundary-kit)

(defun %same-existing-file-p (source destination)
  (let ((source-truename (probe-file source))
        (destination-truename (probe-file destination)))
    (and source-truename
         destination-truename
         (equal (truename source-truename)
                (truename destination-truename)))))

(defun %real-filesystem-copy-file (source destination)
  "Copy SOURCE to DESTINATION on the real filesystem and return DESTINATION.

Copies raw bytes so binary content survives; DESTINATION is superseded if it
already exists. Uses only portable Common Lisp streams so this file still loads
in environments without UIOP (for example the examples bootstrap)."
  (when (%same-existing-file-p source destination)
    (error "Cannot copy file ~S to itself" source))
  (with-open-file (in source :element-type '(unsigned-byte 8))
    (with-open-file (out destination
                         :element-type '(unsigned-byte 8)
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (let ((buffer (make-array 32768 :element-type '(unsigned-byte 8))))
        (loop for count = (read-sequence buffer in)
              while (plusp count)
              do (write-sequence buffer out :end count)))))
  destination)

(defun %real-filesystem-rename-file (source destination)
  "Rename SOURCE to DESTINATION on the real filesystem and return DESTINATION.

Uses `cl:rename-file`, which is atomic on the same volume and preserves the
exact bytes, unlike a copy-then-delete."
  (when (%same-existing-file-p source destination)
    (error "Cannot rename file ~S to itself" source))
  (rename-file source destination)
  destination)

(%define-recording-filesystem-operation filesystem-copy-file
    (filesystem source destination)
    :copy-file
    (list source destination)
    (funcall (%filesystem-copy-file-fn filesystem) source destination)
  "Copy SOURCE to DESTINATION in FILESYSTEM and return DESTINATION.")

(%define-recording-filesystem-operation filesystem-rename-file
    (filesystem source destination)
    :rename-file
    (list source destination)
    (funcall (%filesystem-rename-file-fn filesystem) source destination)
  "Rename SOURCE to DESTINATION in FILESYSTEM and return DESTINATION.")
