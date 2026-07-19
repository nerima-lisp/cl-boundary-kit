;;;; examples/test-logger.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((logger (cl-boundary-kit:make-test-logger :timestamp-fn (lambda () 101)))
       (event (cl-boundary-kit:logger-log logger :warn "test-only" :request-id "req-9"))
       (recorded (first (cl-boundary-kit:recording-log-events logger))))
  (format t "~&event: ~S~%" event)
  (format t "~&same-recorded: ~S~%" (eq event recorded))
  (format t "~&events: ~S~%" (cl-boundary-kit:recording-log-events logger)))
