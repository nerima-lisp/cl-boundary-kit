;;;; t/notifier-test.lisp

(in-package #:cl-boundary-kit/test)

(defvar *test-notifier* nil)

(describe "notifier"
  (it "make-notifier-forwards-events-to-its-emit-fn-and-returns-them"
    (let* ((emitted '())
           (notifier (make-notifier :emit-fn (lambda (event) (push event emitted)))))
      (let ((event (notifier-notify notifier "a@test" "Hi" "Body")))
        (expect event :to-equal (list :recipient "a@test" :subject "Hi" :body "Body"))
        (expect event :to-equal (first emitted))
        (expect event :not :to-be (first emitted)))))

  (it "make-notifier-rejects-a-non-function-emit-fn"
    (signals error
      (make-notifier :emit-fn :bad))))

(describe "test notifier"
  (before-each
    (setf *test-notifier* (make-test-notifier)))

  (it "test-notifier-records-sent-notifications-in-order"
    (notifier-notify *test-notifier* "a@test" "First" "1")
    (notifier-notify *test-notifier* "b@test" "Second" "2")
    (expect (recording-sent-notifications *test-notifier*)
            :to-equal (list (list :recipient "a@test" :subject "First" :body "1")
                            (list :recipient "b@test" :subject "Second" :body "2"))))

  (it "notifier-notify-returns-an-independent-recorded-event"
    (let ((event (notifier-notify *test-notifier* "a@test" "S" "B")))
      (expect event :to-equal (first (recording-sent-notifications *test-notifier*)))
      (expect event :not :to-be (first (recording-sent-notifications *test-notifier*)))))

  (it "recording-sent-notifications-returns-independent-snapshots"
    (let* ((recipient (copy-seq "a@test"))
           (subject (copy-seq "S"))
           (body (copy-seq "B"))
           (event (notifier-notify *test-notifier* recipient subject body)))
      (setf (char recipient 0) #\x
            (char subject 0) #\T
            (char body 0) #\C
            (getf event :subject) "mutated")
      (expect (recording-sent-notifications *test-notifier*) :to-equal (list (list :recipient "a@test" :subject "S" :body "B")))))

  (it "notifier-notify-rejects-non-string-fields"
    (signals error
      (notifier-notify *test-notifier* 42 "S" "B"))
    (signals error
      (notifier-notify *test-notifier* "a@test" 42 "B"))
    (signals error
      (notifier-notify *test-notifier* "a@test" "S" 42))))

(describe "recording notifier"
  (it "recording-notifier-records-and-forwards-to-a-delegate"
    (let* ((forwarded '())
           (delegate (make-notifier :emit-fn (lambda (event) (push event forwarded))))
           (notifier (make-recording-notifier :delegate delegate))
           (event (notifier-notify notifier "a@test" "S" "B")))
      (expect event :to-equal (first (recording-sent-notifications notifier)))
      (expect event :not :to-be (first (recording-sent-notifications notifier)))
      (expect event :to-equal (first forwarded))
      (expect event :not :to-be (first forwarded))))

  (it "make-recording-notifier-defaults-to-a-no-op-sink"
    (let ((notifier (make-recording-notifier)))
      (notifier-notify notifier "a@test" "S" "B")
      (expect (recording-sent-notifications notifier) :to-have-length 1)))

  (it "make-recording-notifier-rejects-a-non-notifier-delegate"
    (signals error
      (make-recording-notifier :delegate :bad))))

(describe "recording-sent-notifications"
  (it-each ((recording-sent-notifications)
            (reset-recording-sent-notifications))
      "~A signals for unsupported notifier types"
      (operation)
    (expect (lambda () (funcall operation (make-notifier))) :to-throw "Unsupported notifier type"))

  (it "reset-recording-sent-notifications-clears-history-and-returns-the-notifier"
    (let ((notifier (make-test-notifier)))
      (notifier-notify notifier "a@test" "S" "B")
      (expect (recording-sent-notifications notifier) :to-have-length 1)
      (expect (reset-recording-sent-notifications notifier) :to-be notifier)
      (expect (recording-sent-notifications notifier) :to-be-null))))

