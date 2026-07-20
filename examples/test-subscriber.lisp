;;;; examples/test-subscriber.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((subscriber (cl-boundary-kit:make-test-subscriber
                   :messages (list "job-1" "job-2"))))
  (format t "~&first: ~A~%" (cl-boundary-kit:subscriber-poll subscriber))
  (format t "~&second: ~A~%" (cl-boundary-kit:subscriber-poll subscriber))
  (format t "~&drained: ~A~%" (cl-boundary-kit:subscriber-poll subscriber)))
