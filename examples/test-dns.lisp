;;;; examples/test-dns.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((resolver (cl-boundary-kit:make-test-dns-resolver
                 :hosts '(("example.test" . ("192.0.2.1" "192.0.2.2"))))))
  (format t "~&addresses: ~S~%" (cl-boundary-kit:dns-resolve resolver "example.test"))
  (format t "~&unknown-signals: ~A~%"
          (handler-case (progn (cl-boundary-kit:dns-resolve resolver "absent.test") nil)
            (error () t))))
