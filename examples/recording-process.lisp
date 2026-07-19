;;;; examples/recording-process.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((process (cl-boundary-kit:make-recording-process-boundary
                 :delegate (cl-boundary-kit:make-process-boundary
                            :run-fn (lambda (command &key arguments input directory environment output error-output timeout)
                                      (declare (ignore input directory environment output error-output timeout))
                                      (list :command (append command arguments)
                                            :stdout "ok"
                                            :stderr ""
                                            :exit-code 0)))))
       (result (cl-boundary-kit:process-boundary-run process '("demo" "--mode")
                                                     :arguments '("arg"))))
  (format t "~&result: ~S~%" result)
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-process-calls process)))
