;;;; t/subscriber-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "subscriber polling and poll batch"
  (it "test-subscriber-yields-queued-messages-then-nil"
    (let ((subscriber (make-test-subscriber :messages (list "a" "b"))))
      (expect (subscriber-poll subscriber) :to-equal "a")
      (expect (subscriber-poll subscriber) :to-equal "b")
      (expect (subscriber-poll subscriber) :to-be-null)))

  (it "test-subscriber-copies-seeded-messages"
    (let* ((messages (list "a" "b"))
           (subscriber (make-test-subscriber :messages messages)))
      (setf (first messages) "changed"
            (rest messages) nil)
      (expect (subscriber-poll subscriber) :to-equal "a")
      (expect (subscriber-poll subscriber) :to-equal "b")))

  (it "test-subscriber-with-no-messages-polls-nil"
    (expect (subscriber-poll (make-test-subscriber)) :to-be-null))

  (it "make-test-subscriber-rejects-a-non-list-messages-value"
    (signals error
      (make-test-subscriber :messages :not-a-list)))

  (it "subscriber-poll-batch-collects-up-to-max-stopping-at-nil"
    (let ((subscriber (make-test-subscriber :messages (list "a" "b" "c"))))
      ;; Stops early when the queue drains before MAX.
      (expect (subscriber-poll-batch subscriber 10) :to-equal (list "a" "b" "c")))
    (let ((subscriber (make-test-subscriber :messages (list "a" "b" "c"))))
      ;; Stops at MAX before the queue drains.
      (expect (subscriber-poll-batch subscriber 2) :to-equal (list "a" "b"))))

  ;; Every other MAKE-RECORDING-SUBSCRIBER test above supplies an explicit
  ;; :DELEGATE; exercise the &KEY default (an empty MAKE-TEST-SUBSCRIBER) too.
  (it "recording-subscriber-defaults-to-an-empty-test-subscriber"
    (let ((subscriber (make-recording-subscriber)))
      (expect (subscriber-poll subscriber) :to-be-null)
      (expect (recording-subscriber-calls subscriber) :to-have-length 1)))

  (it "subscriber-poll-batch-with-max-zero-polls-nothing"
    (let ((subscriber (make-recording-subscriber
                       :delegate (make-test-subscriber :messages (list "a")))))
      (expect (subscriber-poll-batch subscriber 0) :to-be-null)
      (expect (recording-subscriber-calls subscriber) :to-be-null)))

  (it "subscriber-poll-batch-rejects-a-negative-max"
    (signals error
      (subscriber-poll-batch (make-test-subscriber) -1))))

(describe "native subscriber"
  (it "make-subscriber-wires-an-injected-poll-fn"
    (let* ((queue (list 1 2))
           (subscriber (make-subscriber :poll-fn (lambda () (pop queue)))))
      (expect (subscriber-poll subscriber) :to-be 1)
      (expect (subscriber-poll subscriber) :to-be 2)
      (expect (subscriber-poll subscriber) :to-be-null)))

  (it "make-subscriber-rejects-a-non-function-poll-fn"
    (signals error
      (make-subscriber :poll-fn :bad))))

(describe "recording subscriber"
  (it "recording-subscriber-records-polls"
    (let* ((delegate (make-test-subscriber :messages (list "a")))
           (subscriber (make-recording-subscriber :delegate delegate)))
      (subscriber-poll subscriber)
      (subscriber-poll subscriber)
      (expect (recording-subscriber-calls subscriber)
              :to-have-recorded-calls (list (boundary-call-plist :poll '() :result "a")
                                            (boundary-call-plist :poll '() :result nil)))))

  (it "make-recording-subscriber-rejects-a-non-subscriber-delegate"
    (signals error
      (make-recording-subscriber :delegate :bad)))

  (it-each ((recording-subscriber-calls)
            (reset-recording-subscriber-calls))
      "~A signals for unsupported subscriber types"
      (operation)
    (expect (lambda () (funcall operation (make-test-subscriber))) :to-throw "Unsupported subscriber type"))

  (deftest-reset-recording-clears-history
      "reset-recording-subscriber-calls-clears-history-and-returns-the-subscriber"
      (subscriber (make-recording-subscriber
                   :delegate (make-test-subscriber :messages (list "a"))))
      (recording-subscriber-calls reset-recording-subscriber-calls)
    (subscriber-poll subscriber)))

