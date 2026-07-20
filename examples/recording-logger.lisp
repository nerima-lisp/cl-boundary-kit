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
  (format t "~&equal-recorded: ~S~%" (equal event recorded))
  (format t "~&independent-recorded: ~S~%" (not (eq event recorded)))
  (format t "~&equal-forwarded: ~S~%" (equal event sink-event))
  (format t "~&independent-forwarded: ~S~%" (not (eq event sink-event)))
  (format t "~&forwarded: ~S~%" forwarded)
  (format t "~&events: ~S~%" (cl-boundary-kit:recording-log-events logger)))
