;;;; src/filesystem-fakes-entries.lisp

(in-package #:cl-boundary-kit)

(defstruct (%filesystem-entry (:constructor %make-filesystem-entry (path-name content))
                              (:conc-name %filesystem-entry-))
  path-name
  content)

(defun %copy-test-file-content (content)
  (if (stringp content)
      (copy-seq content)
      content))

(defun %filesystem-entry-for-path (files path)
  (gethash path files))

(defun %set-filesystem-entry-in (files directory-counts path content)
  (multiple-value-bind (existing-entry present-p) (gethash path files)
    (declare (ignore existing-entry))
    (unless present-p
      (%adjust-test-directory-counts directory-counts path 1)))
  (setf (gethash path files)
        (%make-filesystem-entry (namestring (pathname path))
                                (%copy-test-file-content content)))
  content)

(defun %directory-path-prefix (directory)
  (let* ((directory-name (namestring (pathname directory))))
    (if (or (zerop (length directory-name))
            (char= (char directory-name (1- (length directory-name))) #\/))
        directory-name
        (concatenate 'string directory-name "/"))))

(defun %sorted-test-directory-entries-in (files directory)
  ;; Sort explicitly so tests do not depend on implementation-specific hash
  ;; table traversal order.
  (let* ((prefix (%directory-path-prefix directory))
         (prefix-length (length prefix))
         (entries nil))
    (maphash (lambda (path entry)
               (let ((path-name (%filesystem-entry-path-name entry)))
                 (when (and (<= prefix-length (length path-name))
                            (string= prefix path-name :end2 prefix-length))
                   (push (cons path path-name) entries))))
             files)
    (let ((sorted-entries (sort entries #'string< :key #'cdr)))
      (loop for tail on sorted-entries
            do (setf (car tail) (caar tail)))
      sorted-entries)))
