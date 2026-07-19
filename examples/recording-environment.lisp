;;;; examples/recording-environment.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((environment (cl-boundary-kit:make-recording-environment
                     :delegate (cl-boundary-kit:make-test-environment
                                :initial-values '("PATH" "/usr/bin"
                                                  "EMPTY" nil))))
       (path (cl-boundary-kit:environment-get environment "PATH" "missing"))
       (empty (cl-boundary-kit:environment-get environment "EMPTY" "fallback")))
  (format t "~&PATH: ~A~%" path)
  (format t "~&EMPTY: ~S~%" empty)
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-environment-calls environment)))
