;;;; t/uuid-test.lisp

(in-package #:cl-boundary-kit/test)

(it "sequential-uuid-source-is-deterministic-and-repeatable"
  (let ((source-a (make-sequential-uuid-source :prefix "req" :start 0))
        (source-b (make-sequential-uuid-source :prefix "req" :start 0)))
    (expect (string= "req-0000000000000000" (uuid-generate source-a)) :to-be-truthy)
    (expect (string= "req-0000000000000001" (uuid-generate source-a)) :to-be-truthy)
    (expect (string= "req-0000000000000000" (uuid-generate source-b)) :to-be-truthy)))

(it "sequential-uuid-source-honors-a-non-zero-start"
  (let ((source (make-sequential-uuid-source :prefix "id" :start 255)))
    (expect (string= "id-00000000000000ff" (uuid-generate source)) :to-be-truthy)
    (expect (string= "id-0000000000000100" (uuid-generate source)) :to-be-truthy)))

(it "sequential-uuid-source-rejects-invalid-prefix-and-start"
  (signals error
    (make-sequential-uuid-source :prefix :not-a-string))
  (signals error
    (make-sequential-uuid-source :start -1))
  (signals error
    (make-sequential-uuid-source :start 1.5d0)))

(it "make-uuid-source-generates-distinct-version-4-identifiers"
  (let* ((source (make-uuid-source))
         (first (uuid-generate source))
         (second (uuid-generate source)))
    (expect (= 36 (length first)) :to-be-truthy)
    (expect (char= #\4 (char first 14)) :to-be-truthy)
    (expect (not (string= first second)) :to-be-truthy)))

(it "make-uuid-source-rejects-a-non-function-generator"
  (signals error
    (make-uuid-source :generate-fn :bad)))

(it "make-uuid-source-uses-an-injected-generator"
  (let ((source (make-uuid-source :generate-fn (lambda () "fixed"))))
    (expect (string= "fixed" (uuid-generate source)) :to-be-truthy)))

(it "test-uuid-source-consumes-queued-values"
  (let ((source (make-test-uuid-source :values (list "a" "b"))))
    (expect (string= "a" (uuid-generate source)) :to-be-truthy)
    (expect (string= "b" (uuid-generate source)) :to-be-truthy)))

(it "test-uuid-source-copies-seeded-values"
  (let* ((values (list "a" "b"))
         (source (make-test-uuid-source :values values)))
    (setf (first values) "changed"
          (rest values) nil)
    (expect (string= "a" (uuid-generate source)) :to-be-truthy)
    (expect (string= "b" (uuid-generate source)) :to-be-truthy)))

(it "test-uuid-source-signals-when-values-are-exhausted"
  (let ((source (make-test-uuid-source :values (list "only"))))
    (expect (string= "only" (uuid-generate source)) :to-be-truthy)
    (signals error
      (uuid-generate source))))

(it "test-uuid-source-rejects-non-list-values-and-non-string-entries"
  (signals error
    (make-test-uuid-source :values #("a")))
  (signals error
    (uuid-generate (make-test-uuid-source :values (list 42)))))

(it "recording-uuid-source-records-the-generated-identifier"
  (let* ((delegate (make-test-uuid-source :values (list "id-1" "id-2")))
         (source (make-recording-uuid-source :delegate delegate)))
    (expect (string= "id-1" (uuid-generate source)) :to-be-truthy)
    (expect (string= "id-2" (uuid-generate source)) :to-be-truthy)
    (expect (equal (recording-uuid-source-calls source)
                   (list (boundary-call-plist :generate '() :result "id-1")
                         (boundary-call-plist :generate '() :result "id-2"))) :to-be-truthy)))

(it "make-recording-uuid-source-defaults-to-a-real-delegate"
  (let ((source (make-recording-uuid-source)))
    (expect (= 36 (length (uuid-generate source))) :to-be-truthy)
    (expect (= 1 (length (recording-uuid-source-calls source))) :to-be-truthy)))

(it "make-recording-uuid-source-rejects-a-non-uuid-source-delegate"
  (signals error
    (make-recording-uuid-source :delegate :bad)))

(it "recording-uuid-source-calls-signals-for-unsupported-source-types"
  (signals error
    (recording-uuid-source-calls (make-uuid-source))))

(it "reset-recording-uuid-source-calls-clears-history-and-returns-the-source"
  (let ((source (make-recording-uuid-source
                 :delegate (make-test-uuid-source :values (list "a" "b")))))
    (uuid-generate source)
    (expect (= 1 (length (recording-uuid-source-calls source))) :to-be-truthy)
    (expect (eq source (reset-recording-uuid-source-calls source)) :to-be-truthy)
    (expect (null (recording-uuid-source-calls source)) :to-be-truthy)))

(it "reset-recording-uuid-source-calls-signals-for-unsupported-source-types"
  (signals error
    (reset-recording-uuid-source-calls (make-uuid-source))))
