;;;; examples/recording-uuid.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((delegate (cl-boundary-kit:make-test-uuid-source
                  :values (list "id-1" "id-2")))
       (source (cl-boundary-kit:make-recording-uuid-source :delegate delegate)))
  (format t "~&first: ~A~%" (cl-boundary-kit:uuid-generate source))
  (format t "~&second: ~A~%" (cl-boundary-kit:uuid-generate source))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-uuid-source-calls source)))
