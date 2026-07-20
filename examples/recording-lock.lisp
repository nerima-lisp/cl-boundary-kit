;;;; examples/recording-lock.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((delegate (cl-boundary-kit:make-test-lock))
       (lock (cl-boundary-kit:make-recording-lock :delegate delegate)))
  (cl-boundary-kit:lock-acquire lock)
  (format t "~&held: ~A~%" (cl-boundary-kit:test-lock-held-p delegate))
  (cl-boundary-kit:lock-release lock)
  (format t "~&released: ~A~%" (cl-boundary-kit:test-lock-held-p delegate))
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-lock-calls lock)))
