;;;; src/filesystem-fakes-normalize.lisp
;;;;
;;;; The continuation-passing normalizer that coerces a NIL, alist, or plist
;;;; input into (key . value) pairs -- shared by every seeded fake, so the
;;;; filesystem, key/value, cache, secret, and environment doubles all accept
;;;; the same two input shapes and report a malformed one the same way -- plus
;;;; the directory-occupancy counts that let the fake filesystem answer "does
;;;; this directory hold files?" without scanning every entry.

(in-package #:cl-boundary-kit)

(defun %split-pair-binding-cps (binding label continuation)
  (cond
    ((consp binding)
     (funcall continuation (car binding) (cdr binding)))
    (t
     (error "~A entry must be a cons: ~S" label binding))))

(defun %collect-pairs-cps (source-cps continuation)
  (let ((pairs '()))
    (funcall source-cps
             (lambda (key value)
               (push (cons key value) pairs)))
    (funcall continuation (nreverse pairs))))

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

(defun %normalize-alist-pairs-cps (input label continuation)
  (%collect-pairs-cps
   (lambda (sink)
     (dolist (binding input)
       (%split-pair-binding-cps
        binding
        label
        (lambda (key value)
          (funcall sink key value)))))
   continuation))

(defun %normalize-plist-pairs-cps (input continuation)
  (%collect-pairs-cps
   (lambda (sink)
     (loop for (key value) on input by #'cddr
           do (funcall sink key value)))
   continuation))

(defun %normalize-pairs-cps (input label continuation)
  "Pass INPUT -- NIL, an alist, or a plist -- to CONTINUATION as a list of
(key . value) pairs. LABEL names the input in the malformed-input error."
  (cond
    ((null input)
     (funcall continuation '()))
    ((every #'consp input)
     (%normalize-alist-pairs-cps input label continuation))
    ((evenp (length input))
     (%normalize-plist-pairs-cps input continuation))
    (t
     (error "~A must be an alist or plist: ~S" label input))))

(defun %normalize-test-files-cps (initial-files continuation)
  (%normalize-pairs-cps initial-files "INITIAL-FILES" continuation))

(defun %split-test-file-binding-cps (binding continuation)
  (%split-pair-binding-cps binding "INITIAL-FILES" continuation))
