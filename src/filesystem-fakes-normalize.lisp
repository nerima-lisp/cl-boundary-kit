;;;; src/filesystem-fakes-normalize.lisp
;;;;
;;;; Input normalization for the in-memory test filesystem: coercing seeded
;;;; INITIAL-FILES (alist or plist) into bindings via continuation-passing
;;;; helpers, and maintaining the directory-occupancy counts that let the fake
;;;; answer "does this directory hold files?" without scanning every entry.

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

(defun %make-test-directory-counts ()
  (make-hash-table :test 'equal))

(defun %test-directory-prefixes-for-path (path)
  (let ((namestring (namestring (pathname path)))
        (prefixes '()))
    (loop for end = (position #\/ namestring :from-end t)
          then (and end (position #\/ namestring :from-end t :end end))
          while end
          do (push (subseq namestring 0 (1+ end)) prefixes)
          finally (return (nreverse prefixes)))))

(defun %adjust-test-directory-counts (counts path delta)
  (dolist (prefix (%test-directory-prefixes-for-path path))
    (incf (gethash prefix counts 0) delta)))

(defun %test-directory-has-files-p (counts directory)
  (let ((prefix (%directory-path-prefix directory)))
    (not (zerop (gethash prefix counts 0)))))

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
