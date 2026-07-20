;;;; examples/recording-secret.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((delegate (cl-boundary-kit:make-test-secret-store
                  :initial '(("api-token" . "s3cr3t"))))
       (store (cl-boundary-kit:make-recording-secret-store :delegate delegate)))
  (format t "~&value: ~A~%" (cl-boundary-kit:secret-get store "api-token"))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-secret-calls store)))
