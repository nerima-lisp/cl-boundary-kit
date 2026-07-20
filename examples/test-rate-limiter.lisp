;;;; examples/test-rate-limiter.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((clock (cl-boundary-kit:make-fake-clock :start 0))
       (limiter (cl-boundary-kit:make-test-rate-limiter
                 :capacity 1 :refill-rate 1
                 :now-fn (lambda () (cl-boundary-kit:clock-now clock)))))
  (format t "~&first: ~A~%" (cl-boundary-kit:rate-limiter-allow-p limiter))
  (format t "~&throttled: ~A~%" (cl-boundary-kit:rate-limiter-allow-p limiter))
  (cl-boundary-kit:advance-fake-clock clock 1)
  (format t "~&after-refill: ~A~%" (cl-boundary-kit:rate-limiter-allow-p limiter)))
