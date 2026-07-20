;;;; t/temp-path-test.lisp

(in-package #:cl-boundary-kit/test)

(it "sequential-temp-path-source-is-deterministic-and-repeatable"
  (let ((source-a (make-sequential-temp-path-source :directory #P"/tmp/" :prefix "job" :suffix ".tmp"))
        (source-b (make-sequential-temp-path-source :directory #P"/tmp/" :prefix "job" :suffix ".tmp")))
    (expect (equal #P"/tmp/job-00000000.tmp" (temp-path-next source-a)) :to-be-truthy)
    (expect (equal #P"/tmp/job-00000001.tmp" (temp-path-next source-a)) :to-be-truthy)
    (expect (equal #P"/tmp/job-00000000.tmp" (temp-path-next source-b)) :to-be-truthy)))

(it "sequential-temp-path-source-honors-a-non-zero-start"
  (let ((source (make-sequential-temp-path-source :directory #P"/var/tmp/" :start 255)))
    (expect (equal #P"/var/tmp/tmp-000000ff" (temp-path-next source)) :to-be-truthy)))

(it "sequential-temp-path-source-rejects-invalid-arguments"
  (signals error
    (make-sequential-temp-path-source :prefix 42))
  (signals error
    (make-sequential-temp-path-source :start -1)))

(it "make-temp-path-source-generates-distinct-paths-under-the-directory"
  (let* ((source (make-temp-path-source :directory #P"/tmp/" :prefix "x"))
         (first (temp-path-next source))
         (second (temp-path-next source)))
    (expect (pathnamep first) :to-be-truthy)
    (expect (not (equal first second)) :to-be-truthy)
    (expect (equal #P"/tmp/" (make-pathname :name nil :type nil :defaults first)) :to-be-truthy)))

(it "test-temp-path-source-consumes-queued-paths"
  (let ((source (make-test-temp-path-source :paths (list #P"/tmp/a" "/tmp/b"))))
    (expect (equal #P"/tmp/a" (temp-path-next source)) :to-be-truthy)
    (expect (equal #P"/tmp/b" (temp-path-next source)) :to-be-truthy)))

(it "test-temp-path-source-signals-when-paths-are-exhausted"
  (let ((source (make-test-temp-path-source :paths (list #P"/tmp/a"))))
    (temp-path-next source)
    (signals error
      (temp-path-next source))))

(it "recording-temp-path-source-records-the-returned-path"
  (let* ((delegate (make-test-temp-path-source :paths (list #P"/tmp/a" #P"/tmp/b")))
         (source (make-recording-temp-path-source :delegate delegate)))
    (temp-path-next source)
    (temp-path-next source)
    (expect (equal (recording-temp-path-source-calls source)
                   (list (boundary-call-plist :next '() :result #P"/tmp/a")
                         (boundary-call-plist :next '() :result #P"/tmp/b"))) :to-be-truthy)))

(it "make-recording-temp-path-source-rejects-a-non-temp-path-source-delegate"
  (signals error
    (make-recording-temp-path-source :delegate :bad)))

(it "recording-temp-path-source-calls-signals-for-unsupported-source-types"
  (signals error
    (recording-temp-path-source-calls (make-temp-path-source))))

(it "reset-recording-temp-path-source-calls-clears-history-and-returns-the-source"
  (let ((source (make-recording-temp-path-source
                 :delegate (make-test-temp-path-source :paths (list #P"/tmp/a")))))
    (temp-path-next source)
    (expect (= 1 (length (recording-temp-path-source-calls source))) :to-be-truthy)
    (expect (eq source (reset-recording-temp-path-source-calls source)) :to-be-truthy)
    (expect (null (recording-temp-path-source-calls source)) :to-be-truthy)))

(it "reset-recording-temp-path-source-calls-signals-for-unsupported-source-types"
  (signals error
    (reset-recording-temp-path-source-calls (make-temp-path-source))))
