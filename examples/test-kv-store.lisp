;;;; examples/test-kv-store.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((store (cl-boundary-kit:make-test-kv-store :initial '(("alpha" . 1)))))
  (cl-boundary-kit:kv-put store "beta" 2)
  (format t "~&alpha: ~A~%" (cl-boundary-kit:kv-get store "alpha"))
  (multiple-value-bind (value present)
      (cl-boundary-kit:kv-get store "missing" :default)
    (format t "~&missing: ~A present: ~A~%" value present))
  (format t "~&deleted-beta: ~A~%" (cl-boundary-kit:kv-delete store "beta"))
  (format t "~&keys: ~S~%" (cl-boundary-kit:kv-keys store)))
