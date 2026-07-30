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

(it "test-network-boundary-copies-seeded-response-list"
  (let* ((first-response '(:status 200 :body "ok"))
         (second-response '(:status 503 :body "retry"))
         (responses (list first-response second-response))
         (network (make-test-network-boundary :responses responses)))
    (setf (first responses) '(:status 500 :body "changed")
          (rest responses) nil)
    (expect (equal first-response
                   (network-boundary-request
                    network
                    '(:method :get :url "https://example.test/ok"))) :to-be-truthy)
    (expect (equal second-response
                   (network-boundary-request
                    network
                    '(:method :get :url "https://example.test/retry"))) :to-be-truthy)))

(it "test-network-boundary-copies-mutable-seeded-response-strings"
  (let* ((response (copy-seq "HELLO-WORLD"))
         (network (make-test-network-boundary :responses (list response))))
    (setf (char response 0) #\J)
    (expect (string= "HELLO-WORLD"
                     (network-boundary-request
                      network
                      '(:method :get :url "https://example.test/string")))
            :to-be-truthy)
    (setf (char response 1) #\A)
    (expect (equal (list (network-call
                          :request '(:method :get :url "https://example.test/string")
                          :timeout nil
                          :result "HELLO-WORLD"))
                   (recording-network-calls network))
            :to-be-truthy)))

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

(it "recording-network-boundary-redacts-sensitive-call-history-by-default"
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-network-boundary
                                             :request-fn (lambda (request &key timeout)
                                                           (declare (ignore request timeout))
                                                           '(:status 200
                                                             :headers ((:set-cookie . "session=secret")
                                                                       (:content-type . "application/json"))
                                                             :body "{\"token\":\"secret\"}"))))
    (let ((result (network-boundary-request
                   network
                   '(:method :post
                     :url "https://example.test/token"
                     :headers ((:authorization . "Bearer secret")
                               (:x-api-key . "key")
                               (:accept . "application/json"))
                     :body "password=secret")
                   :timeout 5)))
      (expect (equal result
                 '(:status 200
                   :headers ((:set-cookie . "session=secret")
                             (:content-type . "application/json"))
                   :body "{\"token\":\"secret\"}"))
              :to-be-truthy)
      (with-network-calls (calls
                           (:request '(:method :post
                                       :url "https://example.test/token"
                                       :headers ((:authorization . :redacted)
                                                 (:x-api-key . :redacted)
                                                 (:accept . "application/json"))
                                       :body :redacted)
                                     :timeout 5
                                     :result '(:status 200
                                               :headers ((:set-cookie . :redacted)
                                                         (:content-type . "application/json"))
                                               :body :redacted)))
        (expect (equal calls
                   (recording-network-calls network)) :to-be-truthy)))))

(it "recording-network-boundary-redacts-through-proper-list-and-dotted-pair-values"
  ;; Exercises the non-plist/non-alist arms of %REDACT-NETWORK-VALUE: a proper
  ;; list of scalars is redacted element-wise, and a dotted pair is rebuilt car
  ;; and cdr. Neither field is sensitive, so both shapes pass through intact --
  ;; the point is that redaction traverses them without corrupting structure.
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-network-boundary
                                             :request-fn (lambda (request &key timeout)
                                                           (declare (ignore request timeout))
                                                           '(:status 200 :cursor (10 . 20)))))
    (network-boundary-request network '(:method :get :tags ("a" "b" "c") :cursor (1 . 2)) :timeout 3)
    (with-network-calls (calls
                         (:request '(:method :get :tags ("a" "b" "c") :cursor (1 . 2))
                                   :timeout 3
                                   :result '(:status 200 :cursor (10 . 20))))
      (expect (equal calls (recording-network-calls network)) :to-be-truthy))))

(it "recording-network-boundary-allows-explicit-full-fidelity-history"
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-network-boundary
                                             :request-fn (lambda (request &key timeout)
                                                           (declare (ignore request timeout))
                                                           '(:status 200 :body "secret")))
                                  :request-redactor-fn #'identity
                                  :response-redactor-fn #'identity)
    (network-boundary-request network '(:method :post :body "secret"))
    (with-network-calls (calls
                         (:request '(:method :post :body "secret")
                                   :timeout nil
                                   :result '(:status 200 :body "secret")))
      (expect (equal calls
                 (recording-network-calls network)) :to-be-truthy))))

(it "make-recording-network-boundary-rejects-non-function-redactors"
  (signals error
    (make-recording-network-boundary
     :delegate (make-network-boundary
                :request-fn (lambda (request &key timeout)
                              (declare (ignore request timeout))
                              '(:status 204)))
     :request-redactor-fn :bad))
  (signals error
    (make-recording-network-boundary
     :delegate (make-network-boundary
                :request-fn (lambda (request &key timeout)
                              (declare (ignore request timeout))
                              '(:status 204)))
     :response-redactor-fn :bad)))

(it "make-recording-network-boundary-requires-delegate"
  (signals error
    (make-recording-network-boundary)))

;; NETWORK-BOUNDARY-REQUEST only type-checks for the TEST/RECORDING kinds
;; before dispatching; anything else -- including a non-boundary argument --
;; falls straight through to %NETWORK-BOUNDARY-REQUEST's own (T) method.
(it "network-boundary-request-rejects-a-non-network-boundary"
  (signals-error-message-contains "Unsupported network boundary type"
    (network-boundary-request :bad '(:method :get))))

;;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
;;; double-record every call -- once on the wrapper, once on the delegate's
;;; own history -- because the recording dispatch recursed through the
;;; delegate's public NETWORK-BOUNDARY-REQUEST, re-entering the delegate's
;;; own recording path. Only the wrapper should record.
(it "recording-network-boundary-does-not-double-record-a-self-recording-delegate"
  (let* ((delegate (make-test-network-boundary :responses (list "ok")))
         (network (make-recording-network-boundary :delegate delegate)))
    (network-boundary-request network '(:method :get :url "https://example.test"))
    (expect (= (length (recording-network-calls network)) 1) :to-be-truthy)
    (expect (= (length (recording-network-calls delegate)) 0) :to-be-truthy)))

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

;; Both readers reject a plain (non-recording, non-test) network boundary the
;; same way, so one it-each table drives the pair through the domain matcher
;; instead of two near-identical it blocks.
(it-each ((recording-network-calls)
          (reset-recording-network-calls))
    "~A signals for unsupported network boundary types"
    (operation)
  (expect (lambda ()
            (funcall operation
                     (make-network-boundary
                      :request-fn (lambda (request &key timeout)
                                    (declare (ignore request timeout))
                                    '(:status 204)))))
          :to-signal-message-containing "Unsupported network boundary type"))

(it "reset-recording-network-calls-clears-history-and-returns-the-boundary"
  (let ((network (make-test-network-boundary :responses (list "ok" "ok2"))))
    (network-boundary-request network '(:method :get))
    (expect (= (length (recording-network-calls network)) 1) :to-be-truthy)
    (expect (eq (reset-recording-network-calls network) network) :to-be-truthy)
    (expect (null (recording-network-calls network)) :to-be-truthy)
    (network-boundary-request network '(:method :get))
    (expect (= (length (recording-network-calls network)) 1) :to-be-truthy)))

;; %NETWORK-CALLS is a type-dispatched generic with a separate SETF method per
;; boundary class; the test above only exercises TEST-NETWORK-BOUNDARY's, so
;; drive the same reset through an actual RECORDING-NETWORK-BOUNDARY too.
(it "reset-recording-network-calls-clears-history-on-a-recording-boundary"
  (with-network-boundary (network make-recording-network-boundary
                                  :delegate (make-test-network-boundary
                                             :responses (list "ok" "ok2")))
    (network-boundary-request network '(:method :get))
    (expect (= (length (recording-network-calls network)) 1) :to-be-truthy)
    (expect (eq (reset-recording-network-calls network) network) :to-be-truthy)
    (expect (null (recording-network-calls network)) :to-be-truthy)))

;;; Regression: %RECORD-NETWORK-CALL built its call record by hand instead of
;;; going through the shared %RECORD-CALL macro, so it never got the
;;; COPY-TREE write-time protection: mutating the request list the caller
;;; still holds a reference to corrupted the boundary's own history.
(it "test-network-boundary-history-is-independent-of-a-mutated-request"
  (let ((network (make-test-network-boundary :responses (list "ok")))
        (request (list :method :get :url "https://example.test")))
    (network-boundary-request network request)
    (setf request (nreverse request))
    (expect (equal (getf (first (recording-network-calls network)) :request)
               '(:method :get :url "https://example.test"))
            :to-be-truthy)))
