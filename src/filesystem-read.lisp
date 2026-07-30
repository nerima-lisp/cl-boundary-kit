;;;; src/filesystem-read.lisp
(in-package #:cl-boundary-kit)

(progn
  (declaim (ftype function %real-filesystem-read-file))
  (defun %real-filesystem-read-file (path &key external-format)
    (with-open-file (stream path :direction :input :external-format (or external-format :default))
      (let* ((size (truncate (file-length stream)))
             (buffer (make-string size))
             (count (read-sequence buffer stream)))
        (if (= count size) buffer
          (subseq buffer 0 count))))))

(%define-recording-filesystem-operation
  filesystem-read-file
  (filesystem path &key external-format)
  :read-file
  (list path :external-format external-format)
  (funcall
    (%filesystem-read-file-fn filesystem)
    path
    :external-format
    external-format)
  "Return the textual contents of PATH from FILESYSTEM.")

(defun %split-file-lines (string)
  ;; READ-LINE semantics: each newline terminates a line and a trailing newline
  ;; does not yield a final empty line, so "a\nb\n" splits to ("a" "b").
  (with-input-from-string (stream string)
    (loop for line = (read-line stream nil nil)
          while line
          collect line)))

(defun filesystem-read-file-lines (filesystem path &key external-format)
  "Read PATH from FILESYSTEM and return its contents split into a list of lines.

Derived from `filesystem-read-file`, so it works across the native, test, and
recording variants and a recording filesystem records the underlying read. Line
splitting follows `read-line` semantics: a trailing newline does not produce a
final empty line."
  (%split-file-lines
    (filesystem-read-file filesystem path :external-format external-format)))
