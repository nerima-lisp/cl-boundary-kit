;;;; t/args-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "args"
  (it "test-args-reads-an-explicit-argument-list"
    (let ((args (make-test-args :arguments (list "app" "--flag" "value"))))
      (expect (args-list args) :to-equal (list "app" "--flag" "value"))
      (expect (args-count args) :to-be 3)
      (expect (args-nth args 0) :to-equal "app")
      (expect (args-nth args 2) :to-equal "value")))

  (it "args-nth-returns-nil-when-out-of-range"
    (let ((args (make-test-args :arguments (list "only"))))
      (expect (args-nth args 5) :to-be-null)))

  (it "args-rest-returns-arguments-from-an-index-onward"
    (let ((args (make-test-args :arguments (list "app" "--flag" "value"))))
      (expect (args-rest args 1) :to-equal (list "--flag" "value"))
      (expect (args-rest args 5) :to-be-null)
      (signals error (args-rest args -1))))

  (it "args-nth-rejects-a-negative-index"
    (signals error
      (args-nth (make-test-args :arguments (list "a")) -1)))

  (it "args-list-returns-a-fresh-list-that-callers-cannot-mutate-into-the-boundary"
    (let* ((args (make-test-args :arguments (list "a" "b")))
           (copy (args-list args)))
      (setf (first copy) "mutated")
      (expect (args-nth args 0) :to-equal "a")))

  (it "make-test-args-copies-the-seeded-argument-list"
    (let* ((arguments (list "app" "--flag" "value"))
           (args (make-test-args :arguments arguments)))
      (setf (first arguments) "changed"
            (rest arguments) nil)
      (expect (args-list args) :to-equal (list "app" "--flag" "value"))))

  (it "make-args-defaults-to-the-host-argument-vector"
    (let ((args (make-args)))
      (expect (args-list args) :to-be-type-of 'list)
      (expect (args-count args) :to-be-type-of 'integer)))

  (it "make-test-args-rejects-non-string-arguments"
    (signals error
      (make-test-args :arguments (list 42)))
    (signals error
      (make-test-args :arguments "not-a-list")))

  (it "recording-args-records-reads"
    (let* ((delegate (make-test-args :arguments (list "app" "--flag")))
           (args (make-recording-args :delegate delegate)))
      (args-list args)
      (args-count args)
      (args-nth args 1)
      (expect (recording-args-calls args)
              :to-have-recorded-calls
              (list (boundary-call-plist :list '() :result (list "app" "--flag"))
                    (boundary-call-plist :count '() :result 2)
                    (boundary-call-plist :nth (list 1) :result "--flag")))))

  (it "make-recording-args-uses-an-empty-test-boundary-by-default"
    (let ((args (make-recording-args)))
      (expect (args-list args) :to-be-null)))

  (it "make-recording-args-rejects-a-non-args-delegate"
    (signals error
      (make-recording-args :delegate :bad)))

  (it-each ((recording-args-calls)
            (reset-recording-args-calls))
      "~A signals for unsupported args types"
      (operation)
    (expect (lambda () (funcall operation (make-test-args))) :to-throw "Unsupported command-line arguments type"))

  (deftest-reset-recording-clears-history
      "reset-recording-args-calls-clears-history-and-returns-the-args"
      (args (make-recording-args :delegate (make-test-args :arguments (list "a"))))
      (recording-args-calls reset-recording-args-calls)
    (args-list args)))
