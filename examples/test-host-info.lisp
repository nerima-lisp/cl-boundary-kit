;;;; examples/test-host-info.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((host (cl-boundary-kit:make-test-host-info
             :hostname "build-01" :username "ci" :pid 4242)))
  (format t "~&hostname: ~A~%" (cl-boundary-kit:host-info-hostname host))
  (format t "~&username: ~A~%" (cl-boundary-kit:host-info-username host))
  (format t "~&pid: ~A~%" (cl-boundary-kit:host-info-pid host)))
