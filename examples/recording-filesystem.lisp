;;;; examples/recording-filesystem.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((filesystem (cl-boundary-kit:make-recording-filesystem
                    :delegate (cl-boundary-kit:make-filesystem
                               :write-file-fn (lambda (path content
                                                   &key if-exists if-does-not-exist external-format)
                                                (declare (ignore path content if-exists if-does-not-exist external-format))
                                                t))))
       (path #P"example.txt")
       (result (cl-boundary-kit:filesystem-store-file filesystem path "hello"
                                                      :if-exists :append
                                                      :if-does-not-exist :create
                                                      :external-format :utf-8)))
  (format t "~&result: ~S~%" result)
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-filesystem-calls filesystem)))
