;;;; src/filesystem-recording-constructor.lisp

(in-package #:cl-boundary-kit)

(defun make-recording-filesystem (&key delegate)
  "Create a filesystem boundary that records calls before returning DELEGATE results."
  (let ((delegate (%require-filesystem (or delegate (make-filesystem)) "DELEGATE")))
    (%make-filesystem-data
     +recording-filesystem-type+
     :read-file-fn (getf delegate :read-file-fn)
     :write-file-fn (getf delegate :write-file-fn)
     :probe-file-fn (getf delegate :probe-file-fn)
     :list-directory-fn (getf delegate :list-directory-fn)
     :path-exists-p-fn (getf delegate :path-exists-p-fn)
     :delete-file-fn (getf delegate :delete-file-fn)
     :copy-file-fn (getf delegate :copy-file-fn)
     :rename-file-fn (getf delegate :rename-file-fn)
     :make-directory-fn (getf delegate :make-directory-fn)
     :directory-exists-p-fn (getf delegate :directory-exists-p-fn)
     :delete-directory-fn (getf delegate :delete-directory-fn)
     :calls (list nil)
     :delegate delegate)))
