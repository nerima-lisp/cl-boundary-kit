;;;; examples/test-system.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((system (cl-boundary-kit:make-test-system-boundary)))
  (format t "~&default-code: ~A~%" (cl-boundary-kit:system-exit system))
  (format t "~&explicit-code: ~A~%" (cl-boundary-kit:system-exit system 2))
  (format t "~&exit-codes: ~S~%" (cl-boundary-kit:test-system-exit-codes system)))
