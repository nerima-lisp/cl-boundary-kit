;;;; t/filesystem-test.lisp

(in-package #:cl-boundary-kit/test)

(defun assert-recorded-calls (filesystem expected)
  (expect (equal (recording-filesystem-calls filesystem) expected) :to-be-truthy))

(defun assert-no-recorded-calls (filesystem)
  (expect (null (recording-filesystem-calls filesystem)) :to-be-truthy))

(defmacro assert-recording-filesystem-does-not-record-on-error ((filesystem &rest delegate-initargs)
                                                                &body operation)
  `(let ((,filesystem (make-recording-filesystem
                       :delegate (make-filesystem ,@delegate-initargs))))
     (signals error
       ,@operation)
     (assert-no-recorded-calls ,filesystem)))

(it "filesystem-round-trip"
  (let* ((directory (merge-pathnames #P"cl-boundary-kit-test/"
                                     (uiop:temporary-directory)))
         (path (merge-pathnames #P"sample.txt" directory))
         (fs (make-filesystem)))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (expect (filesystem-store-file fs path "hello") :to-be-truthy)
           (expect (string= (filesystem-read-file fs path) "hello") :to-be-truthy)
           (expect (filesystem-path-exists-p fs path) :to-be-truthy))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

;;; Regression: FILE-LENGTH counts octets, so a multibyte external format used
;;; to over-allocate the read buffer and leave a trailing NUL/wrong length.
(it "filesystem-round-trip-preserves-multibyte-content"
  (let* ((directory (merge-pathnames #P"cl-boundary-kit-test/"
                                     (uiop:temporary-directory)))
         (path (merge-pathnames #P"multibyte.txt" directory))
         (fs (make-filesystem))
         (content "caf\U000000E9 \U000003BB \U0001F600 boundary"))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (expect (filesystem-store-file fs path content :external-format :utf-8)
                   :to-be-truthy)
           (let ((read-back (filesystem-read-file fs path :external-format :utf-8)))
             (expect (string= read-back content) :to-be-truthy)
             (expect (= (length read-back) (length content)) :to-be-truthy)))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

;;; Exercises the native list-directory path (previously only fakes were
;;; tested), verifying real directory enumeration end to end.
(it "native-filesystem-lists-directory-entries"
  (let* ((directory (merge-pathnames #P"cl-boundary-kit-listdir-test/"
                                     (uiop:temporary-directory)))
         (fs (make-filesystem))
         (alpha (merge-pathnames #P"alpha.txt" directory))
         (beta (merge-pathnames #P"beta.txt" directory)))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (filesystem-store-file fs alpha "a")
           (filesystem-store-file fs beta "b")
           (let ((names (sort (mapcar #'file-namestring
                                      (filesystem-list-directory fs directory))
                              #'string<)))
             (expect (equal names '("alpha.txt" "beta.txt")) :to-be-truthy)))
      (ignore-errors (delete-file alpha))
      (ignore-errors (delete-file beta))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "make-filesystem-rejects-non-function-collaborators"
  (dolist (case '((:read-file-fn :bad)
                  (:write-file-fn :bad)
                  (:probe-file-fn :bad)
                  (:list-directory-fn :bad)
                  (:path-exists-p-fn :bad)))
    (signals error
      (apply #'make-filesystem case))))

(it "test-filesystem-supports-stateful-read-write-and-inspection"
  (let* ((path-a #P"/tmp/a.txt")
         (path-b #P"/tmp/nested/b.txt")
         (fs (make-test-filesystem :initial-files (list path-a "hello"))))
    (let ((expected-calls (list
                           (boundary-call-plist :read-file
                                                (list path-a :external-format nil)
                                                :result "hello")
                           (boundary-call-plist :write-file
                                                (list path-a
                                                      :content " world"
                                                      :if-exists :append
                                                      :if-does-not-exist nil
                                                      :external-format nil)
                                                :result t)
                           (boundary-call-plist :read-file
                                                (list path-a :external-format nil)
                                                :result "hello world")
                           (boundary-call-plist :write-file
                                                (list path-b
                                                      :content "payload"
                                                      :if-exists nil
                                                      :if-does-not-exist :create
                                                      :external-format nil)
                                                :result t)
                           (boundary-call-plist :read-file
                                                (list path-b :external-format nil)
                                                :result "payload")
                           (boundary-call-plist :probe-file
                                                (list path-a)
                                                :result path-a)
                           (boundary-call-plist :path-exists-p
                                                (list path-b)
                                                :result t)
                           (boundary-call-plist :list-directory
                                                (list #P"/tmp/")
                                                :result (list path-a path-b)))))
    (expect (string= (filesystem-read-file fs path-a) "hello") :to-be-truthy)
    (expect (filesystem-store-file fs path-a " world" :if-exists :append) :to-be-truthy)
    (expect (string= (filesystem-read-file fs path-a) "hello world") :to-be-truthy)
    (expect (filesystem-store-file fs path-b "payload" :if-does-not-exist :create) :to-be-truthy)
    (expect (string= (filesystem-read-file fs path-b) "payload") :to-be-truthy)
    (expect (equal (filesystem-probe-file fs path-a) path-a) :to-be-truthy)
    (expect (filesystem-path-exists-p fs path-b) :to-be-truthy)
    (expect (equal (filesystem-list-directory fs #P"/tmp/")
               (list path-a path-b)) :to-be-truthy)
    (assert-recorded-calls fs expected-calls))))

(it "test-filesystem-validates-initial-files-and-write-modes"
  (let* ((path #P"/tmp/plist.txt")
         (fs (make-test-filesystem :initial-files (list path "plist"))))
    (expect (string= (filesystem-read-file fs path) "plist") :to-be-truthy))
  (signals error
    (make-test-filesystem :initial-files '(:bad)))
  (signals error
    (filesystem-read-file (make-test-filesystem) #P"/tmp/missing.txt"))
  (signals error
    (filesystem-store-file (make-test-filesystem)
                           #P"/tmp/missing.txt"
                           "hello"
                           :if-does-not-exist :error))
  (signals error
    (filesystem-store-file (make-test-filesystem :initial-files (list #P"/tmp/out.txt" "old"))
                           #P"/tmp/out.txt"
                           "new"
                           :if-exists :error)))

(it "recording-filesystem-records"
  (let* ((fs (make-recording-filesystem))
         (path #P"/tmp/example.txt"))
    (let ((result (ignore-errors (filesystem-probe-file fs path))))
      (expect (null result) :to-be-truthy)
      (assert-recorded-calls fs
                             (list (boundary-call-plist :probe-file
                                                        (list path)
                                                        :result result))))))

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
      (expect (string= (filesystem-read-file fs path :external-format :utf-8) "payload") :to-be-truthy)
      (expect (filesystem-store-file fs path "hello"
                                 :if-exists :append
                                 :if-does-not-exist :create
                                 :external-format :utf-8) :to-be-truthy)
      (expect (equal observed-read-args
                 (list path :external-format :utf-8)) :to-be-truthy)
      (expect (equal observed-write-args
                 (list path
                       :content "hello"
                       :if-exists :append
                       :if-does-not-exist :create
                       :external-format :utf-8)) :to-be-truthy)
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
      (expect (equal (filesystem-list-directory fs directory) entries) :to-be-truthy)
      (expect (filesystem-path-exists-p fs #P"/tmp/demo/a.txt") :to-be-truthy)
      (assert-recorded-calls fs
                             (list
                               (boundary-call-plist :list-directory
                                                    (list directory)
                                                    :result entries)
                               (boundary-call-plist :path-exists-p
                                                    (list #P"/tmp/demo/a.txt")
                                                    :result t))))))

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
                             :external-format :utf-8))))

(it "make-recording-filesystem-rejects-non-filesystem-delegate"
  (signals error
    (make-recording-filesystem :delegate :bad)))

(it "recording-filesystem-calls-signals-for-unsupported-filesystem-types"
  (signals-error-message-contains "Unsupported filesystem type"
      (recording-filesystem-calls (make-filesystem))))
