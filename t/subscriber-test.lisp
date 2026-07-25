;;;; t/subscriber-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-subscriber-yields-queued-messages-then-nil"
  (let ((subscriber (make-test-subscriber :messages (list "a" "b"))))
    (expect (string= "a" (subscriber-poll subscriber)) :to-be-truthy)
    (expect (string= "b" (subscriber-poll subscriber)) :to-be-truthy)
    (expect (null (subscriber-poll subscriber)) :to-be-truthy)))

(it "test-subscriber-copies-seeded-messages"
  (let* ((messages (list "a" "b"))
         (subscriber (make-test-subscriber :messages messages)))
    (setf (first messages) "changed"
          (rest messages) nil)
    (expect (string= "a" (subscriber-poll subscriber)) :to-be-truthy)
    (expect (string= "b" (subscriber-poll subscriber)) :to-be-truthy)))

(it "test-subscriber-with-no-messages-polls-nil"
  (expect (null (subscriber-poll (make-test-subscriber))) :to-be-truthy))

(it "make-test-subscriber-rejects-a-non-list-messages-value"
  (signals error
    (make-test-subscriber :messages :not-a-list)))

(it "subscriber-poll-batch-collects-up-to-max-stopping-at-nil"
  (let ((subscriber (make-test-subscriber :messages (list "a" "b" "c"))))
    ;; Stops early when the queue drains before MAX.
    (expect (equal (list "a" "b" "c") (subscriber-poll-batch subscriber 10)) :to-be-truthy))
  (let ((subscriber (make-test-subscriber :messages (list "a" "b" "c"))))
    ;; Stops at MAX before the queue drains.
    (expect (equal (list "a" "b") (subscriber-poll-batch subscriber 2)) :to-be-truthy)))

(it "subscriber-poll-batch-with-max-zero-polls-nothing"
  (let ((subscriber (make-recording-subscriber
                     :delegate (make-test-subscriber :messages (list "a")))))
    (expect (null (subscriber-poll-batch subscriber 0)) :to-be-truthy)
    (expect (null (recording-subscriber-calls subscriber)) :to-be-truthy)))

(it "subscriber-poll-batch-rejects-a-negative-max"
  (signals error
    (subscriber-poll-batch (make-test-subscriber) -1)))

(it "make-subscriber-wires-an-injected-poll-fn"
  (let* ((queue (list 1 2))
         (subscriber (make-subscriber :poll-fn (lambda () (pop queue)))))
    (expect (= 1 (subscriber-poll subscriber)) :to-be-truthy)
    (expect (= 2 (subscriber-poll subscriber)) :to-be-truthy)
    (expect (null (subscriber-poll subscriber)) :to-be-truthy)))

(it "make-subscriber-rejects-a-non-function-poll-fn"
  (signals error
    (make-subscriber :poll-fn :bad)))

(it "recording-subscriber-records-polls"
  (let* ((delegate (make-test-subscriber :messages (list "a")))
         (subscriber (make-recording-subscriber :delegate delegate)))
    (subscriber-poll subscriber)
    (subscriber-poll subscriber)
    (expect (equal (recording-subscriber-calls subscriber)
                   (list (boundary-call-plist :poll '() :result "a")
                         (boundary-call-plist :poll '() :result nil))) :to-be-truthy)))

(it "make-recording-subscriber-rejects-a-non-subscriber-delegate"
  (signals error
    (make-recording-subscriber :delegate :bad)))

(it-each ((recording-subscriber-calls)
          (reset-recording-subscriber-calls))
    "~A signals for unsupported subscriber types"
    (operation)
  (expect (lambda () (funcall operation (make-test-subscriber)))
          :to-signal-message-containing "Unsupported subscriber type"))

(it "reset-recording-subscriber-calls-clears-history-and-returns-the-subscriber"
  (let ((subscriber (make-recording-subscriber
                     :delegate (make-test-subscriber :messages (list "a")))))
    (subscriber-poll subscriber)
    (expect (= 1 (length (recording-subscriber-calls subscriber))) :to-be-truthy)
    (expect (eq subscriber (reset-recording-subscriber-calls subscriber)) :to-be-truthy)
    (expect (null (recording-subscriber-calls subscriber)) :to-be-truthy)))

