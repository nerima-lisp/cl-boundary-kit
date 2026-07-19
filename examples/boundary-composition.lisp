;;;; examples/boundary-composition.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((context (cl-boundary-kit:make-boundary-context
                 :clock (cl-boundary-kit:make-fake-clock :start 7)
                 :filesystem (cl-boundary-kit:make-filesystem)))
       (clock (cl-boundary-kit:boundary-context-get context :clock))
       (filesystem (cl-boundary-kit:boundary-context-get context :filesystem)))
  (declare (ignore filesystem))
  (format t "~&clock: ~A~%" (cl-boundary-kit:clock-now clock)))
