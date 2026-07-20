;;;; t/args-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-args-reads-an-explicit-argument-list"
  (let ((args (make-test-args :arguments (list "app" "--flag" "value"))))
    (expect (equal (list "app" "--flag" "value") (args-list args)) :to-be-truthy)
    (expect (= 3 (args-count args)) :to-be-truthy)
    (expect (string= "app" (args-nth args 0)) :to-be-truthy)
    (expect (string= "value" (args-nth args 2)) :to-be-truthy)))

(it "args-nth-returns-nil-when-out-of-range"
  (let ((args (make-test-args :arguments (list "only"))))
    (expect (null (args-nth args 5)) :to-be-truthy)))

(it "args-rest-returns-arguments-from-an-index-onward"
  (let ((args (make-test-args :arguments (list "app" "--flag" "value"))))
    (expect (equal (list "--flag" "value") (args-rest args 1)) :to-be-truthy)
    (expect (null (args-rest args 5)) :to-be-truthy)
    (signals error (args-rest args -1))))

(it "args-nth-rejects-a-negative-index"
  (signals error
    (args-nth (make-test-args :arguments (list "a")) -1)))

(it "args-list-returns-a-fresh-list-that-callers-cannot-mutate-into-the-boundary"
  (let* ((args (make-test-args :arguments (list "a" "b")))
         (copy (args-list args)))
    (setf (first copy) "mutated")
    (expect (string= "a" (args-nth args 0)) :to-be-truthy)))

(it "make-test-args-copies-the-seeded-argument-list"
  (let* ((arguments (list "app" "--flag" "value"))
         (args (make-test-args :arguments arguments)))
    (setf (first arguments) "changed"
          (rest arguments) nil)
    (expect (equal (list "app" "--flag" "value") (args-list args)) :to-be-truthy)))

(it "make-args-defaults-to-the-host-argument-vector"
  (let ((args (make-args)))
    (expect (listp (args-list args)) :to-be-truthy)
    (expect (integerp (args-count args)) :to-be-truthy)))

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
    (expect (equal (recording-args-calls args)
                   (list (boundary-call-plist :list '() :result (list "app" "--flag"))
                         (boundary-call-plist :count '() :result 2)
                         (boundary-call-plist :nth (list 1) :result "--flag"))) :to-be-truthy)))

(it "make-recording-args-rejects-a-non-args-delegate"
  (signals error
    (make-recording-args :delegate :bad)))

(it "recording-args-calls-signals-for-unsupported-args-types"
  (signals error
    (recording-args-calls (make-test-args))))

(it "reset-recording-args-calls-clears-history-and-returns-the-args"
  (let ((args (make-recording-args :delegate (make-test-args :arguments (list "a")))))
    (args-list args)
    (expect (= 1 (length (recording-args-calls args))) :to-be-truthy)
    (expect (eq args (reset-recording-args-calls args)) :to-be-truthy)
    (expect (null (recording-args-calls args)) :to-be-truthy)))

(it "reset-recording-args-calls-signals-for-unsupported-args-types"
  (signals error
    (reset-recording-args-calls (make-test-args))))
