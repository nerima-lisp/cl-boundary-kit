;;;; t/console-test.lisp

(in-package #:cl-boundary-kit/test)

(defvar *console* nil)
(defvar *recording-console* nil)

(describe "console"
  (before-each
    (setf *console* (make-test-console)
          *recording-console* (make-recording-console)))

  (it "make-console-reads-and-writes-through-its-streams"
    (let* ((input (make-string-input-stream (format nil "first~%second~%")))
           (output (make-string-output-stream))
           (errors (make-string-output-stream))
           (console (make-console :input input :output output :error errors)))
      (expect (console-read-line console) :to-equal "first")
      (expect (console-write-line console "hello") :to-equal "hello")
      (expect (console-write-error console "oops") :to-equal "oops")
      (expect (get-output-stream-string output) :to-equal (format nil "hello~%"))
      (expect (get-output-stream-string errors) :to-equal (format nil "oops~%"))))

  (it "make-console-rejects-non-stream-collaborators"
    (signals error
      (make-console :input :not-a-stream)))

  (it "test-console-consumes-queued-input-and-signals-eof-with-nil"
    (let ((console (make-test-console :input-lines (list "a" "b"))))
      (expect (console-read-line console) :to-equal "a")
      (expect (console-read-line console) :to-equal "b")
      (expect (console-read-line console) :to-be-null)))

  (it "test-console-copies-seeded-input-lines"
    (let* ((input-lines (list "a" "b"))
           (console (make-test-console :input-lines input-lines)))
      (setf (first input-lines) "changed"
            (rest input-lines) nil)
      (expect (console-read-line console) :to-equal "a")
      (expect (console-read-line console) :to-equal "b")))

  (it "test-console-captures-output-and-error-lines-oldest-first"
    (console-write-line *console* "one")
    (console-write-line *console* "two")
    (console-write-error *console* "boom")
    (expect (test-console-output *console*) :to-equal (list "one" "two"))
    (expect (test-console-errors *console*) :to-equal (list "boom")))

  (it "console-write-captures-text-without-a-newline-in-the-output"
    (expect (console-write *console* "prompt> ") :to-equal "prompt> ")
    (console-write-line *console* "answer")
    (expect (test-console-output *console*) :to-equal (list "prompt> " "answer")))

  (it "make-console-console-write-omits-the-newline"
    (let* ((output (make-string-output-stream))
           (console (make-console :output output)))
      (console-write console "a")
      (console-write console "b")
      (expect (get-output-stream-string output) :to-equal "ab")))

  (it "recording-console-keeps-write-and-write-line-operations-distinct"
    (console-write *recording-console* "x")
    (console-write-line *recording-console* "y")
    (expect (recording-console-calls *recording-console*)
            :to-have-recorded-calls
            (list (boundary-call-plist :write (list "x") :result "x")
                  (boundary-call-plist :write-line (list "y") :result "y"))))

  (it "console-write-rejects-a-non-string-argument"
    (signals error
      (console-write (make-test-console) 42)))

  (it "console-format-writes-a-formatted-string"
    (expect (console-format *console* "~D items" 3) :to-equal "3 items")
    (expect (test-console-output *console*) :to-equal (list "3 items")))

  (it "console-format-line-writes-a-formatted-line-recorded-as-write-line"
    (expect (console-format-line *recording-console* "total ~D" 5) :to-equal "total 5")
    (expect (recorded-call-operations (recording-console-calls *recording-console*)) :to-equal (list :write-line)))

  (it "console-prompt-writes-a-prompt-then-reads-a-line"
    (let ((console (make-test-console :input-lines (list "alice"))))
      (expect (console-prompt console "Name: ") :to-equal "alice")
      (expect (test-console-output console) :to-equal (list "Name: "))))

  (it "console-prompt-on-a-recording-console-records-the-write-then-the-read"
    (let ((console (make-recording-console
                    :delegate (make-test-console :input-lines (list "yes")))))
      (expect (console-prompt console "Continue? ") :to-equal "yes")
      (expect (recorded-call-operations (recording-console-calls console)) :to-equal (list :write :read-line))))

  (it "test-console-rejects-non-string-input-and-written-lines"
    (signals error
      (make-test-console :input-lines (list 42)))
    (signals error
      (console-write-line (make-test-console) 42)))

  (it "test-console-accessors-signal-for-unsupported-console-types"
    (signals error
      (test-console-output (make-recording-console)))
    (signals error
      (test-console-errors (make-recording-console))))

  (it "recording-console-records-reads-and-writes"
    (let* ((delegate (make-test-console :input-lines (list "line")))
           (console (make-recording-console :delegate delegate)))
      (expect (console-read-line console) :to-equal "line")
      (expect (console-write-line console "out") :to-equal "out")
      (expect (console-write-error console "err") :to-equal "err")
      (expect (recording-console-calls console)
              :to-have-recorded-calls
              (list (boundary-call-plist :read-line '() :result "line")
                    (boundary-call-plist :write-line (list "out") :result "out")
                    (boundary-call-plist :write-error (list "err") :result "err")))))

  (it "make-recording-console-defaults-to-a-non-blocking-delegate"
    (expect (console-read-line *recording-console*) :to-be-null))

  (it "make-recording-console-rejects-a-non-console-delegate"
    (signals error
      (make-recording-console :delegate :bad)))

  (it-each ((recording-console-calls)
            (reset-recording-console-calls))
      "~A signals for unsupported console types"
      (operation)
    (expect (lambda () (funcall operation (make-test-console))) :to-throw "Unsupported console type"))

  (deftest-reset-recording-clears-history
      "reset-recording-console-calls-clears-history-and-returns-the-console"
      (console (make-recording-console))
      (recording-console-calls reset-recording-console-calls)
    (console-write-line console "x"))

  (it "make-test-console-rejects-non-list-input-lines"
    (expect (lambda () (make-test-console :input-lines 42)) :to-throw "Test console input lines must be a list")))
