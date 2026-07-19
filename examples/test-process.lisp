;;;; examples/test-process.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((process (cl-boundary-kit:make-test-process-boundary
                 :results (list '(:stdout "ok" :stderr "" :exit-code 0)
                                '(:stdout "warn" :stderr "note" :exit-code 1))))
       (first (cl-boundary-kit:process-boundary-run process "demo" :arguments '("--help")))
       (second (cl-boundary-kit:process-boundary-run process "demo-2")))
  (format t "~&first: ~S~%" first)
  (format t "~&second: ~S~%" second)
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-process-calls process)))
