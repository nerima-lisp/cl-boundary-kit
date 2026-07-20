;;;; examples/sequential-temp-path.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((source (cl-boundary-kit:make-sequential-temp-path-source
               :directory #P"/tmp/" :prefix "job" :suffix ".tmp")))
  (format t "~&first: ~A~%" (cl-boundary-kit:temp-path-next source))
  (format t "~&second: ~A~%" (cl-boundary-kit:temp-path-next source)))
