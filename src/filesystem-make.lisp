;;;; src/filesystem-make.lisp

(in-package #:cl-boundary-kit)

(defun make-filesystem (&key
                                          (read-file-fn #'%real-filesystem-read-file)
                                          (write-file-fn #'%real-filesystem-write-file)
                                          (probe-file-fn #'probe-file)
                                          (list-directory-fn #'%real-filesystem-list-directory)
                                          (path-exists-p-fn (lambda (path)
                                                              (not (null (probe-file path)))))
                                          (delete-file-fn #'%real-filesystem-delete-file)
                                          (copy-file-fn #'%real-filesystem-copy-file)
                                          (rename-file-fn #'%real-filesystem-rename-file)
                                          (make-directory-fn #'%real-filesystem-make-directory)
                                          (directory-exists-p-fn #'%real-filesystem-directory-exists-p)
                                          (delete-directory-fn #'%real-filesystem-delete-directory))
  "Create a filesystem boundary backed by the supplied function implementations."
  (require-function read-file-fn "READ-FILE-FN")
  (require-function write-file-fn "WRITE-FILE-FN")
  (require-function probe-file-fn "PROBE-FILE-FN")
  (require-function list-directory-fn "LIST-DIRECTORY-FN")
  (require-function path-exists-p-fn "PATH-EXISTS-P-FN")
  (require-function delete-file-fn "DELETE-FILE-FN")
  (require-function copy-file-fn "COPY-FILE-FN")
  (require-function rename-file-fn "RENAME-FILE-FN")
  (require-function make-directory-fn "MAKE-DIRECTORY-FN")
  (require-function directory-exists-p-fn "DIRECTORY-EXISTS-P-FN")
  (require-function delete-directory-fn "DELETE-DIRECTORY-FN")
  (%make-filesystem-data
   +filesystem-type+
   :read-file-fn read-file-fn
   :write-file-fn write-file-fn
   :probe-file-fn probe-file-fn
   :list-directory-fn list-directory-fn
   :path-exists-p-fn path-exists-p-fn
   :delete-file-fn delete-file-fn
   :copy-file-fn copy-file-fn
   :rename-file-fn rename-file-fn
   :make-directory-fn make-directory-fn
   :directory-exists-p-fn directory-exists-p-fn
   :delete-directory-fn delete-directory-fn))
