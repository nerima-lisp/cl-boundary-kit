;;;; examples/recording-sleeper.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((sleeper (cl-boundary-kit:make-recording-sleeper)))
  (format t "~&slept: ~A~%" (cl-boundary-kit:sleeper-sleep sleeper 5))
  (format t "~&slept: ~A~%" (cl-boundary-kit:sleeper-sleep sleeper 0.25d0))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-sleeper-calls sleeper)))
