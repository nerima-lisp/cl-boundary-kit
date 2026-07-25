;;;; t/console-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-console-reads-and-writes-through-its-streams"
  (let* ((input (make-string-input-stream (format nil "first~%second~%")))
         (output (make-string-output-stream))
         (errors (make-string-output-stream))
         (console (make-console :input input :output output :error errors)))
    (expect (string= "first" (console-read-line console)) :to-be-truthy)
    (expect (string= "hello" (console-write-line console "hello")) :to-be-truthy)
    (expect (string= "oops" (console-write-error console "oops")) :to-be-truthy)
    (expect (string= (format nil "hello~%") (get-output-stream-string output)) :to-be-truthy)
    (expect (string= (format nil "oops~%") (get-output-stream-string errors)) :to-be-truthy)))

(it "make-console-rejects-non-stream-collaborators"
  (signals error
    (make-console :input :not-a-stream)))

(it "test-console-consumes-queued-input-and-signals-eof-with-nil"
  (let ((console (make-test-console :input-lines (list "a" "b"))))
    (expect (string= "a" (console-read-line console)) :to-be-truthy)
    (expect (string= "b" (console-read-line console)) :to-be-truthy)
    (expect (null (console-read-line console)) :to-be-truthy)))

(it "test-console-copies-seeded-input-lines"
  (let* ((input-lines (list "a" "b"))
         (console (make-test-console :input-lines input-lines)))
    (setf (first input-lines) "changed"
          (rest input-lines) nil)
    (expect (string= "a" (console-read-line console)) :to-be-truthy)
    (expect (string= "b" (console-read-line console)) :to-be-truthy)))

(it "test-console-captures-output-and-error-lines-oldest-first"
  (let ((console (make-test-console)))
    (console-write-line console "one")
    (console-write-line console "two")
    (console-write-error console "boom")
    (expect (equal (list "one" "two") (test-console-output console)) :to-be-truthy)
    (expect (equal (list "boom") (test-console-errors console)) :to-be-truthy)))

(it "console-write-captures-text-without-a-newline-in-the-output"
  (let ((console (make-test-console)))
    (expect (string= "prompt> " (console-write console "prompt> ")) :to-be-truthy)
    (console-write-line console "answer")
    (expect (equal (list "prompt> " "answer") (test-console-output console)) :to-be-truthy)))

(it "make-console-console-write-omits-the-newline"
  (let* ((output (make-string-output-stream))
         (console (make-console :output output)))
    (console-write console "a")
    (console-write console "b")
    (expect (string= "ab" (get-output-stream-string output)) :to-be-truthy)))

(it "recording-console-keeps-write-and-write-line-operations-distinct"
  (let ((console (make-recording-console)))
    (console-write console "x")
    (console-write-line console "y")
    (expect (equal (recording-console-calls console)
                   (list (boundary-call-plist :write (list "x") :result "x")
                         (boundary-call-plist :write-line (list "y") :result "y"))) :to-be-truthy)))

(it "console-write-rejects-a-non-string-argument"
  (signals error
    (console-write (make-test-console) 42)))

(it "console-format-writes-a-formatted-string"
  (let ((console (make-test-console)))
    (expect (string= "3 items" (console-format console "~D items" 3)) :to-be-truthy)
    (expect (equal (list "3 items") (test-console-output console)) :to-be-truthy)))

(it "console-format-line-writes-a-formatted-line-recorded-as-write-line"
  (let ((console (make-recording-console)))
    (expect (string= "total 5" (console-format-line console "total ~D" 5)) :to-be-truthy)
    (expect (equal (list :write-line)
                   (recorded-call-operations (recording-console-calls console))) :to-be-truthy)))

(it "console-prompt-writes-a-prompt-then-reads-a-line"
  (let ((console (make-test-console :input-lines (list "alice"))))
    (expect (string= "alice" (console-prompt console "Name: ")) :to-be-truthy)
    (expect (equal (list "Name: ") (test-console-output console)) :to-be-truthy)))

(it "console-prompt-on-a-recording-console-records-the-write-then-the-read"
  (let ((console (make-recording-console
                  :delegate (make-test-console :input-lines (list "yes")))))
    (expect (string= "yes" (console-prompt console "Continue? ")) :to-be-truthy)
    (expect (equal (list :write :read-line)
                   (recorded-call-operations (recording-console-calls console))) :to-be-truthy)))

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
    (expect (string= "line" (console-read-line console)) :to-be-truthy)
    (expect (string= "out" (console-write-line console "out")) :to-be-truthy)
    (expect (string= "err" (console-write-error console "err")) :to-be-truthy)
    (expect (equal (recording-console-calls console)
                   (list (boundary-call-plist :read-line '() :result "line")
                         (boundary-call-plist :write-line (list "out") :result "out")
                         (boundary-call-plist :write-error (list "err") :result "err"))) :to-be-truthy)))

(it "make-recording-console-defaults-to-a-non-blocking-delegate"
  (let ((console (make-recording-console)))
    (expect (null (console-read-line console)) :to-be-truthy)))

(it "make-recording-console-rejects-a-non-console-delegate"
  (signals error
    (make-recording-console :delegate :bad)))

(it-each ((recording-console-calls)
          (reset-recording-console-calls))
    "~A signals for unsupported console types"
    (operation)
  (expect (lambda () (funcall operation (make-test-console)))
          :to-signal-message-containing "Unsupported console type"))

(it "reset-recording-console-calls-clears-history-and-returns-the-console"
  (let ((console (make-recording-console)))
    (console-write-line console "x")
    (expect (= 1 (length (recording-console-calls console))) :to-be-truthy)
    (expect (eq console (reset-recording-console-calls console)) :to-be-truthy)
    (expect (null (recording-console-calls console)) :to-be-truthy)))

(it "make-test-console-rejects-non-list-input-lines"
  (signals-error-message-contains "Test console input lines must be a list"
    (make-test-console :input-lines 42)))
