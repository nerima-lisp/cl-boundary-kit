;;;; examples/recording-network.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((network (cl-boundary-kit:make-recording-network-boundary
                 :delegate (cl-boundary-kit:make-network-boundary
                            :request-fn (lambda (request &key timeout)
                                          (declare (ignore request timeout))
                                          '(:status 204)))))
       (response (cl-boundary-kit:network-boundary-request
                  network
                  '(:method :get :url "https://example.test")
                  :timeout 5)))
  (format t "~&response: ~S~%" response)
  (format t "~&calls: ~S~%"
          (cl-boundary-kit:recording-network-calls network)))
