;;;; examples/test-args.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((args (cl-boundary-kit:make-test-args
             :arguments (list "app" "--verbose" "input.txt"))))
  (format t "~&count: ~A~%" (cl-boundary-kit:args-count args))
  (format t "~&first: ~A~%" (cl-boundary-kit:args-nth args 0))
  (format t "~&list: ~S~%" (cl-boundary-kit:args-list args)))
