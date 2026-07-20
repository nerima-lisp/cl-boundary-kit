;;;; examples/test-feature-flags.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((flags (cl-boundary-kit:make-test-feature-flags
              :enabled '(:new-checkout :dark-mode))))
  (format t "~&new-checkout: ~A~%" (cl-boundary-kit:feature-enabled-p flags :new-checkout))
  (format t "~&legacy-flow: ~A~%" (cl-boundary-kit:feature-enabled-p flags :legacy-flow)))
