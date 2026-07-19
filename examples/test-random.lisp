;;;; examples/test-random.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((source (cl-boundary-kit:make-test-random-source :values '(7 2 0.5d0)))
       (first (cl-boundary-kit:random-source-random source 10))
       (second (cl-boundary-kit:random-source-random source 10))
       (third (cl-boundary-kit:random-source-random source 1.0d0)))
  (format t "~&first: ~S~%" first)
  (format t "~&second: ~S~%" second)
  (format t "~&third: ~S~%" third))
