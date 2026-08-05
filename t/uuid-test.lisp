;;;; t/uuid-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "sequential uuid source"
  (it "sequential-uuid-source-is-deterministic-and-repeatable"
    (let ((source-a (make-sequential-uuid-source :prefix "req" :start 0))
          (source-b (make-sequential-uuid-source :prefix "req" :start 0)))
      (expect (uuid-generate source-a) :to-equal "req-0000000000000000")
      (expect (uuid-generate source-a) :to-equal "req-0000000000000001")
      (expect (uuid-generate source-b) :to-equal "req-0000000000000000")))

  (it "sequential-uuid-source-honors-a-non-zero-start"
    (let ((source (make-sequential-uuid-source :prefix "id" :start 255)))
      (expect (uuid-generate source) :to-equal "id-00000000000000ff")
      (expect (uuid-generate source) :to-equal "id-0000000000000100")))

  (it "sequential-uuid-source-rejects-invalid-prefix-and-start"
    (signals error
      (make-sequential-uuid-source :prefix :not-a-string))
    (signals error
      (make-sequential-uuid-source :start -1))
    (signals error
      (make-sequential-uuid-source :start 1.5d0))))

(describe "native uuid source"
  (it "make-uuid-source-generates-distinct-version-4-identifiers"
    (let* ((source (make-uuid-source))
           (first (uuid-generate source))
           (second (uuid-generate source)))
      (expect first :to-have-length 36)
      (expect (char first 14) :to-be #\4)
      (expect second :not :to-equal first)))

  (it "make-uuid-source-rejects-a-non-function-generator"
    (signals error
      (make-uuid-source :generate-fn :bad)))

  (it "make-uuid-source-uses-an-injected-generator"
    (let ((source (make-uuid-source :generate-fn (lambda () "fixed"))))
      (expect (uuid-generate source) :to-equal "fixed"))))

(describe "test uuid source"
  (it "test-uuid-source-consumes-queued-values"
    (let ((source (make-test-uuid-source :values (list "a" "b"))))
      (expect (uuid-generate source) :to-equal "a")
      (expect (uuid-generate source) :to-equal "b")))

  (it "test-uuid-source-copies-seeded-values"
    (let* ((values (list "a" "b"))
           (source (make-test-uuid-source :values values)))
      (setf (first values) "changed"
            (rest values) nil)
      (expect (uuid-generate source) :to-equal "a")
      (expect (uuid-generate source) :to-equal "b")))

  (it "test-uuid-source-signals-when-values-are-exhausted"
    (let ((source (make-test-uuid-source :values (list "only"))))
      (expect (uuid-generate source) :to-equal "only")
      (signals error
        (uuid-generate source))))

  (it "test-uuid-source-rejects-non-list-values-and-non-string-entries"
    (signals error
      (make-test-uuid-source :values #("a")))
    (signals error
      (uuid-generate (make-test-uuid-source :values (list 42))))))

(describe "recording uuid source"
  (it "recording-uuid-source-records-the-generated-identifier"
    (let* ((delegate (make-test-uuid-source :values (list "id-1" "id-2")))
           (source (make-recording-uuid-source :delegate delegate)))
      (expect (uuid-generate source) :to-equal "id-1")
      (expect (uuid-generate source) :to-equal "id-2")
      (expect (recording-uuid-source-calls source)
              :to-have-recorded-calls (list (boundary-call-plist :generate '() :result "id-1")
                                            (boundary-call-plist :generate '() :result "id-2")))))

  (it "make-recording-uuid-source-defaults-to-a-real-delegate"
    (let ((source (make-recording-uuid-source)))
      (expect (uuid-generate source) :to-have-length 36)
      (expect (recording-uuid-source-calls source) :to-have-length 1)))

  (it "make-recording-uuid-source-rejects-a-non-uuid-source-delegate"
    (signals error
      (make-recording-uuid-source :delegate :bad)))

  (it-each ((recording-uuid-source-calls)
            (reset-recording-uuid-source-calls))
      "~A signals for unsupported source types"
      (operation)
    (expect (lambda () (funcall operation (make-uuid-source))) :to-throw "Unsupported UUID source type"))

  (deftest-reset-recording-clears-history
      "reset-recording-uuid-source-calls-clears-history-and-returns-the-source"
      (source (make-recording-uuid-source
               :delegate (make-test-uuid-source :values (list "a" "b"))))
      (recording-uuid-source-calls reset-recording-uuid-source-calls)
    (uuid-generate source)))

