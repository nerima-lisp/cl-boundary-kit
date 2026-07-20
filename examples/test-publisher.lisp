;;;; examples/test-publisher.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((publisher (cl-boundary-kit:make-test-publisher)))
  (cl-boundary-kit:publisher-publish publisher "orders" "created:42")
  (cl-boundary-kit:publisher-publish publisher "orders" "shipped:42")
  (format t "~&messages: ~S~%" (cl-boundary-kit:recording-published-messages publisher)))
