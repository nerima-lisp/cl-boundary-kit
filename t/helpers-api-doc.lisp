;;;; t/helpers-api-doc.lisp

(in-package #:cl-boundary-kit/test)

(defun contains-string-p (needle haystack)
  (not (null (search needle haystack))))

(defun assert-contains-all (haystack needles)
  (dolist (needle needles t)
    (expect (contains-string-p needle haystack) :to-be-truthy)))

(defun assert-contains-none (haystack needles)
  (dolist (needle needles t)
    (expect (null (search needle haystack)) :to-be-truthy)))

(defun string-set-difference (left right)
  (let ((present (make-hash-table :test #'equal)))
    (dolist (item right)
      (setf (gethash item present) t))
    (remove-if (lambda (item)
                 (gethash item present))
               left)))

(defmacro assert-string-set-equal (expected actual)
  `(progn
     (expect (null (string-set-difference ,expected ,actual)) :to-be-truthy)
     (expect (null (string-set-difference ,actual ,expected)) :to-be-truthy)))

(defun exported-symbol-names ()
  (mapcar #'symbol-name (exported-symbols)))

(defun exported-symbols ()
  (let ((symbols '()))
    (do-external-symbols (symbol :cl-boundary-kit)
      (push symbol symbols))
    symbols))

(defun exported-symbol-documentation-kinds (symbol)
  (let ((kinds '()))
    (when (fboundp symbol)
      (push 'function kinds))
    (when (find-class symbol nil)
      (push 'type kinds))
    (when (boundp symbol)
      (push 'variable kinds))
    (nreverse kinds)))

(defun exported-symbol-documentation-missing-entries ()
  (mapcan (lambda (symbol)
            (unless (exported-symbol-documentation-kinds symbol)
              (list (symbol-name symbol))))
          (exported-symbols)))

(defun repository-file-string (name)
  (uiop:read-file-string (repository-pathname name)))

(defun repository-file-exists-p (name)
  (not (null (probe-file (repository-pathname name)))))

(defun api-test-suite-file-paths ()
  '("t/api-test.lisp"
    "t/api-doc-claims-test.lisp"
    "t/api-doc-claims-foundation-test.lisp"
    "t/api-doc-claims-readme-test.lisp"
    "t/api-doc-links-test.lisp"
    "t/api-doc-links-foundation-test.lisp"
    "t/api-doc-links-documents-test.lisp"
    "t/api-doc-links-readme-test.lisp"
    "t/api-executable-docs-test.lisp"))

(defun api-test-suite-string ()
  (with-output-to-string (out)
    (dolist (path (api-test-suite-file-paths))
      (write-string (repository-file-string path) out)
      (terpri out))))

(defun readme-testing-child-process-p ()
  (not (null (member :cl-boundary-kit-verify-readme-testing *features*))))

(defun checkout-installation-snippet ()
  (replace-substring
   (single-document-fenced-code-block "docs/src/installation.md" "# Installation" "## Nix" "lisp")
   "/path/to/cl-boundary-kit/"
   (namestring (repository-root))))

(defun replace-substring (string target replacement)
  (with-output-to-string (out)
    (loop with start = 0
          for position = (search target string :start2 start)
          do (if position
                 (progn
                   (write-string string out :start start :end position)
                   (write-string replacement out)
                   (setf start (+ position (length target))))
                 (progn
                   (write-string string out :start start)
                   (return))))))

(defun string-lines (string)
  (remove-if #'(lambda (line) (string= "" (trimmed-markdown-line line)))
             (split-lines string)))
