;;;; examples/recording-boundary.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((boundary (cl-boundary-kit:make-recording-boundary
                 :handler (lambda (operation &rest args)
                            (list :operation operation
                                  :arguments args
                                  :status :ok)))))
  (format t "~&result: ~S~%"
          (cl-boundary-kit:recording-boundary-invoke boundary :ping 1 2))
  (format t "~&calls: ~S~%"
          (cl-boundary-kit:recording-boundary-calls boundary)))
