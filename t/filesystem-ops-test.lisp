;;;; t/filesystem-ops-test.lisp
;;;;
;;;; Filesystem delete/copy/rename/directory operation tests, split out of
;;;; filesystem-test.lisp.

(in-package #:cl-boundary-kit/test)

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

(it "make-filesystem-delete-file-signals-a-real-failure-instead-of-swallowing-it"
  (let ((directory (uiop:ensure-directory-pathname
                    (merge-pathnames "cl-boundary-kit-delete-error-test/" (uiop:temporary-directory)))))
    (ensure-directories-exist directory)
    (unwind-protect
         (let ((fs (make-filesystem)))
           ;; DELETE-FILE rejects a directory pathname (it is not a regular
           ;; file), but PROBE-FILE still finds it -- the "still exists"
           ;; branch that must re-signal instead of reporting NIL, since a
           ;; NIL result is reserved for "was already absent."
           (signals file-error
             (filesystem-delete-file fs directory)))
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
