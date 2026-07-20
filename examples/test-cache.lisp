;;;; examples/test-cache.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((clock (cl-boundary-kit:make-fake-clock :start 0))
       (cache (cl-boundary-kit:make-test-cache
               :now-fn (lambda () (cl-boundary-kit:clock-now clock)))))
  (cl-boundary-kit:cache-put cache "session" "active" :ttl 10)
  (format t "~&before: ~A~%" (cl-boundary-kit:cache-get cache "session"))
  (cl-boundary-kit:advance-fake-clock clock 10)
  (format t "~&after-expiry: ~A~%" (cl-boundary-kit:cache-get cache "session" :expired)))
