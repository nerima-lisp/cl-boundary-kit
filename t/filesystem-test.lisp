;;;; t/filesystem-test.lisp

(in-package #:cl-boundary-kit/test)

(defun assert-recorded-calls (filesystem expected)
  (expect (recording-filesystem-calls filesystem) :to-have-recorded-calls expected))

(defun assert-no-recorded-calls (filesystem)
  (expect (recording-filesystem-calls filesystem) :to-be-null))

(defmacro assert-recording-filesystem-does-not-record-on-error ((filesystem &rest delegate-initargs)
                                                                &body operation)
  `(let ((,filesystem (make-recording-filesystem
                       :delegate (make-filesystem ,@delegate-initargs))))
     (signals error
       ,@operation)
     (assert-no-recorded-calls ,filesystem)))

(describe "native filesystem operations"
  (it "filesystem-round-trip"
    (let* ((directory (merge-pathnames #P"cl-boundary-kit-test/"
                                       (uiop:temporary-directory)))
           (path (merge-pathnames #P"sample.txt" directory))
           (fs (make-filesystem)))
      (ensure-directories-exist directory)
      ;; The default PATH-EXISTS-P-FN is (NOT (NULL (PROBE-FILE PATH))), so
      ;; check it for a genuinely absent path before the file is created, not
      ;; only for the present case below.
      (expect (filesystem-path-exists-p fs path) :to-be-null)
      (unwind-protect
           (progn
             (expect (filesystem-store-file fs path "hello") :to-be-truthy)
             (expect (filesystem-read-file fs path) :to-equal "hello")
             (expect (filesystem-path-exists-p fs path) :to-be-truthy))
        (ignore-errors (delete-file path))
        (ignore-errors (uiop:delete-empty-directory directory)))))

  ;; Regression: FILE-LENGTH counts octets, so a multibyte external format used
  ;; to over-allocate the read buffer and leave a trailing NUL/wrong length.
  (it "filesystem-round-trip-preserves-multibyte-content"
    (let* ((directory (merge-pathnames #P"cl-boundary-kit-test/"
                                       (uiop:temporary-directory)))
           (path (merge-pathnames #P"multibyte.txt" directory))
           (fs (make-filesystem))
           (content "café λ 😀 boundary"))
      (ensure-directories-exist directory)
      (unwind-protect
           (progn
             (expect (filesystem-store-file fs path content :external-format :utf-8)
                     :to-be-truthy)
             (let ((read-back (filesystem-read-file fs path :external-format :utf-8)))
               (expect read-back :to-equal content)
               (expect read-back :to-have-length (length content))))
        (ignore-errors (delete-file path))
        (ignore-errors (uiop:delete-empty-directory directory)))))

  ;; Exercises the native list-directory path (previously only fakes were
  ;; tested), verifying real directory enumeration end to end.
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
               (expect names :to-equal '("alpha.txt" "beta.txt"))))
        (ignore-errors (delete-file alpha))
        (ignore-errors (delete-file beta))
        (ignore-errors (uiop:delete-empty-directory directory)))))

  ;; Regression: %REAL-FILESYSTEM-LIST-DIRECTORY merged a wild name/type onto
  ;; (PATHNAME DIRECTORY) directly; without a trailing separator, a string
  ;; like ".../dirtest" parses its last component as a NAME, so the merge
  ;; listed the *parent* directory instead of DIRECTORY itself.
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
               (expect names :to-equal '("alpha.txt"))))
        (ignore-errors (delete-file alpha))
        (ignore-errors (uiop:delete-empty-directory directory))))))

(describe "test filesystem"
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
      (with-soft-assertions
        (expect (filesystem-read-file fs path-a) :to-equal "hello")
        (expect (filesystem-store-file fs path-a " world" :if-exists :append) :to-be-truthy)
        (expect (filesystem-read-file fs path-a) :to-equal "hello world")
        (expect (filesystem-store-file fs path-b "payload" :if-does-not-exist :create) :to-be-truthy)
        (expect (filesystem-read-file fs path-b) :to-equal "payload")
        (expect (filesystem-probe-file fs path-a) :to-equal path-a)
        (expect (filesystem-path-exists-p fs path-b) :to-be-truthy)
        (expect (filesystem-list-directory fs #P"/tmp/") :to-equal (list path-a path-b))
        (assert-recorded-calls fs expected-calls)))))

  (it "test-filesystem-validates-initial-files-and-write-modes"
    (let* ((path #P"/tmp/plist.txt")
           (fs (make-test-filesystem :initial-files (list path "plist"))))
      (expect (filesystem-read-file fs path) :to-equal "plist"))
    (signals error
      (make-test-filesystem :initial-files (quote (:bad))))
    ;; %NORMALIZE-TEST-FILES-CPS only dispatches to %NORMALIZE-ALIST-PAIRS-CPS
    ;; once every element already satisfies CONSP, so no public entry point can
    ;; reach %SPLIT-TEST-FILE-BINDING-CPS's own defensive non-cons check; call
    ;; the private helper directly to exercise it.
    (expect (lambda ()
              (cl-boundary-kit::%split-test-file-binding-cps
               :bad (lambda (path content) (declare (ignore path content)))))
            :to-throw "INITIAL-FILES entry must be a cons")
    (signals error
      (filesystem-read-file (make-test-filesystem) #P"/tmp/missing.txt"))
    (signals error
      (filesystem-store-file (make-test-filesystem)
                             #P"/tmp/missing.txt"
                             "hello"
                             :if-does-not-exist :error))
    (signals error
      (filesystem-store-file (make-test-filesystem :initial-files (list #P"/tmp/unsupported.txt" "old"))
                             #P"/tmp/unsupported.txt"
                             "new"
                             :if-exists :unsupported))
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
      (expect (filesystem-read-file fs path) :to-equal "seed")))

  (it "test-filesystem-copies-written-file-content"
    (let* ((path #P"/tmp/write.txt")
           (content (copy-seq "write"))
           (fs (make-test-filesystem)))
      (filesystem-store-file fs path content)
      (setf (char content 0) #\W)
      (expect (filesystem-read-file fs path) :to-equal "write")))

  (it "test-filesystem-read-file-returns-independent-content"
    (let* ((path #P"/tmp/read.txt")
           (fs (make-test-filesystem :initial-files (list path "read")))
           (read-back (filesystem-read-file fs path)))
      (setf (char read-back 0) #\R)
      (expect (filesystem-read-file fs path) :to-equal "read")))

  (it "test-filesystem-copy-file-does-not-expose-source-content"
    (let* ((source #P"/tmp/source.txt")
           (destination #P"/tmp/destination.txt")
           (fs (make-test-filesystem :initial-files (list source "copy"))))
      (filesystem-copy-file fs source destination)
      (let ((read-back (filesystem-read-file fs destination)))
        (setf (char read-back 0) #\C))
      (expect (filesystem-read-file fs source) :to-equal "copy")
      (expect (filesystem-read-file fs destination) :to-equal "copy")))

  ;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
  ;; double-record every call -- once on the wrapper, once on the delegate's
  ;; own history -- because MAKE-RECORDING-FILESYSTEM copied the delegate's
  ;; already-self-recording read/write/etc. closures verbatim. Only the
  ;; wrapper should record.
  ;; Regression: %SNAPSHOT-RECORDED-CALLS used to only COPY-LIST each call
  ;; plist, leaving a returned :RESULT list (or :ARGUMENTS) shared with the
  ;; boundary's own history. Destructively editing the value the caller
  ;; already holds (here NREVERSE on the returned directory listing) must not
  ;; retroactively corrupt what RECORDING-FILESYSTEM-CALLS reports.
  ;; Regression: :IF-EXISTS :OVERWRITE on MAKE-TEST-FILESYSTEM used to behave
  ;; like :SUPERSEDE (full replacement). Real CL :OVERWRITE opens the file
  ;; positioned at the start without truncating, so bytes beyond the new
  ;; content's length survive; the fake must match so tests written against it
  ;; do not diverge from MAKE-FILESYSTEM in production.
  (it "test-filesystem-overwrite-preserves-trailing-content-like-the-real-filesystem"
    (let* ((path "/tmp/ov.txt")
           (content (copy-seq "hi"))
           (fs (make-test-filesystem :initial-files (list path "hello world"))))
      (expect (filesystem-store-file fs path content :if-exists :overwrite)
              :to-be-truthy)
      (expect content :to-equal "hi")
      (expect (filesystem-read-file fs path) :to-equal "hillo world")))

  (it "test-filesystem-overwrite-replaces-same-length-content"
    (let* ((path "/tmp/overwrite-same.txt")
           (fs (make-test-filesystem :initial-files (list path "hello"))))
      (expect (filesystem-store-file fs path "there" :if-exists :overwrite)
              :to-be-truthy)
      (expect (filesystem-read-file fs path) :to-equal "there")))

  (it "test-filesystem-overwrite-replaces-with-longer-content"
    (let* ((path "/tmp/overwrite-long.txt")
           (fs (make-test-filesystem :initial-files (list path "short"))))
      (expect (filesystem-store-file fs path "a longer replacement" :if-exists :overwrite)
              :to-be-truthy)
      (expect (filesystem-read-file fs path) :to-equal "a longer replacement")))

  (it "test-filesystem-overwrite-handles-large-existing-content"
    (let* ((path "/tmp/overwrite-large.txt")
           (existing (make-string (* 16 1024) :initial-element (code-char 97)))
           (fs (make-test-filesystem :initial-files (list path existing))))
      (expect (filesystem-store-file fs path "xy" :if-exists :overwrite)
              :to-be-truthy)
      (let ((read-back (filesystem-read-file fs path)))
        (expect read-back :to-have-length (length existing))
        (expect (char read-back 0) :to-be (code-char 120))
        (expect (char read-back 1) :to-be (code-char 121))
        (expect (char read-back (1- (length read-back))) :to-be (code-char 97))))))

(describe "filesystem line and append operations"
  (it "test-filesystem-read-file-lines-splits-content-with-read-line-semantics"
    (let ((fs (make-test-filesystem
               :initial-files (list (cons #P"a.txt" (format nil "one~%two~%three"))
                                    (cons #P"b.txt" (format nil "trailing~%"))
                                    (cons #P"empty.txt" "")))))
      (expect (filesystem-read-file-lines fs #P"a.txt") :to-equal (list "one" "two" "three"))
      ;; A trailing newline does not yield a final empty line.
      (expect (filesystem-read-file-lines fs #P"b.txt") :to-equal (list "trailing"))
      (expect (filesystem-read-file-lines fs #P"empty.txt") :to-be-null)))

  (it "recording-filesystem-read-file-lines-records-the-underlying-read"
    (let ((fs (make-recording-filesystem
               :delegate (make-test-filesystem
                          :initial-files (list (cons #P"a.txt" (format nil "x~%y")))))))
      (expect (filesystem-read-file-lines fs #P"a.txt") :to-equal (list "x" "y"))
      (expect (recording-filesystem-calls fs) :to-have-recorded-operations (list :read-file))))

  (it "filesystem-store-file-lines-round-trips-with-read-file-lines"
    (let ((fs (make-test-filesystem)))
      (filesystem-store-file-lines fs #P"out.txt" (list "one" "two" "three"))
      (expect (filesystem-read-file fs #P"out.txt") :to-equal (format nil "one~%two~%three~%"))
      (expect (filesystem-read-file-lines fs #P"out.txt") :to-equal (list "one" "two" "three"))))

  (it "filesystem-store-file-lines-forwards-write-options-and-records-the-write"
    (let ((fs (make-recording-filesystem :delegate (make-test-filesystem))))
      (filesystem-store-file-lines fs #P"out.txt" (list "x") :if-exists :supersede)
      (expect (recording-filesystem-calls fs) :to-have-recorded-operations (list :write-file))))

  (it "filesystem-store-file-lines-rejects-non-string-lines"
    (signals error
      (filesystem-store-file-lines (make-test-filesystem) #P"out.txt" (list 42))))

  (it "filesystem-append-file-creates-then-appends"
    (let ((fs (make-test-filesystem)))
      ;; Appends to a file that does not exist yet -> creates it.
      (filesystem-append-file fs #P"log.txt" "first")
      (expect (filesystem-read-file fs #P"log.txt") :to-equal "first")
      ;; A second append extends the existing content.
      (filesystem-append-file fs #P"log.txt" "-second")
      (expect (filesystem-read-file fs #P"log.txt") :to-equal "first-second")))

  (it "filesystem-append-file-records-the-write-with-append-options"
    (let ((fs (make-recording-filesystem :delegate (make-test-filesystem))))
      (filesystem-append-file fs #P"log.txt" "x")
      (assert-recorded-calls
       fs
       (list (boundary-call-plist
              :write-file
              (list #P"log.txt" :content "x"
                    :if-exists :append :if-does-not-exist :create :external-format nil)
              :result t))))))

(describe "filesystem argument validation"
  (it "make-filesystem-rejects-non-function-collaborators"
    (dolist (case '((:read-file-fn :bad)
                    (:write-file-fn :bad)
                    (:probe-file-fn :bad)
                    (:list-directory-fn :bad)
                    (:path-exists-p-fn :bad)))
      (signals error
        (apply #'make-filesystem case))))

  ;; Regression: FILESYSTEM-STORE-FILE's unknown-option check used PLIST-REMOVE-KEYS,
  ;; which pushed VALUE before KEY and so returned keys/values transposed. The
  ;; error message must report the actual offending option as a valid plist.
  (it "filesystem-store-file-reports-unknown-options-as-a-valid-plist"
    (expect (lambda () (filesystem-store-file (make-filesystem) #P"/tmp/x.txt" "content" :bogus 1)) :to-throw "(:BOGUS 1)"))

  (it "filesystem-store-file-rejects-an-odd-length-option-list"
    (let ((filesystem (make-test-filesystem)))
      (expect (lambda () (filesystem-store-file filesystem "/tmp/f.txt" "data" :if-exists)) :to-throw "Option list ended after")))

  (it "filesystem-store-file-rejects-unknown-write-options"
    (let ((filesystem (make-test-filesystem)))
      (expect (lambda () (filesystem-store-file filesystem "/tmp/f.txt" "data" :bogus 1)) :to-throw "Unknown filesystem write options")))

  (it "recording-filesystem-calls-rejects-a-non-filesystem-argument"
    (expect (lambda () (recording-filesystem-calls 42)) :to-throw "must be a filesystem")
    (expect (lambda () (recording-filesystem-calls nil)) :to-throw "must be a filesystem"))

  (it "filesystem-read-file-rejects-a-list-without-a-type"
    (expect (lambda () (filesystem-read-file '() #P"/tmp/x.txt")) :to-throw "FILESYSTEM must be a filesystem"))

  (it "filesystem-store-file-lines-rejects-non-list-lines"
      (expect (lambda () (filesystem-store-file-lines (make-test-filesystem) "/tmp/x.txt" 42)) :to-throw "lines must be a list of strings")))

(describe "recording filesystem and temp-path sources"
  (it "custom-filesystem-collaborators-run-without-recording"
      (let ((filesystem
              (make-filesystem
               :read-file-fn (lambda (path &key external-format)
                               (declare (ignore path external-format))
                               "custom"))))
        (expect (filesystem-read-file filesystem #P"/unreadable/path.txt") :to-equal "custom")))

  (it "reset-recording-filesystem-calls-clears-test-filesystem-history"
      (let ((filesystem (make-test-filesystem :initial-files (list #P"entry.txt" "value"))))
        (filesystem-read-file filesystem #P"entry.txt")
        (expect (recording-filesystem-calls filesystem) :to-have-length 1)
        (expect (reset-recording-filesystem-calls filesystem) :to-be filesystem)
        (assert-no-recorded-calls filesystem)))

  (it "recording-temp-path-source-does-not-record-a-failed-delegate-call"
      (let ((source (make-recording-temp-path-source
                     :delegate (make-test-temp-path-source))))
        (signals error
          (temp-path-next source))
        (expect (recording-temp-path-source-calls source) :to-be-null)))

  (it "test-temp-path-source-normalizes-a-string-path-without-touching-the-filesystem"
      (let ((source (make-test-temp-path-source :paths (list "/virtual/result.tmp"))))
        (expect (temp-path-next source) :to-equal #P"/virtual/result.tmp"))))
