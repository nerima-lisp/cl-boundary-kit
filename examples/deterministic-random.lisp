;;;; examples/deterministic-random.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((source-a (cl-boundary-kit:make-deterministic-random-source :seed 42))
       (source-b (cl-boundary-kit:make-deterministic-random-source :seed 42))
       (sequence-a (list (cl-boundary-kit:random-source-random source-a 10)
                         (cl-boundary-kit:random-source-random source-a 10)
                         (cl-boundary-kit:random-source-random source-a 10)))
       (sequence-b (list (cl-boundary-kit:random-source-random source-b 10)
                         (cl-boundary-kit:random-source-random source-b 10)
                         (cl-boundary-kit:random-source-random source-b 10))))
  (format t "~&sequence-a: ~S~%" sequence-a)
  (format t "~&sequence-b: ~S~%" sequence-b)
  (format t "~&same-sequence: ~S~%" (equal sequence-a sequence-b)))
