;;;; src/filesystem-fakes-helpers.lisp

(in-package #:cl-boundary-kit)

(defun %test-write-mode (entry path if-exists if-does-not-exist)
  (cond
    (entry (or if-exists :supersede))
    ((eq if-does-not-exist :error)
     (error "Test filesystem cannot write missing file ~S with :IF-DOES-NOT-EXIST :ERROR"
            path))
    (t
     :create)))

(defun %resolve-test-write-content (entry path content if-exists if-does-not-exist)
  (let ((mode (%test-write-mode entry path if-exists if-does-not-exist)))
    (case mode
      (:append
       (concatenate 'string (%filesystem-entry-content entry) content))
      (:overwrite
       ;; Real CL :OVERWRITE opens the file positioned at the start without
       ;; truncating, so bytes beyond the new content's length survive from
       ;; the original file; :SUPERSEDE/:CREATE truncate. Match that so
       ;; make-test-filesystem doesn't diverge from make-filesystem here.
       (let* ((existing (%filesystem-entry-content entry))
              (existing-length (length existing))
              (content-length (length content)))
         (if (> existing-length content-length)
             (let ((resolved (make-string existing-length)))
               (replace resolved content)
               (replace resolved existing
                        :start1 content-length
                        :start2 content-length)
               resolved)
             content)))
      ((:supersede :create nil)
       content)
      (:error
       (error "Test filesystem refuses to overwrite existing file ~S" path))
      (otherwise
       (unsupported-operation
        'filesystem-write-file
        (format nil "test filesystem does not implement :IF-EXISTS ~S" mode))))))

(defmacro define-test-filesystem-operation-fn (name lambda-list &body body)
  ;; No recording here: %WITH-RECORDING-FILESYSTEM-CALL applies it externally
  ;; for both :TEST and :RECORDING kinds, so a recording filesystem wrapping
  ;; a test-filesystem delegate can call this raw effect directly (as
  ;; MAKE-RECORDING-FILESYSTEM already copies it verbatim) without
  ;; re-entering the delegate's own recording path and double-recording.
  ;; Every builder takes the same three collaborators so %INSTANTIATE-TEST-
  ;; FILESYSTEM can wire them up uniformly; IGNORABLE lets each one close over
  ;; only the subset it needs without an unused-variable warning.
  `(defun ,name (files directories directory-counts)
     (declare (ignorable files directories directory-counts))
     (lambda ,lambda-list
       ,@body)))

(define-test-filesystem-operation-fn %make-test-filesystem-read-fn
    (path &key external-format)
  (declare (ignore external-format))
  (let ((entry (%filesystem-entry-for-path files path)))
    (unless entry
      (error "Test filesystem cannot read missing file ~S" path))
    (%copy-test-file-content (%filesystem-entry-content entry))))

(define-test-filesystem-operation-fn %make-test-filesystem-write-fn
    (path content &key if-exists if-does-not-exist external-format)
  (declare (ignore external-format))
  (%set-filesystem-entry-in
   files
   directory-counts
   path
   (%resolve-test-write-content
    (%filesystem-entry-for-path files path)
    path
    content
    if-exists
    if-does-not-exist))
  t)

(define-test-filesystem-operation-fn %make-test-filesystem-probe-fn
    (path)
  (and (%filesystem-entry-for-path files path)
       (pathname path)))

(define-test-filesystem-operation-fn %make-test-filesystem-list-directory-fn
    (directory)
  (%sorted-test-directory-entries-in files directory))

(define-test-filesystem-operation-fn %make-test-filesystem-path-exists-p-fn
    (path)
  (not (null (%filesystem-entry-for-path files path))))

(define-test-filesystem-operation-fn %make-test-filesystem-delete-fn
    (path)
  ;; REMHASH returns whether the entry was present, matching the delete
  ;; contract shared with kv-delete and cache-evict.
  (when (remhash path files)
    (%adjust-test-directory-counts directory-counts path -1)
    t))

(define-test-filesystem-operation-fn %make-test-filesystem-copy-fn
    (source destination)
  (when (equal source destination)
    (error "Test filesystem cannot copy file ~S to itself" source))
  (let ((entry (%filesystem-entry-for-path files source)))
    (unless entry
      (error "Test filesystem cannot copy missing file ~S" source))
    (%set-filesystem-entry-in files directory-counts destination (%filesystem-entry-content entry))
    destination))

(define-test-filesystem-operation-fn %make-test-filesystem-rename-fn
    (source destination)
  (when (equal source destination)
    (error "Test filesystem cannot rename file ~S to itself" source))
  (let ((entry (%filesystem-entry-for-path files source)))
    (unless entry
      (error "Test filesystem cannot rename missing file ~S" source))
    (%adjust-test-directory-counts directory-counts source -1)
    (%set-filesystem-entry-in files directory-counts destination (%filesystem-entry-content entry))
    (remhash source files)
    destination))

(defun %seed-test-filesystem-files (files directory-counts initial-files)
  (%normalize-test-files-cps
   initial-files
   (lambda (bindings)
     (dolist (binding bindings)
       (%set-filesystem-entry-in files directory-counts (car binding) (cdr binding))))))

(define-test-filesystem-operation-fn %make-test-filesystem-make-directory-fn
    (path)
  (let ((directory (%directory-path-prefix path)))
    (setf (gethash directory directories) t)
    (pathname directory)))

(define-test-filesystem-operation-fn %make-test-filesystem-directory-exists-p-fn
    (path)
  (let ((directory (%directory-path-prefix path)))
    (or (not (null (gethash directory directories)))
        (%test-directory-has-files-p directory-counts path))))

(define-test-filesystem-operation-fn %make-test-filesystem-delete-directory-fn
    (path)
  (let ((directory (%directory-path-prefix path)))
    (cond
      ((%test-directory-has-files-p directory-counts path)
       (error "Test filesystem cannot delete non-empty directory ~S" path))
      ((gethash directory directories)
       (remhash directory directories)
       t)
      (t nil))))

(defun %instantiate-test-filesystem (files directories directory-counts call-box)
  (%make-filesystem-data
   +test-filesystem-type+
   :files files
   :calls call-box
   :read-file-fn (%make-test-filesystem-read-fn files directories directory-counts)
   :write-file-fn (%make-test-filesystem-write-fn files directories directory-counts)
   :probe-file-fn (%make-test-filesystem-probe-fn files directories directory-counts)
   :list-directory-fn (%make-test-filesystem-list-directory-fn files directories directory-counts)
   :path-exists-p-fn (%make-test-filesystem-path-exists-p-fn files directories directory-counts)
   :delete-file-fn (%make-test-filesystem-delete-fn files directories directory-counts)
   :copy-file-fn (%make-test-filesystem-copy-fn files directories directory-counts)
   :rename-file-fn (%make-test-filesystem-rename-fn files directories directory-counts)
   :make-directory-fn (%make-test-filesystem-make-directory-fn files directories directory-counts)
   :directory-exists-p-fn (%make-test-filesystem-directory-exists-p-fn
                           files directories directory-counts)
   :delete-directory-fn (%make-test-filesystem-delete-directory-fn
                         files directories directory-counts)))
