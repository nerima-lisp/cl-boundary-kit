;;;; examples/test-semaphore.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((semaphore (cl-boundary-kit:make-test-semaphore :permits 2)))
  (format t "~&start: ~A~%" (cl-boundary-kit:semaphore-available semaphore))
  (cl-boundary-kit:semaphore-acquire semaphore)
  (cl-boundary-kit:semaphore-acquire semaphore)
  (format t "~&drained: ~A~%" (cl-boundary-kit:semaphore-available semaphore))
  (cl-boundary-kit:semaphore-release semaphore)
  (format t "~&after-release: ~A~%" (cl-boundary-kit:semaphore-available semaphore)))
