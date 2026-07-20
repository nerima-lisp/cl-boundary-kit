;;;; examples/sequential-uuid.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((source (cl-boundary-kit:make-sequential-uuid-source :prefix "req" :start 0))
      (other (cl-boundary-kit:make-sequential-uuid-source :prefix "req" :start 0)))
  (format t "~&first: ~A~%" (cl-boundary-kit:uuid-generate source))
  (format t "~&second: ~A~%" (cl-boundary-kit:uuid-generate source))
  (format t "~&reproducible: ~A~%"
          (string= (cl-boundary-kit:uuid-generate other) "req-0000000000000000")))
