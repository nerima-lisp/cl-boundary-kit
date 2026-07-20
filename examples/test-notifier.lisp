;;;; examples/test-notifier.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((notifier (cl-boundary-kit:make-test-notifier)))
  (cl-boundary-kit:notifier-notify notifier "ops@example.test" "Deploy" "Build 42 shipped")
  (format t "~&notifications: ~S~%" (cl-boundary-kit:recording-sent-notifications notifier)))
