;;;; src/filesystem-fakes-helpers.lisp

(in-package #:cl-boundary-kit)

(defun %split-test-file-binding-cps (binding continuation)
  (cond
    ((consp binding)
     (funcall continuation (car binding) (cdr binding)))
    (t
     (error "INITIAL-FILES entry must be a cons: ~S" binding))))

(defun %collect-test-files-bindings-cps (source-cps continuation)
  (let ((bindings '()))
    (funcall source-cps
             (lambda (path content)
               (push (cons path content) bindings)))
    (funcall continuation (nreverse bindings))))

(defun %normalize-test-files-alist-cps (initial-files continuation)
  (%collect-test-files-bindings-cps
   (lambda (sink)
     (dolist (binding initial-files)
       (%split-test-file-binding-cps
        binding
        (lambda (path content)
          (funcall sink path content)))))
   continuation))

(defun %normalize-test-files-plist-cps (initial-files continuation)
  (%collect-test-files-bindings-cps
   (lambda (sink)
     (loop for (path content) on initial-files by #'cddr
           do (funcall sink path content)))
   continuation))

(defun %normalize-test-files-cps (initial-files continuation)
  (cond
    ((null initial-files)
     (funcall continuation '()))
    ((every #'consp initial-files)
     (%normalize-test-files-alist-cps initial-files continuation))
    ((evenp (length initial-files))
     (%normalize-test-files-plist-cps initial-files continuation))
    (t
     (error "INITIAL-FILES must be an alist or plist: ~S" initial-files))))

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
       (let ((existing (%filesystem-entry-content entry)))
         (if (> (length existing) (length content))
             (concatenate 'string content (subseq existing (length content)))
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
  `(defun ,name (files)
     (lambda ,lambda-list
       ,@body)))

(define-test-filesystem-operation-fn %make-test-filesystem-read-fn
    (path &key external-format)
  (declare (ignore external-format))
  (let ((entry (%filesystem-entry-for-path files path)))
    (unless entry
      (error "Test filesystem cannot read missing file ~S" path))
    (%filesystem-entry-content entry)))

(define-test-filesystem-operation-fn %make-test-filesystem-write-fn
    (path content &key if-exists if-does-not-exist external-format)
  (declare (ignore external-format))
  (%set-filesystem-entry-in
   files
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
  (remhash path files))

(define-test-filesystem-operation-fn %make-test-filesystem-copy-fn
    (source destination)
  (let ((entry (%filesystem-entry-for-path files source)))
    (unless entry
      (error "Test filesystem cannot copy missing file ~S" source))
    (%set-filesystem-entry-in files destination (%filesystem-entry-content entry))
    destination))

(define-test-filesystem-operation-fn %make-test-filesystem-rename-fn
    (source destination)
  (let ((entry (%filesystem-entry-for-path files source)))
    (unless entry
      (error "Test filesystem cannot rename missing file ~S" source))
    (%set-filesystem-entry-in files destination (%filesystem-entry-content entry))
    (remhash source files)
    destination))

(defun %seed-test-filesystem-files (files initial-files)
  (%normalize-test-files-cps
   initial-files
   (lambda (bindings)
     (dolist (binding bindings)
       (%set-filesystem-entry-in files (car binding) (cdr binding))))))

(defun %test-directory-has-files-p (files directory)
  (let ((prefix (%directory-path-prefix directory)))
    (block scan
      (maphash (lambda (path entry)
                 (declare (ignore entry))
                 (let ((path-name (namestring (pathname path))))
                   (when (and (<= (length prefix) (length path-name))
                              (string= prefix path-name :end2 (length prefix)))
                     (return-from scan t))))
               files)
      nil)))

(defun %make-test-filesystem-make-directory-fn (files directories)
  (declare (ignore files))
  (lambda (path)
    (let ((directory (%directory-path-prefix path)))
      (setf (gethash directory directories) t)
      (pathname directory))))

(defun %make-test-filesystem-directory-exists-p-fn (files directories)
  (lambda (path)
    (let ((directory (%directory-path-prefix path)))
      (or (not (null (gethash directory directories)))
          (%test-directory-has-files-p files path)))))

(defun %make-test-filesystem-delete-directory-fn (files directories)
  (lambda (path)
    (let ((directory (%directory-path-prefix path)))
      (cond
        ((%test-directory-has-files-p files path)
         (error "Test filesystem cannot delete non-empty directory ~S" path))
        ((gethash directory directories)
         (remhash directory directories)
         t)
        (t nil)))))

(defun %instantiate-test-filesystem (files directories call-box)
  (%make-filesystem-data
   +test-filesystem-type+
   :files files
   :calls call-box
   :read-file-fn (%make-test-filesystem-read-fn files)
   :write-file-fn (%make-test-filesystem-write-fn files)
   :probe-file-fn (%make-test-filesystem-probe-fn files)
   :list-directory-fn (%make-test-filesystem-list-directory-fn files)
   :path-exists-p-fn (%make-test-filesystem-path-exists-p-fn files)
   :delete-file-fn (%make-test-filesystem-delete-fn files)
   :copy-file-fn (%make-test-filesystem-copy-fn files)
   :rename-file-fn (%make-test-filesystem-rename-fn files)
   :make-directory-fn (%make-test-filesystem-make-directory-fn files directories)
   :directory-exists-p-fn (%make-test-filesystem-directory-exists-p-fn files directories)
   :delete-directory-fn (%make-test-filesystem-delete-directory-fn files directories)))

(defstruct (%filesystem-entry (:constructor %make-filesystem-entry (in content))
                              (:conc-name %filesystem-entry-))
  in
  content)

(defun %filesystem-entry-for-path (files path)
  (gethash path files))

(defun %set-filesystem-entry-in (files path content)
  (setf (gethash path files)
        (%make-filesystem-entry path content))
  content)

(defun %directory-path-prefix (directory)
  (let* ((directory-name (namestring (pathname directory))))
    (if (or (zerop (length directory-name))
            (char= (char directory-name (1- (length directory-name))) #\/))
        directory-name
        (concatenate 'string directory-name "/"))))

(defun %sorted-test-directory-entries-in (files directory)
  ;; Compute each matching entry's namestring once, here, and carry it
  ;; alongside PATH for the sort key -- SORT's :KEY function can otherwise
  ;; re-run the same PATHNAME/NAMESTRING conversion per comparison rather
  ;; than once per entry.
  (let ((prefix (%directory-path-prefix directory))
        (entries nil))
    (maphash (lambda (path entry)
               (declare (ignore entry))
               (let ((path-name (namestring (pathname path))))
                 (when (and (<= (length prefix) (length path-name))
                            (string= prefix path-name :end2 (length prefix)))
                   (push (cons path path-name) entries))))
             files)
    (mapcar #'car (sort entries #'string< :key #'cdr))))
