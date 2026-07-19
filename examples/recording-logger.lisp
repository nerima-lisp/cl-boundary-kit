;;;; examples/recording-logger.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((forwarded '())
       (logger (cl-boundary-kit:make-recording-logger
                :delegate (cl-boundary-kit:make-logger
                           :timestamp-fn (lambda () 42)
                           :sink-fn (lambda (event)
                                      (push event forwarded)))))
       (event (cl-boundary-kit:logger-log logger :info "example" :user "take"))
       (recorded (first (cl-boundary-kit:recording-log-events logger)))
       (sink-event (first forwarded)))
  (format t "~&event: ~S~%" event)
  (format t "~&same-recorded: ~S~%" (eq event recorded))
  (format t "~&same-forwarded: ~S~%" (eq event sink-event))
  (format t "~&forwarded: ~S~%" forwarded)
  (format t "~&events: ~S~%" (cl-boundary-kit:recording-log-events logger)))
