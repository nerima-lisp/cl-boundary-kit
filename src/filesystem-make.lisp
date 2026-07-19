;;;; src/filesystem-make.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function make-filesystem (&key
                                          (read-file-fn #'%real-filesystem-read-file)
                                          (write-file-fn #'%real-filesystem-write-file)
                                          (probe-file-fn #'probe-file)
                                          (list-directory-fn #'%real-filesystem-list-directory)
                                          (path-exists-p-fn (lambda (path)
                                                              (not (null (probe-file path))))))
  "Create a filesystem boundary backed by the supplied function implementations."
  (require-function read-file-fn "READ-FILE-FN")
  (require-function write-file-fn "WRITE-FILE-FN")
  (require-function probe-file-fn "PROBE-FILE-FN")
  (require-function list-directory-fn "LIST-DIRECTORY-FN")
  (require-function path-exists-p-fn "PATH-EXISTS-P-FN")
  (%make-filesystem-data
   +filesystem-type+
   :read-file-fn read-file-fn
   :write-file-fn write-file-fn
   :probe-file-fn probe-file-fn
   :list-directory-fn list-directory-fn
   :path-exists-p-fn path-exists-p-fn))
