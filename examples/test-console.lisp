;;;; examples/test-console.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let ((console (cl-boundary-kit:make-test-console
                :input-lines (list "alice" "bob"))))
  (let ((name (cl-boundary-kit:console-read-line console)))
    (cl-boundary-kit:console-write-line console (format nil "hello, ~A" name)))
  (cl-boundary-kit:console-write-error console "second line missing")
  (format t "~&first-input: ~A~%" "alice")
  (format t "~&at-eof: ~A~%"
          (progn (cl-boundary-kit:console-read-line console)
                 (cl-boundary-kit:console-read-line console)))
  (format t "~&output: ~S~%" (cl-boundary-kit:test-console-output console))
  (format t "~&errors: ~S~%" (cl-boundary-kit:test-console-errors console)))
