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
      ((:supersede :overwrite :create nil)
       content)
      (:error
       (error "Test filesystem refuses to overwrite existing file ~S" path))
      (otherwise
       (unsupported-operation
        'filesystem-write-file
        (format nil "test filesystem does not implement :IF-EXISTS ~S" mode))))))

(defun %record-test-filesystem-call (call-box operation arguments result)
  (%record-call (car call-box)
    :operation operation
    :arguments arguments
    :result result)
  result)

(defmacro define-test-filesystem-operation-fn (name lambda-list operation arguments-form &body body)
  `(defun ,name (files call-box)
     (lambda ,lambda-list
       (let ((result (progn ,@body)))
         (%record-test-filesystem-call call-box ,operation ,arguments-form result)
         result))))

(define-test-filesystem-operation-fn %make-test-filesystem-read-fn
    (path &key external-format)
  :read-file
  (list path :external-format external-format)
  (let ((entry (%filesystem-entry-for-path files path)))
    (unless entry
      (error "Test filesystem cannot read missing file ~S" path))
    (%filesystem-entry-content entry)))

(define-test-filesystem-operation-fn %make-test-filesystem-write-fn
    (path content &key if-exists if-does-not-exist external-format)
  :write-file
  (list path
        :content content
        :if-exists if-exists
        :if-does-not-exist if-does-not-exist
        :external-format external-format)
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
  :probe-file
  (list path)
  (and (%filesystem-entry-for-path files path)
       (pathname path)))

(define-test-filesystem-operation-fn %make-test-filesystem-list-directory-fn
    (directory)
  :list-directory
  (list directory)
  (%sorted-test-directory-entries-in files directory))

(define-test-filesystem-operation-fn %make-test-filesystem-path-exists-p-fn
    (path)
  :path-exists-p
  (list path)
  (not (null (%filesystem-entry-for-path files path))))

(defun %seed-test-filesystem-files (files initial-files)
  (%normalize-test-files-cps
   initial-files
   (lambda (bindings)
     (dolist (binding bindings)
       (%set-filesystem-entry-in files (car binding) (cdr binding))))))

(defun %instantiate-test-filesystem (files call-box)
  (%make-filesystem-data
   +test-filesystem-type+
   :files files
   :calls call-box
   :read-file-fn (%make-test-filesystem-read-fn files call-box)
   :write-file-fn (%make-test-filesystem-write-fn files call-box)
   :probe-file-fn (%make-test-filesystem-probe-fn files call-box)
   :list-directory-fn (%make-test-filesystem-list-directory-fn files call-box)
   :path-exists-p-fn (%make-test-filesystem-path-exists-p-fn files call-box)))

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
  (let ((prefix (%directory-path-prefix directory))
        (entries nil))
    (maphash (lambda (path entry)
               (declare (ignore entry))
               (let ((path-name (namestring (pathname path))))
                 (when (and (<= (length prefix) (length path-name))
                            (string= prefix path-name :end2 (length prefix)))
                   (push path entries))))
             files)
    (sort entries #'string< :key (lambda (path) (namestring (pathname path))))))
