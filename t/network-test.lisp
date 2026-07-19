;;;; t/network-test.lisp

(in-package #:cl-boundary-kit/test)

(defmacro with-network-boundary ((network constructor &rest constructor-args) &body body)
  `(let ((,network (,constructor ,@constructor-args)))
     ,@body))

(defmacro with-network-calls ((calls &rest call-specs) &body body)
  `(let ((,calls (list ,@(mapcar (lambda (spec)
                                   `(network-call ,@spec))
                                 call-specs))))
     ,@body))

(defun network-request-summary (&key request timeout status)
  (list :request request :timeout timeout :status status))

(defun network-call (&key request timeout result)
  (list :request request :timeout timeout :result result))

(it "network-boundary-uses-request-handler"
  (with-network-boundary (network make-network-boundary
                                  :request-fn (lambda (request &key timeout)
                                                (network-request-summary :request request
                                                                          :timeout timeout
                                                                          :status 200)))
    (expect (equal (network-boundary-request network '(:method :get :url "https://example.test"))
               '(:request (:method :get :url "https://example.test") :timeout nil :status 200)) :to-be-truthy)))

(it "network-boundary-forwards-timeout"
  (with-network-boundary (network make-network-boundary
                                  :request-fn (lambda (request &key timeout)
                                                (network-request-summary :request request
                                                                          :timeout timeout
                                                                          :status 202)))
    (expect (equal (network-boundary-request network '(:method :post :url "https://example.test/jobs")
                                         :timeout 15)
               '(:request (:method :post :url "https://example.test/jobs") :timeout 15 :status 202)) :to-be-truthy)))

(it "make-network-boundary-requires-request-handler"
  (signals error
    (make-network-boundary)))

(it "make-network-boundary-rejects-non-function-transport"
  (signals error
    (make-network-boundary :request-fn :bad)))

(it "test-network-boundary-consumes-queued-responses-and-records-calls"
  (with-network-boundary (network make-test-network-boundary
                                  :responses (list '(:status 200 :body "ok")
                                                   '(:status 503 :body "retry")))
    (expect (equal (network-boundary-request network '(:method :get :url "https://example.test/ok")
                                         :timeout 1)
               '(:status 200 :body "ok")) :to-be-truthy)
    (expect (equal (network-boundary-request network '(:method :post :url "https://example.test/retry"))
               '(:status 503 :body "retry")) :to-be-truthy)
    (with-network-calls (calls
                         (:request '(:method :get :url "https://example.test/ok")
                                   :timeout 1
                                   :result '(:status 200 :body "ok"))
                         (:request '(:method :post :url "https://example.test/retry")
                                   :timeout nil
                                   :result '(:status 503 :body "retry")))
      (expect (equal calls
                 (recording-network-calls network)) :to-be-truthy))))

(it "test-network-boundary-signals-when-responses-are-exhausted"
  (with-network-boundary (network make-test-network-boundary :responses nil)
    (signals error
      (network-boundary-request network '(:method :get :url "https://example.test/missing")))))

(it "test-network-boundary-preserves-explicit-nil-responses-in-call-history"
  (with-network-boundary (network make-test-network-boundary :responses (list nil))
    (expect (null (network-boundary-request network '(:method :get :url "https://example.test/noop"))) :to-be-truthy)
    (with-network-calls (calls
                         (:request '(:method :get :url "https://example.test/noop")
                                   :timeout nil
                                   :result nil))
      (expect (equal calls
                 (recording-network-calls network)) :to-be-truthy))))

(it "make-test-network-boundary-rejects-non-list-responses"
  (signals error
    (make-test-network-boundary :responses :bad)))

(it "recording-network-boundary-records"
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-network-boundary
                                             :request-fn (lambda (request &key timeout)
                                                           (declare (ignore request timeout))
                                                           '(:status 204))))
    (let ((result (network-boundary-request network '(:method :get :url "https://example.test")
                                            :timeout 5)))
      (expect (equal result '(:status 204)) :to-be-truthy)
      (with-network-calls (calls
                           (:request '(:method :get :url "https://example.test")
                                     :timeout 5
                                     :result '(:status 204)))
        (expect (equal calls
                   (recording-network-calls network)) :to-be-truthy)))))

(it "make-recording-network-boundary-requires-delegate"
  (signals error
    (make-recording-network-boundary)))

(it "recording-network-boundary-preserves-explicit-nil-responses-in-call-history"
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-network-boundary
                                             :request-fn (lambda (request &key timeout)
                                                           (declare (ignore request timeout))
                                                           nil)))
    (expect (null (network-boundary-request network '(:method :get :url "https://example.test/noop"))) :to-be-truthy)
    (with-network-calls (calls
                         (:request '(:method :get :url "https://example.test/noop")
                                   :timeout nil
                                   :result nil))
      (expect (equal calls
                 (recording-network-calls network)) :to-be-truthy))))

(it "make-recording-network-boundary-rejects-non-network-delegate"
  (signals error
    (make-recording-network-boundary :delegate :bad)))

(it "recording-network-calls-signals-for-unsupported-boundary-types"
  (signals-error-message-contains "Unsupported network boundary type"
      (recording-network-calls
       (make-network-boundary
        :request-fn (lambda (request &key timeout)
                      (declare (ignore request timeout))
                      '(:status 204))))))
