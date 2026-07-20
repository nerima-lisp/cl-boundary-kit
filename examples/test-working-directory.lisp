;;;; examples/test-working-directory.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((wd (cl-boundary-kit:make-test-working-directory :initial #P"/home/take/")))
  (format t "~&before: ~A~%" (cl-boundary-kit:working-directory-get wd))
  (cl-boundary-kit:working-directory-set wd "/tmp/work/")
  (format t "~&after: ~A~%" (cl-boundary-kit:working-directory-get wd)))
