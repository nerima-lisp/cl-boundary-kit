;;;; t/notifier-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-notifier-forwards-events-to-its-emit-fn-and-returns-them"
  (let* ((emitted '())
         (notifier (make-notifier :emit-fn (lambda (event) (push event emitted)))))
    (let ((event (notifier-notify notifier "a@test" "Hi" "Body")))
      (expect (equal (list :recipient "a@test" :subject "Hi" :body "Body") event) :to-be-truthy)
      (expect (equal event (first emitted)) :to-be-truthy)
      (expect (not (eq event (first emitted))) :to-be-truthy))))

(it "make-notifier-rejects-a-non-function-emit-fn"
  (signals error
    (make-notifier :emit-fn :bad)))

(it "test-notifier-records-sent-notifications-in-order"
  (let ((notifier (make-test-notifier)))
    (notifier-notify notifier "a@test" "First" "1")
    (notifier-notify notifier "b@test" "Second" "2")
    (expect (equal (recording-sent-notifications notifier)
                   (list (list :recipient "a@test" :subject "First" :body "1")
                         (list :recipient "b@test" :subject "Second" :body "2"))) :to-be-truthy)))

(it "notifier-notify-returns-an-independent-recorded-event"
  (let* ((notifier (make-test-notifier))
         (event (notifier-notify notifier "a@test" "S" "B")))
    (expect (equal event (first (recording-sent-notifications notifier))) :to-be-truthy)
    (expect (not (eq event (first (recording-sent-notifications notifier)))) :to-be-truthy)))

(it "recording-sent-notifications-returns-independent-snapshots"
  (let* ((notifier (make-test-notifier))
         (recipient (copy-seq "a@test"))
         (subject (copy-seq "S"))
         (body (copy-seq "B"))
         (event (notifier-notify notifier recipient subject body)))
    (setf (char recipient 0) #\x
          (char subject 0) #\T
          (char body 0) #\C
          (getf event :subject) "mutated")
    (expect (equal (list (list :recipient "a@test" :subject "S" :body "B"))
                   (recording-sent-notifications notifier)) :to-be-truthy)))

(it "notifier-notify-rejects-non-string-fields"
  (let ((notifier (make-test-notifier)))
    (signals error
      (notifier-notify notifier 42 "S" "B"))
    (signals error
      (notifier-notify notifier "a@test" 42 "B"))
    (signals error
      (notifier-notify notifier "a@test" "S" 42))))

(it "recording-notifier-records-and-forwards-to-a-delegate"
  (let* ((forwarded '())
         (delegate (make-notifier :emit-fn (lambda (event) (push event forwarded))))
         (notifier (make-recording-notifier :delegate delegate))
         (event (notifier-notify notifier "a@test" "S" "B")))
    (expect (equal event (first (recording-sent-notifications notifier))) :to-be-truthy)
    (expect (not (eq event (first (recording-sent-notifications notifier)))) :to-be-truthy)
    (expect (equal event (first forwarded)) :to-be-truthy)
    (expect (not (eq event (first forwarded))) :to-be-truthy)))

(it "make-recording-notifier-defaults-to-a-no-op-sink"
  (let ((notifier (make-recording-notifier)))
    (notifier-notify notifier "a@test" "S" "B")
    (expect (= 1 (length (recording-sent-notifications notifier))) :to-be-truthy)))

(it "make-recording-notifier-rejects-a-non-notifier-delegate"
  (signals error
    (make-recording-notifier :delegate :bad)))

(it-each ((recording-sent-notifications)
          (reset-recording-sent-notifications))
    "~A signals for unsupported notifier types"
    (operation)
  (expect (lambda () (funcall operation (make-notifier)))
          :to-signal-message-containing "Unsupported notifier type"))

(it "reset-recording-sent-notifications-clears-history-and-returns-the-notifier"
  (let ((notifier (make-test-notifier)))
    (notifier-notify notifier "a@test" "S" "B")
    (expect (= 1 (length (recording-sent-notifications notifier))) :to-be-truthy)
    (expect (eq notifier (reset-recording-sent-notifications notifier)) :to-be-truthy)
    (expect (null (recording-sent-notifications notifier)) :to-be-truthy)))

