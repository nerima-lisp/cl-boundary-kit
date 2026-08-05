;;;; t/publisher-test.lisp

(in-package #:cl-boundary-kit/test)

(defvar *test-publisher* nil)

(describe "publisher"
  (it "make-publisher-forwards-events-to-its-emit-fn-and-returns-them"
    (let* ((emitted '())
           (publisher (make-publisher :emit-fn (lambda (event) (push event emitted)))))
      (let ((event (publisher-publish publisher "orders" "created")))
        (expect event :to-equal (list :topic "orders" :message "created"))
        (expect event :to-equal (first emitted))
        (expect event :not :to-be (first emitted)))))

  (it "make-publisher-rejects-a-non-function-emit-fn"
    (signals error
      (make-publisher :emit-fn :bad))))

(describe "test publisher"
  (before-each
    (setf *test-publisher* (make-test-publisher)))

  (it "test-publisher-records-published-messages-in-order"
    (publisher-publish *test-publisher* "orders" "created")
    (publisher-publish *test-publisher* :alerts 500)
    (expect (recording-published-messages *test-publisher*)
            :to-equal (list (list :topic "orders" :message "created")
                            (list :topic :alerts :message 500))))

  (it "publisher-publish-returns-an-independent-recorded-event"
    (let ((event (publisher-publish *test-publisher* "t" "m")))
      (expect event :to-equal (first (recording-published-messages *test-publisher*)))
      (expect event :not :to-be (first (recording-published-messages *test-publisher*)))))

  (it "recording-published-messages-returns-independent-snapshots"
    (let* ((payload (list :id (copy-seq "one")))
           (event (publisher-publish *test-publisher* "orders" payload)))
      (setf (getf event :topic) "mutated"
            (getf (getf event :message) :id) "changed"
            (getf payload :id) "caller-changed")
      (expect (recording-published-messages *test-publisher*)
              :to-equal (list (list :topic "orders" :message (list :id "one"))))))

  (it "publisher-publish-rejects-an-invalid-topic"
    (with-soft-assertions
      ;; NIL is itself a symbol, so this exercises the "symbol but falsy" arm.
      (signals error
        (publisher-publish (make-test-publisher) nil "m"))
      ;; A number is neither a string nor a symbol, exercising the
      ;; not-a-symbol-at-all arm the NIL case above cannot reach.
      (signals error
        (publisher-publish (make-test-publisher) 42 "m")))))

(describe "recording publisher"
  (it "recording-publisher-records-messages-and-forwards-them-to-a-delegate"
    (let* ((forwarded '())
           (delegate (make-publisher :emit-fn (lambda (event) (push event forwarded))))
           (publisher (make-recording-publisher :delegate delegate))
           (event (publisher-publish publisher "orders" "created")))
      (expect event :to-equal (first (recording-published-messages publisher)))
      (expect event :not :to-be (first (recording-published-messages publisher)))
      (expect event :to-equal (first forwarded))
      (expect event :not :to-be (first forwarded))))

  (it "make-recording-publisher-defaults-to-a-no-op-sink"
    (let ((publisher (make-recording-publisher)))
      (publisher-publish publisher "orders" "created")
      (expect (recording-published-messages publisher) :to-have-length 1)))

  (it "make-recording-publisher-rejects-a-non-publisher-delegate"
    (signals error
      (make-recording-publisher :delegate :bad)))

  (it-each ((recording-published-messages)
            (reset-recording-published-messages))
      "~A signals for unsupported publisher types"
      (operation)
    (expect (lambda () (funcall operation (make-publisher))) :to-throw "Unsupported publisher type"))

  (it "reset-recording-published-messages-clears-history-and-returns-the-publisher"
    (let ((publisher (make-test-publisher)))
      (publisher-publish publisher "orders" "created")
      (expect (recording-published-messages publisher) :to-have-length 1)
      (expect (reset-recording-published-messages publisher) :to-be publisher)
      (expect (recording-published-messages publisher) :to-be-null))))

