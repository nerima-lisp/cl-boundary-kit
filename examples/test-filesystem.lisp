;;;; examples/test-filesystem.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((path #P"tmp/example.txt")
       (filesystem (cl-boundary-kit:make-test-filesystem
                    :initial-files (list path "hello"))))
  (format t "~&before: ~S~%" (cl-boundary-kit:filesystem-read-file filesystem path))
  (cl-boundary-kit:filesystem-store-file filesystem path " world" :if-exists :append)
  (format t "~&after: ~S~%" (cl-boundary-kit:filesystem-read-file filesystem path))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-filesystem-calls filesystem)))
