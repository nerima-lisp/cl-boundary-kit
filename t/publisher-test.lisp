;;;; t/publisher-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-publisher-forwards-events-to-its-emit-fn-and-returns-them"
  (let* ((emitted '())
         (publisher (make-publisher :emit-fn (lambda (event) (push event emitted)))))
    (let ((event (publisher-publish publisher "orders" "created")))
      (expect (equal (list :topic "orders" :message "created") event) :to-be-truthy)
      (expect (equal event (first emitted)) :to-be-truthy)
      (expect (not (eq event (first emitted))) :to-be-truthy))))

(it "make-publisher-rejects-a-non-function-emit-fn"
  (signals error
    (make-publisher :emit-fn :bad)))

(it "test-publisher-records-published-messages-in-order"
  (let ((publisher (make-test-publisher)))
    (publisher-publish publisher "orders" "created")
    (publisher-publish publisher :alerts 500)
    (expect (equal (recording-published-messages publisher)
                   (list (list :topic "orders" :message "created")
                         (list :topic :alerts :message 500))) :to-be-truthy)))

(it "publisher-publish-returns-an-independent-recorded-event"
  (let* ((publisher (make-test-publisher))
         (event (publisher-publish publisher "t" "m")))
    (expect (equal event (first (recording-published-messages publisher))) :to-be-truthy)
    (expect (not (eq event (first (recording-published-messages publisher)))) :to-be-truthy)))

(it "recording-published-messages-returns-independent-snapshots"
  (let* ((publisher (make-test-publisher))
         (payload (list :id (copy-seq "one")))
         (event (publisher-publish publisher "orders" payload)))
    (setf (getf event :topic) "mutated"
          (getf (getf event :message) :id) "changed"
          (getf payload :id) "caller-changed")
    (expect (equal (list (list :topic "orders" :message (list :id "one")))
                   (recording-published-messages publisher)) :to-be-truthy)))

(it "publisher-publish-rejects-an-invalid-topic"
  (signals error
    (publisher-publish (make-test-publisher) nil "m")))

(it "recording-publisher-records-messages-and-forwards-them-to-a-delegate"
  (let* ((forwarded '())
         (delegate (make-publisher :emit-fn (lambda (event) (push event forwarded))))
         (publisher (make-recording-publisher :delegate delegate))
         (event (publisher-publish publisher "orders" "created")))
    (expect (equal event (first (recording-published-messages publisher))) :to-be-truthy)
    (expect (not (eq event (first (recording-published-messages publisher)))) :to-be-truthy)
    (expect (equal event (first forwarded)) :to-be-truthy)
    (expect (not (eq event (first forwarded))) :to-be-truthy)))

(it "make-recording-publisher-defaults-to-a-no-op-sink"
  (let ((publisher (make-recording-publisher)))
    (publisher-publish publisher "orders" "created")
    (expect (= 1 (length (recording-published-messages publisher))) :to-be-truthy)))

(it "make-recording-publisher-rejects-a-non-publisher-delegate"
  (signals error
    (make-recording-publisher :delegate :bad)))

(it "recording-published-messages-signals-for-unsupported-publisher-types"
  (signals error
    (recording-published-messages (make-publisher))))

(it "reset-recording-published-messages-clears-history-and-returns-the-publisher"
  (let ((publisher (make-test-publisher)))
    (publisher-publish publisher "orders" "created")
    (expect (= 1 (length (recording-published-messages publisher))) :to-be-truthy)
    (expect (eq publisher (reset-recording-published-messages publisher)) :to-be-truthy)
    (expect (null (recording-published-messages publisher)) :to-be-truthy)))

(it "reset-recording-published-messages-signals-for-unsupported-publisher-types"
  (signals error
    (reset-recording-published-messages (make-publisher))))
