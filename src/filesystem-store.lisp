;;;; src/filesystem-store.lisp

(in-package #:cl-boundary-kit)

(define-runtime-function filesystem-store-file (filesystem path content &rest options)
  "Write CONTENT to PATH through FILESYSTEM and return a truthy success value."
  (unless (evenp (length options))
    (error "Option list ended after ~S." (car (last options))))
  (let ((filesystem (%require-filesystem filesystem))
        (unknown-options
          (plist-remove-keys options '(:if-exists :if-does-not-exist :external-format))))
    (when unknown-options
      (error "Unknown filesystem write options: ~S" unknown-options))
    (%filesystem-store-file/cps
     filesystem
     path
     content
     (getf options :if-exists)
     (getf options :if-does-not-exist)
     (getf options :external-format))))
