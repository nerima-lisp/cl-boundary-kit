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

;; The test above only exercises an out-of-range integer :START, taking the
;; AND's other operand's false branch; a non-integer takes INTEGERP's own
;; false branch.
(it "sequential-temp-path-source-rejects-a-non-integer-start"
  (signals error
    (make-sequential-temp-path-source :start 1.5)))

;; Every other MAKE-SEQUENTIAL-TEMP-PATH-SOURCE call above supplies at least
;; one explicit keyword; exercise all four &KEY defaults together too.
(it "sequential-temp-path-source-defaults-to-tmp-with-a-zero-start"
  (let ((source (make-sequential-temp-path-source)))
    (expect (equal #P"/tmp/tmp-00000000" (temp-path-next source)) :to-be-truthy)))

(it "make-temp-path-source-generates-distinct-paths-under-the-directory"
  (let* ((source (make-temp-path-source :directory #P"/tmp/" :prefix "x"))
         (first (temp-path-next source))
         (second (temp-path-next source)))
    (expect (pathnamep first) :to-be-truthy)
    (expect (not (equal first second)) :to-be-truthy)
    (expect (equal #P"/tmp/" (make-pathname :name nil :type nil :defaults first)) :to-be-truthy)))

(it "make-temp-path-source-skips-existing-random-candidates"
  (let* ((state (make-random-state t))
         (probe-state (make-random-state state))
         (occupied (merge-pathnames
                    (pathname (format nil "x-~(~32,'0x~).tmp"
                                      (random (ash 1 128) probe-state)))
                    #P"/tmp/"))
         (source (make-temp-path-source :directory #P"/tmp/"
                                        :prefix "x"
                                        :suffix ".tmp"
                                        :state state)))
    (unwind-protect
         (progn
           (with-open-file (stream occupied
                                   :direction :output
                                   :if-exists :supersede
                                   :if-does-not-exist :create)
             (write-string "occupied" stream))
           (expect (not (equal occupied (temp-path-next source))) :to-be-truthy))
      (when (probe-file occupied)
        (delete-file occupied)))))

(it "make-temp-path-source-rejects-invalid-random-state"
  (signals error
    (make-temp-path-source :state :bad)))

;; %RANDOM-TEMP-PATH tries 256 candidates before giving up; the test above
;; only occupies one, so drive it to full exhaustion here to hit that path.
(it "make-temp-path-source-signals-when-all-256-candidates-are-occupied"
  (let* ((state (make-random-state t))
         (probe-state (make-random-state state))
         (occupied (loop repeat 256
                         collect (merge-pathnames
                                  (pathname (format nil "x-~(~32,'0x~).tmp"
                                                    (random (ash 1 128) probe-state)))
                                  #P"/tmp/")))
         (source (make-temp-path-source :directory #P"/tmp/"
                                        :prefix "x"
                                        :suffix ".tmp"
                                        :state state)))
    (unwind-protect
         (progn
           (dolist (path occupied)
             (with-open-file (stream path
                                     :direction :output
                                     :if-exists :supersede
                                     :if-does-not-exist :create)
               (write-string "occupied" stream)))
           (signals-error-message-contains "Unable to find an unused temp path"
             (temp-path-next source)))
      (dolist (path occupied)
        (when (probe-file path)
          (delete-file path))))))

(it "test-temp-path-source-consumes-queued-paths"
  (let ((source (make-test-temp-path-source :paths (list #P"/tmp/a" "/tmp/b"))))
    (expect (equal #P"/tmp/a" (temp-path-next source)) :to-be-truthy)
    (expect (equal #P"/tmp/b" (temp-path-next source)) :to-be-truthy)))

(it "test-temp-path-source-copies-seeded-paths"
  (let* ((paths (list #P"/tmp/a" "/tmp/b"))
         (source (make-test-temp-path-source :paths paths)))
    (setf (first paths) #P"/tmp/changed"
          (rest paths) nil)
    (expect (equal #P"/tmp/a" (temp-path-next source)) :to-be-truthy)
    (expect (equal #P"/tmp/b" (temp-path-next source)) :to-be-truthy)))

(it "test-temp-path-source-copies-mutable-seeded-path-strings"
  (let* ((path (copy-seq "/tmp/original-path"))
         (source (make-test-temp-path-source :paths (list path))))
    (setf (char path 5) #\X)
    (expect (equal #P"/tmp/original-path" (temp-path-next source)) :to-be-truthy)))

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

;; Every other MAKE-RECORDING-TEMP-PATH-SOURCE test above supplies an
;; explicit :DELEGATE; exercise the &KEY default (a fresh
;; MAKE-TEMP-PATH-SOURCE) too.
(it "recording-temp-path-source-defaults-to-a-fresh-temp-path-source"
  (let ((source (make-recording-temp-path-source)))
    (expect (equal #P"/tmp/" (make-pathname :name nil :type nil
                                            :defaults (temp-path-next source)))
            :to-be-truthy)
    (expect (= (length (recording-temp-path-source-calls source)) 1) :to-be-truthy)))

(it-each ((recording-temp-path-source-calls)
          (reset-recording-temp-path-source-calls))
    "~A signals for unsupported source types"
    (operation)
  (expect (lambda () (funcall operation (make-temp-path-source)))
          :to-signal-message-containing "Unsupported temp path source type"))

(deftest-reset-recording-clears-history
    "reset-recording-temp-path-source-calls-clears-history-and-returns-the-source"
    (source (make-recording-temp-path-source
             :delegate (make-test-temp-path-source :paths (list #P"/tmp/a"))))
    (recording-temp-path-source-calls reset-recording-temp-path-source-calls)
  (temp-path-next source))

;;; Constructor and queue validation error branches.

(it "make-temp-path-source-rejects-a-non-pathname-directory"
  (signals-error-message-contains "Temp path directory must be a pathname or string"
    (make-temp-path-source :directory 42)))

(it "make-test-temp-path-source-rejects-non-list-paths"
  (signals-error-message-contains "Test temp path source paths must be a list"
    (make-test-temp-path-source :paths 42)))

(it "test-temp-path-next-rejects-a-non-pathname-queued-path"
  (let ((source (make-test-temp-path-source :paths (list 42))))
    (signals-error-message-contains "Test temp path source path must be a pathname or string"
      (temp-path-next source))))
