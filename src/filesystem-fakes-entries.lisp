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
  (%adjust-test-directory-counts directory-counts path 1)
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
  ;; Compute each matching entry's namestring once, here, and carry it
  ;; alongside PATH for the sort key -- SORT's :KEY function can otherwise
  ;; re-run the same PATHNAME/NAMESTRING conversion per comparison rather
  ;; than once per entry.
  (let ((prefix (%directory-path-prefix directory))
        (entries nil))
    (maphash (lambda (path entry)
               (let ((path-name (%filesystem-entry-path-name entry)))
                 (when (and (<= (length prefix) (length path-name))
                            (string= prefix path-name :end2 (length prefix)))
                   (push (cons path path-name) entries))))
             files)
    (mapcar #'car (sort entries #'string< :key #'cdr))))
