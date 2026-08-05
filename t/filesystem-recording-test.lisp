;;;; t/filesystem-recording-test.lisp
;;;;
;;;; Recording-filesystem tests, split out of filesystem-test.lisp.

(in-package #:cl-boundary-kit/test)

(describe "recording-filesystem records boundary calls"
  (it "recording-filesystem-records"
    (let* ((fs (make-recording-filesystem))
           (path #P"/tmp/example.txt"))
      (let ((result (ignore-errors (filesystem-probe-file fs path))))
        (expect result :to-be-null)
        (assert-recorded-calls fs
                               (list (boundary-call-plist :probe-file
                                                          (list path)
                                                          :result result))))))

  (it "recording-filesystem-does-not-double-record-a-self-recording-delegate"
    (let* ((delegate (make-test-filesystem :initial-files (list #P"/tmp/a.txt" "hello")))
           (fs (make-recording-filesystem :delegate delegate)))
      (filesystem-read-file fs #P"/tmp/a.txt")
      (expect (recording-filesystem-calls fs) :to-have-length 1)
      (expect (recording-filesystem-calls delegate) :to-have-length 0)))

  (it "recording-filesystem-records-read-and-write-options"
    (let ((observed-read-args nil)
          (observed-write-args nil))
      (let* ((fs (make-recording-filesystem
                  :delegate (make-filesystem
                             :read-file-fn (lambda (read-path &key external-format)
                                             (setf observed-read-args
                                                   (list read-path :external-format external-format))
                                             "payload")
                             :write-file-fn (lambda (write-path content
                                                                  &key if-exists if-does-not-exist external-format)
                                              (setf observed-write-args
                                                    (list write-path
                                                          :content content
                                                          :if-exists if-exists
                                                          :if-does-not-exist if-does-not-exist
                                                          :external-format external-format))
                                              t))))
             (path #P"/tmp/example.txt"))
        (expect (filesystem-read-file fs path :external-format :utf-8) :to-equal "payload")
        (expect (filesystem-store-file fs path "hello"
                                   :if-exists :append
                                   :if-does-not-exist :create
                                   :external-format :utf-8) :to-be-truthy)
        (expect observed-read-args :to-equal (list path :external-format :utf-8))
        (expect observed-write-args
                :to-equal (list path
                                :content "hello"
                                :if-exists :append
                                :if-does-not-exist :create
                                :external-format :utf-8))
        (assert-recorded-calls fs
                               (list
                                 (boundary-call-plist :read-file
                                                      (list path :external-format :utf-8)
                                                      :result "payload")
                                 (boundary-call-plist :write-file
                                                      (list path
                                                            :content "hello"
                                                            :if-exists :append
                                                            :if-does-not-exist :create
                                                            :external-format :utf-8)
                                                      :result t))))))

  (it "recording-filesystem-records-list-directory-and-path-exists"
    (let* ((directory #P"/tmp/demo/")
           (entries (list #P"/tmp/demo/a.txt" #P"/tmp/demo/b.txt")))
      (let ((fs (make-recording-filesystem
                 :delegate (make-filesystem
                            :list-directory-fn (lambda (path)
                                                 (declare (ignore path))
                                                 entries)
                            :path-exists-p-fn (lambda (path)
                                                (equal path #P"/tmp/demo/a.txt"))))))
        (expect (filesystem-list-directory fs directory) :to-equal entries)
        (expect (filesystem-path-exists-p fs #P"/tmp/demo/a.txt") :to-be-truthy)
        (assert-recorded-calls fs
                               (list
                                 (boundary-call-plist :list-directory
                                                      (list directory)
                                                      :result entries)
                                 (boundary-call-plist :path-exists-p
                                                      (list #P"/tmp/demo/a.txt")
                                                      :result t)))))))

(describe "recording-filesystem error propagation"
  (it "recording-filesystem-propagates-errors-without-recording"
    (let ((path #P"/tmp/missing.txt"))
      (assert-recording-filesystem-does-not-record-on-error
          (fs :probe-file-fn (lambda (path)
                               (declare (ignore path))
                               (error "probe failed")))
        (filesystem-probe-file fs path))))

  (it "recording-filesystem-propagates-list-directory-errors-without-recording"
    (assert-recording-filesystem-does-not-record-on-error
        (fs :list-directory-fn (lambda (directory)
                                  (declare (ignore directory))
                                  (error "list failed")))
      (filesystem-list-directory fs #P"/tmp/missing/")))

  (it "recording-filesystem-propagates-read-errors-without-recording"
    (let ((path #P"/tmp/missing.txt"))
      (assert-recording-filesystem-does-not-record-on-error
          (fs :read-file-fn (lambda (path &key external-format)
                              (declare (ignore path external-format))
                              (error "read failed")))
        (filesystem-read-file fs path :external-format :utf-8))))

  (it "recording-filesystem-propagates-write-errors-without-recording"
    (let ((path #P"/tmp/out.txt"))
      (assert-recording-filesystem-does-not-record-on-error
          (fs :write-file-fn (lambda (path content
                                  &key if-exists if-does-not-exist external-format)
                               (declare (ignore path content if-exists if-does-not-exist external-format))
                               (error "write failed")))
        (filesystem-store-file fs path "hello"
                               :if-exists :append
                               :if-does-not-exist :create
                               :external-format :utf-8)))))

(describe "recording-filesystem history and delegate validation"
  (it "make-recording-filesystem-rejects-non-filesystem-delegate"
    (signals error
      (make-recording-filesystem :delegate :bad)))

  (it-each ((recording-filesystem-calls)
            (reset-recording-filesystem-calls))
      "~A signals for unsupported filesystem types"
      (operation)
    (expect (lambda () (funcall operation (make-filesystem))) :to-throw "Unsupported filesystem type"))

  (it "reset-recording-filesystem-calls-clears-history-and-returns-the-filesystem"
    (let ((fs (make-test-filesystem :initial-files (list #P"/tmp/a.txt" "hi"))))
      (filesystem-read-file fs #P"/tmp/a.txt")
      (expect (recording-filesystem-calls fs) :to-have-length 1)
      (expect (reset-recording-filesystem-calls fs) :to-be fs)
      (expect (recording-filesystem-calls fs) :to-be-null)
      (filesystem-read-file fs #P"/tmp/a.txt")
      (expect (recording-filesystem-calls fs) :to-have-length 1)))

  (it "recording-filesystem-history-is-independent-of-the-returned-result"
    (let* ((entries (list "a.txt" "b.txt"))
           (fs (make-recording-filesystem
                :delegate (make-filesystem
                           :list-directory-fn (lambda (directory)
                                                (declare (ignore directory))
                                                entries)))))
      (let ((result (filesystem-list-directory fs #P"/tmp/")))
        (setf result (nreverse result))
        (expect (getf (first (recording-filesystem-calls fs)) :result) :to-equal (list "a.txt" "b.txt"))))))
