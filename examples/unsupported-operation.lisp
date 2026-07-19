;;;; examples/unsupported-operation.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((environment (cl-boundary-kit:make-environment)))
  (handler-case
      (cl-boundary-kit:environment-set environment "FEATURE_FLAG" "enabled")
    (cl-boundary-kit:unsupported-boundary-operation (condition)
      (format t "~&operation: ~S~%"
              (cl-boundary-kit:unsupported-boundary-operation-operation condition))
      (format t "~&detail: ~A~%"
              (cl-boundary-kit:unsupported-boundary-operation-detail condition)))))
