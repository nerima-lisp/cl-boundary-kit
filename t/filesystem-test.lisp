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

(it "test-filesystem-copies-seeded-file-content"
  (let* ((path #P"/tmp/seed.txt")
         (content (copy-seq "seed"))
         (fs (make-test-filesystem :initial-files (list path content))))
    (setf (char content 0) #\S)
    (expect (string= (filesystem-read-file fs path) "seed") :to-be-truthy)))

(it "test-filesystem-copies-written-file-content"
  (let* ((path #P"/tmp/write.txt")
         (content (copy-seq "write"))
         (fs (make-test-filesystem)))
    (filesystem-store-file fs path content)
    (setf (char content 0) #\W)
    (expect (string= (filesystem-read-file fs path) "write") :to-be-truthy)))

(it "test-filesystem-read-file-returns-independent-content"
  (let* ((path #P"/tmp/read.txt")
         (fs (make-test-filesystem :initial-files (list path "read")))
         (read-back (filesystem-read-file fs path)))
    (setf (char read-back 0) #\R)
    (expect (string= (filesystem-read-file fs path) "read") :to-be-truthy)))

(it "test-filesystem-copy-file-does-not-expose-source-content"
  (let* ((source #P"/tmp/source.txt")
         (destination #P"/tmp/destination.txt")
         (fs (make-test-filesystem :initial-files (list source "copy"))))
    (filesystem-copy-file fs source destination)
    (let ((read-back (filesystem-read-file fs destination)))
      (setf (char read-back 0) #\C))
    (expect (string= (filesystem-read-file fs source) "copy") :to-be-truthy)
    (expect (string= (filesystem-read-file fs destination) "copy") :to-be-truthy)))

(it "recording-filesystem-records"
  (let* ((fs (make-recording-filesystem))
         (path #P"/tmp/example.txt"))
    (let ((result (ignore-errors (filesystem-probe-file fs path))))
      (expect (null result) :to-be-truthy)
      (assert-recorded-calls fs
                             (list (boundary-call-plist :probe-file
                                                        (list path)
                                                        :result result))))))

;;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
;;; double-record every call -- once on the wrapper, once on the delegate's
;;; own history -- because MAKE-RECORDING-FILESYSTEM copied the delegate's
;;; already-self-recording read/write/etc. closures verbatim. Only the
;;; wrapper should record.
(it "recording-filesystem-does-not-double-record-a-self-recording-delegate"
  (let* ((delegate (make-test-filesystem :initial-files (list #P"/tmp/a.txt" "hello")))
         (fs (make-recording-filesystem :delegate delegate)))
    (filesystem-read-file fs #P"/tmp/a.txt")
    (expect (= (length (recording-filesystem-calls fs)) 1) :to-be-truthy)
    (expect (= (length (recording-filesystem-calls delegate)) 0) :to-be-truthy)))

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

(it "reset-recording-filesystem-calls-clears-history-and-returns-the-filesystem"
  (let ((fs (make-test-filesystem :initial-files (list #P"/tmp/a.txt" "hi"))))
    (filesystem-read-file fs #P"/tmp/a.txt")
    (expect (= (length (recording-filesystem-calls fs)) 1) :to-be-truthy)
    (expect (eq (reset-recording-filesystem-calls fs) fs) :to-be-truthy)
    (expect (null (recording-filesystem-calls fs)) :to-be-truthy)
    (filesystem-read-file fs #P"/tmp/a.txt")
    (expect (= (length (recording-filesystem-calls fs)) 1) :to-be-truthy)))

(it "reset-recording-filesystem-calls-signals-for-unsupported-filesystem-types"
  (signals-error-message-contains "Unsupported filesystem type"
      (reset-recording-filesystem-calls (make-filesystem))))

;;; Regression: %SNAPSHOT-RECORDED-CALLS used to only COPY-LIST each call
;;; plist, leaving a returned :RESULT list (or :ARGUMENTS) shared with the
;;; boundary's own history. Destructively editing the value the caller
;;; already holds (here NREVERSE on the returned directory listing) must not
;;; retroactively corrupt what RECORDING-FILESYSTEM-CALLS reports.
(it "recording-filesystem-history-is-independent-of-the-returned-result"
  (let* ((entries (list "a.txt" "b.txt"))
         (fs (make-recording-filesystem
              :delegate (make-filesystem
                         :list-directory-fn (lambda (directory)
                                              (declare (ignore directory))
                                              entries)))))
    (let ((result (filesystem-list-directory fs #P"/tmp/")))
      (setf result (nreverse result))
      (expect (equal (getf (first (recording-filesystem-calls fs)) :result)
                 (list "a.txt" "b.txt")) :to-be-truthy))))

;;; Regression: :IF-EXISTS :OVERWRITE on MAKE-TEST-FILESYSTEM used to behave
;;; like :SUPERSEDE (full replacement). Real CL :OVERWRITE opens the file
;;; positioned at the start without truncating, so bytes beyond the new
;;; content's length survive; the fake must match so tests written against it
;;; do not diverge from MAKE-FILESYSTEM in production.
(it "test-filesystem-overwrite-preserves-trailing-content-like-the-real-filesystem"
  (let ((fs (make-test-filesystem :initial-files (list #P"/tmp/ov.txt" "hello world"))))
    (expect (filesystem-store-file fs #P"/tmp/ov.txt" "hi" :if-exists :overwrite)
            :to-be-truthy)
    (expect (string= (filesystem-read-file fs #P"/tmp/ov.txt") "hillo world")
            :to-be-truthy)))

;;; Regression: FILESYSTEM-STORE-FILE's unknown-option check used PLIST-REMOVE-KEYS,
;;; which pushed VALUE before KEY and so returned keys/values transposed. The
;;; error message must report the actual offending option as a valid plist.
(it "filesystem-store-file-reports-unknown-options-as-a-valid-plist"
  (signals-error-message-contains "(:BOGUS 1)"
      (filesystem-store-file (make-filesystem) #P"/tmp/x.txt" "content" :bogus 1)))

;;; Regression: %REAL-FILESYSTEM-LIST-DIRECTORY merged a wild name/type onto
;;; (PATHNAME DIRECTORY) directly; without a trailing separator, a string
;;; like ".../dirtest" parses its last component as a NAME, so the merge
;;; listed the *parent* directory instead of DIRECTORY itself.
(it "native-filesystem-lists-directory-entries-without-a-trailing-slash"
  (let* ((directory (merge-pathnames #P"cl-boundary-kit-notrailingslash-test/"
                                     (uiop:temporary-directory)))
         (fs (make-filesystem))
         (alpha (merge-pathnames #P"alpha.txt" directory)))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (filesystem-store-file fs alpha "a")
           (let* ((directory-string (string-right-trim "/" (namestring directory)))
                  (names (mapcar #'file-namestring
                                 (filesystem-list-directory fs directory-string))))
             (expect (equal names '("alpha.txt")) :to-be-truthy)))
      (ignore-errors (delete-file alpha))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "test-filesystem-delete-file-removes-an-entry-and-reports-presence"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (expect (eq t (filesystem-path-exists-p fs #P"a.txt")) :to-be-truthy)
    (expect (eq t (filesystem-delete-file fs #P"a.txt")) :to-be-truthy)
    (expect (null (filesystem-path-exists-p fs #P"a.txt")) :to-be-truthy)
    ;; Deleting an absent file reports NIL.
    (expect (null (filesystem-delete-file fs #P"a.txt")) :to-be-truthy)))

(it "test-filesystem-records-delete-file-calls"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (filesystem-delete-file fs #P"a.txt")
    (assert-recorded-calls fs (list (boundary-call-plist :delete-file (list #P"a.txt") :result t)))))

(it "recording-filesystem-records-delete-file-with-the-delegate-result"
  (let ((fs (make-recording-filesystem
             :delegate (make-test-filesystem :initial-files '((#P"a.txt" . "hello"))))))
    (expect (eq t (filesystem-delete-file fs #P"a.txt")) :to-be-truthy)
    (assert-recorded-calls fs (list (boundary-call-plist :delete-file (list #P"a.txt") :result t)))))

(it "recording-filesystem-records-delete-file-when-delegate-reports-absence"
  (let ((fs (make-recording-filesystem
             :delegate (make-filesystem :delete-file-fn (lambda (path)
                                                          (declare (ignore path))
                                                          nil)))))
    (expect (null (filesystem-delete-file fs #P"missing.txt")) :to-be-truthy)
    (assert-recorded-calls fs (list (boundary-call-plist :delete-file (list #P"missing.txt") :result nil)))))

(it "make-filesystem-delete-file-removes-a-real-file"
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames "cl-boundary-kit-delete-test/" (uiop:temporary-directory))))
         (path (merge-pathnames "victim.txt" directory)))
    (ensure-directories-exist directory)
    (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
      (write-string "bye" out))
    (unwind-protect
         (let ((fs (make-filesystem)))
           (expect (eq t (filesystem-delete-file fs path)) :to-be-truthy)
           (expect (null (probe-file path)) :to-be-truthy)
           ;; Deleting again reports NIL rather than signaling.
           (expect (null (filesystem-delete-file fs path)) :to-be-truthy))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "make-filesystem-rejects-a-non-function-delete-file-fn"
  (signals error
    (make-filesystem :delete-file-fn :bad)))

(it "test-filesystem-copy-file-duplicates-content-and-keeps-the-source"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (expect (equal #P"b.txt" (filesystem-copy-file fs #P"a.txt" #P"b.txt")) :to-be-truthy)
    (expect (string= "hello" (filesystem-read-file fs #P"a.txt")) :to-be-truthy)
    (expect (string= "hello" (filesystem-read-file fs #P"b.txt")) :to-be-truthy)))

(it "test-filesystem-copy-file-rejects-self-copy"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (signals error
      (filesystem-copy-file fs #P"a.txt" #P"a.txt"))
    (expect (string= "hello" (filesystem-read-file fs #P"a.txt")) :to-be-truthy)))

(it "test-filesystem-rename-file-moves-content-and-drops-the-source"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (expect (equal #P"b.txt" (filesystem-rename-file fs #P"a.txt" #P"b.txt")) :to-be-truthy)
    (expect (null (filesystem-path-exists-p fs #P"a.txt")) :to-be-truthy)
    (expect (string= "hello" (filesystem-read-file fs #P"b.txt")) :to-be-truthy)))

(it "test-filesystem-rename-file-rejects-self-rename"
  (let ((fs (make-test-filesystem :initial-files '((#P"a.txt" . "hello")))))
    (signals error
      (filesystem-rename-file fs #P"a.txt" #P"a.txt"))
    (expect (string= "hello" (filesystem-read-file fs #P"a.txt")) :to-be-truthy)))

(it "test-filesystem-copy-and-rename-signal-for-a-missing-source"
  (let ((fs (make-test-filesystem)))
    (signals error (filesystem-copy-file fs #P"missing.txt" #P"b.txt"))
    (signals error (filesystem-rename-file fs #P"missing.txt" #P"b.txt"))))

(it "recording-filesystem-records-copy-and-rename"
  (let ((fs (make-recording-filesystem
             :delegate (make-test-filesystem :initial-files '((#P"a.txt" . "hi"))))))
    (filesystem-copy-file fs #P"a.txt" #P"b.txt")
    (filesystem-rename-file fs #P"b.txt" #P"c.txt")
    (assert-recorded-calls
     fs
     (list (boundary-call-plist :copy-file (list #P"a.txt" #P"b.txt") :result #P"b.txt")
           (boundary-call-plist :rename-file (list #P"b.txt" #P"c.txt") :result #P"c.txt")))))

(it "make-filesystem-copy-and-rename-operate-on-real-files"
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames "cl-boundary-kit-move-test/" (uiop:temporary-directory))))
         (source (merge-pathnames "source.txt" directory))
         (copy (merge-pathnames "copy.txt" directory))
         (moved (merge-pathnames "moved.txt" directory)))
    (ensure-directories-exist directory)
    (with-open-file (out source :direction :output :if-exists :supersede :if-does-not-exist :create)
      (write-string "payload" out))
    (unwind-protect
         (let ((fs (make-filesystem)))
           (filesystem-copy-file fs source copy)
           (expect (not (null (probe-file source))) :to-be-truthy)
           (expect (string= "payload" (uiop:read-file-string copy)) :to-be-truthy)
           (filesystem-rename-file fs copy moved)
           (expect (null (probe-file copy)) :to-be-truthy)
           (expect (string= "payload" (uiop:read-file-string moved)) :to-be-truthy))
      (dolist (p (list source copy moved))
        (ignore-errors (delete-file p)))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "make-filesystem-copy-file-rejects-self-copy-without-truncating"
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames "cl-boundary-kit-self-copy-test/" (uiop:temporary-directory))))
         (path (merge-pathnames "source.txt" directory)))
    (ensure-directories-exist directory)
    (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
      (write-string "payload" out))
    (unwind-protect
         (let ((fs (make-filesystem)))
           (signals error
             (filesystem-copy-file fs path path))
           (expect (string= "payload" (uiop:read-file-string path)) :to-be-truthy))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "make-filesystem-rename-file-rejects-self-rename-without-deleting"
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames "cl-boundary-kit-self-rename-test/" (uiop:temporary-directory))))
         (path (merge-pathnames "source.txt" directory)))
    (ensure-directories-exist directory)
    (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
      (write-string "payload" out))
    (unwind-protect
         (let ((fs (make-filesystem)))
           (signals error
             (filesystem-rename-file fs path path))
           (expect (string= "payload" (uiop:read-file-string path)) :to-be-truthy))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

(it "make-filesystem-rejects-non-function-copy-and-rename-fns"
  (signals error (make-filesystem :copy-file-fn :bad))
  (signals error (make-filesystem :rename-file-fn :bad)))

(it "test-filesystem-make-and-check-directory"
  (let ((fs (make-test-filesystem)))
    (expect (null (filesystem-directory-exists-p fs #P"/tmp/work/")) :to-be-truthy)
    (filesystem-make-directory fs #P"/tmp/work/")
    (expect (eq t (filesystem-directory-exists-p fs #P"/tmp/work/")) :to-be-truthy)))

(it "test-filesystem-directory-with-files-exists-implicitly"
  (let ((fs (make-test-filesystem :initial-files '((#P"/tmp/data/a.txt" . "x")))))
    (expect (eq t (filesystem-directory-exists-p fs #P"/tmp/data/")) :to-be-truthy)))

(it "test-filesystem-delete-empty-directory-and-refuse-non-empty"
  (let ((fs (make-test-filesystem :initial-files '((#P"/tmp/full/a.txt" . "x")))))
    (filesystem-make-directory fs #P"/tmp/empty/")
    (expect (eq t (filesystem-delete-directory fs #P"/tmp/empty/")) :to-be-truthy)
    (expect (null (filesystem-directory-exists-p fs #P"/tmp/empty/")) :to-be-truthy)
    ;; Deleting an absent directory reports NIL.
    (expect (null (filesystem-delete-directory fs #P"/tmp/absent/")) :to-be-truthy)
    ;; A non-empty directory refuses deletion.
    (signals error (filesystem-delete-directory fs #P"/tmp/full/"))))

(it "recording-filesystem-records-directory-operations"
  (let ((fs (make-recording-filesystem :delegate (make-test-filesystem))))
    (filesystem-make-directory fs #P"/tmp/d/")
    (filesystem-directory-exists-p fs #P"/tmp/d/")
    (filesystem-delete-directory fs #P"/tmp/d/")
    (assert-recorded-calls
     fs
     (list (boundary-call-plist :make-directory (list #P"/tmp/d/") :result #P"/tmp/d/")
           (boundary-call-plist :directory-exists-p (list #P"/tmp/d/") :result t)
           (boundary-call-plist :delete-directory (list #P"/tmp/d/") :result t)))))

(it "make-filesystem-directory-operations-work-on-real-directories"
  (let* ((base (uiop:ensure-directory-pathname
                (merge-pathnames "cl-boundary-kit-dir-test/" (uiop:temporary-directory))))
         (sub (merge-pathnames "sub/" base)))
    (ignore-errors (uiop:delete-empty-directory sub))
    (ignore-errors (uiop:delete-empty-directory base))
    (unwind-protect
         (let ((fs (make-filesystem)))
           (filesystem-make-directory fs sub)
           (expect (eq t (filesystem-directory-exists-p fs sub)) :to-be-truthy)
           (expect (eq t (filesystem-delete-directory fs sub)) :to-be-truthy)
           (expect (null (filesystem-directory-exists-p fs sub)) :to-be-truthy))
      (ignore-errors (uiop:delete-empty-directory sub))
      (ignore-errors (uiop:delete-empty-directory base)))))

(it "make-filesystem-rejects-non-function-directory-collaborators"
  (signals error (make-filesystem :make-directory-fn :bad))
  (signals error (make-filesystem :directory-exists-p-fn :bad))
  (signals error (make-filesystem :delete-directory-fn :bad)))

(it "test-filesystem-read-file-lines-splits-content-with-read-line-semantics"
  (let ((fs (make-test-filesystem
             :initial-files (list (cons #P"a.txt" (format nil "one~%two~%three"))
                                  (cons #P"b.txt" (format nil "trailing~%"))
                                  (cons #P"empty.txt" "")))))
    (expect (equal (list "one" "two" "three") (filesystem-read-file-lines fs #P"a.txt")) :to-be-truthy)
    ;; A trailing newline does not yield a final empty line.
    (expect (equal (list "trailing") (filesystem-read-file-lines fs #P"b.txt")) :to-be-truthy)
    (expect (null (filesystem-read-file-lines fs #P"empty.txt")) :to-be-truthy)))

(it "recording-filesystem-read-file-lines-records-the-underlying-read"
  (let ((fs (make-recording-filesystem
             :delegate (make-test-filesystem
                        :initial-files (list (cons #P"a.txt" (format nil "x~%y")))))))
    (expect (equal (list "x" "y") (filesystem-read-file-lines fs #P"a.txt")) :to-be-truthy)
    (expect (equal (list :read-file)
                   (recorded-call-operations (recording-filesystem-calls fs))) :to-be-truthy)))

(it "filesystem-store-file-lines-round-trips-with-read-file-lines"
  (let ((fs (make-test-filesystem)))
    (filesystem-store-file-lines fs #P"out.txt" (list "one" "two" "three"))
    (expect (string= (format nil "one~%two~%three~%") (filesystem-read-file fs #P"out.txt")) :to-be-truthy)
    (expect (equal (list "one" "two" "three") (filesystem-read-file-lines fs #P"out.txt")) :to-be-truthy)))

(it "filesystem-store-file-lines-forwards-write-options-and-records-the-write"
  (let ((fs (make-recording-filesystem :delegate (make-test-filesystem))))
    (filesystem-store-file-lines fs #P"out.txt" (list "x") :if-exists :supersede)
    (expect (equal (list :write-file)
                   (recorded-call-operations (recording-filesystem-calls fs))) :to-be-truthy)))

(it "filesystem-store-file-lines-rejects-non-string-lines"
  (signals error
    (filesystem-store-file-lines (make-test-filesystem) #P"out.txt" (list 42))))

(it "filesystem-append-file-creates-then-appends"
  (let ((fs (make-test-filesystem)))
    ;; Appends to a file that does not exist yet -> creates it.
    (filesystem-append-file fs #P"log.txt" "first")
    (expect (string= "first" (filesystem-read-file fs #P"log.txt")) :to-be-truthy)
    ;; A second append extends the existing content.
    (filesystem-append-file fs #P"log.txt" "-second")
    (expect (string= "first-second" (filesystem-read-file fs #P"log.txt")) :to-be-truthy)))

(it "filesystem-append-file-records-the-write-with-append-options"
  (let ((fs (make-recording-filesystem :delegate (make-test-filesystem))))
    (filesystem-append-file fs #P"log.txt" "x")
    (assert-recorded-calls
     fs
     (list (boundary-call-plist
            :write-file
            (list #P"log.txt" :content "x"
                  :if-exists :append :if-does-not-exist :create :external-format nil)
            :result t)))))

(it "filesystem-store-file-rejects-an-odd-length-option-list"
  (let ((filesystem (make-test-filesystem)))
    (signals-error-message-contains "Option list ended after"
      (filesystem-store-file filesystem "/tmp/f.txt" "data" :if-exists))))

(it "filesystem-store-file-rejects-unknown-write-options"
  (let ((filesystem (make-test-filesystem)))
    (signals-error-message-contains "Unknown filesystem write options"
      (filesystem-store-file filesystem "/tmp/f.txt" "data" :bogus 1))))

(it "recording-filesystem-calls-rejects-a-non-filesystem-argument"
  (signals-error-message-contains "must be a filesystem"
    (recording-filesystem-calls 42)))

(it "filesystem-store-file-lines-rejects-non-list-lines"
  (signals-error-message-contains "lines must be a list of strings"
    (filesystem-store-file-lines (make-test-filesystem) "/tmp/x.txt" 42)))
