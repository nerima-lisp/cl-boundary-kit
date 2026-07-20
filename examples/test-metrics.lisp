;;;; examples/test-metrics.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((metrics (cl-boundary-kit:make-test-metrics)))
  (cl-boundary-kit:metrics-count metrics "requests" 1)
  (cl-boundary-kit:metrics-gauge metrics "queue-depth" 7)
  (cl-boundary-kit:metrics-timing metrics "request-ms" 42)
  (format t "~&events: ~S~%" (cl-boundary-kit:recording-metric-events metrics)))
