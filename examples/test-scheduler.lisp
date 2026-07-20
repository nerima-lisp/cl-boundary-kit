;;;; examples/test-scheduler.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((scheduler (cl-boundary-kit:make-test-scheduler))
      (log '()))
  (cl-boundary-kit:scheduler-schedule scheduler 5 (lambda () (push :first log) :first))
  (cl-boundary-kit:scheduler-schedule scheduler 10 (lambda () (push :second log) :second))
  (format t "~&pending: ~S~%" (cl-boundary-kit:test-scheduler-pending scheduler))
  (format t "~&results: ~S~%" (cl-boundary-kit:test-scheduler-run-pending scheduler))
  (format t "~&drained: ~S~%" (cl-boundary-kit:test-scheduler-pending scheduler)))
