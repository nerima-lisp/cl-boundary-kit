;;;; src/filesystem-read.lisp

(in-package #:cl-boundary-kit)

(defun %real-filesystem-read-file (path &key external-format)
  (with-open-file (stream path
                          :direction :input
                          :external-format (or external-format :default))
    ;; FILE-LENGTH counts octets; with a multibyte external format the file
    ;; holds fewer characters than octets, so READ-SEQUENCE fills only a prefix
    ;; of BUFFER and returns that fill index.  Truncate to it, otherwise the
    ;; unread tail keeps MAKE-STRING's fill character and corrupts the result.
    (let* ((buffer (make-string (file-length stream)))
           (count (read-sequence buffer stream)))
      (if (= count (length buffer))
          buffer
          (subseq buffer 0 count)))))

(%define-recording-filesystem-operation filesystem-read-file
    (filesystem path &key external-format)
    :read-file
    (list path :external-format external-format)
    (funcall (%filesystem-read-file-fn filesystem)
             path
             :external-format external-format)
  "Return the textual contents of PATH from FILESYSTEM.")
