;;;; examples/test-network.lisp

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((network (cl-boundary-kit:make-test-network-boundary
                 :responses (list '(:status 200 :body "ok")
                                  '(:status 429 :body "slow down"))))
       (first (cl-boundary-kit:network-boundary-request
               network
               '(:method :get :url "https://example.test/ping")
               :timeout 2))
       (second (cl-boundary-kit:network-boundary-request
                network
                '(:method :post :url "https://example.test/jobs"))))
  (format t "~&first: ~S~%" first)
  (format t "~&second: ~S~%" second)
  (format t "~&calls: ~S~%" (cl-boundary-kit:recording-network-calls network)))
