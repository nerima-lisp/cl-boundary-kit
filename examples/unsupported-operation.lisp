;;;; examples/unsupported-operation.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

;; SET-FN NIL opts an environment out of native mutation, e.g. when the
;; embedding application wants environment writes to fail loudly instead of
;; reaching a real process environment (make-environment's default SET-FN
;; does support real mutation via cl-host-kit).
(let ((environment (cl-boundary-kit:make-environment :set-fn nil)))
  (handler-case
      (cl-boundary-kit:environment-set environment "FEATURE_FLAG" "enabled")
    (cl-boundary-kit:unsupported-boundary-operation (condition)
      (format t "~&operation: ~S~%"
              (cl-boundary-kit:unsupported-boundary-operation-operation condition))
      (format t "~&detail: ~A~%"
              (cl-boundary-kit:unsupported-boundary-operation-detail condition)))))
