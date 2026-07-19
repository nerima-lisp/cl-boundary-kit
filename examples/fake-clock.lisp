;;;; examples/fake-clock.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((clock (cl-boundary-kit:make-fake-clock :start 100)))
  (format t "~&before: ~A~%" (cl-boundary-kit:clock-now clock))
  (cl-boundary-kit:advance-fake-clock clock 10)
  (format t "~&after: ~A~%" (cl-boundary-kit:clock-now clock)))
