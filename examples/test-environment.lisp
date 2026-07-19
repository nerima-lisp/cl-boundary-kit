;;;; examples/test-environment.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((environment (cl-boundary-kit:make-test-environment
                     :initial-values '("PATH" "/usr/bin"
                                       "EMPTY" nil)))
       (path (cl-boundary-kit:environment-get environment "PATH" "missing"))
       (empty (cl-boundary-kit:environment-get environment "EMPTY" "fallback"))
       (missing (cl-boundary-kit:environment-present-p environment "MISSING")))
  (cl-boundary-kit:environment-set environment "HOME" "/tmp/home")
  (format t "~&PATH: ~A~%" path)
  (format t "~&EMPTY: ~S~%" empty)
  (format t "~&MISSING?: ~S~%" missing)
  (format t "~&HOME: ~A~%" (cl-boundary-kit:environment-get environment "HOME" "missing"))
  (format t "~&entries: ~S~%" (cl-boundary-kit:environment-list environment))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-environment-calls environment)))
