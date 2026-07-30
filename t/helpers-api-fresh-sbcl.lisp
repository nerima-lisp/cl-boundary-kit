;;;; t/helpers-api-fresh-sbcl.lisp

(in-package #:cl-boundary-kit/test)

(defparameter +fresh-sbcl-timeout+ 600
  "Allow the documented REPL runner to complete its full test suite in a fresh SBCL process.")

(defun run-lisp-forms-in-fresh-sbcl (forms)
  (let* ((sbcl-program (namestring sb-ext:*runtime-pathname*))
         (script (format nil "(require :asdf)~%(pushnew :cl-boundary-kit-verify-readme-testing *features*)~%~{~A~%~}~%(uiop:quit 0)~%"
                         forms)))
    (uiop:with-temporary-file (:stream stream
                               :pathname script-path
                               :directory (uiop:temporary-directory)
                               :prefix "cl-boundary-kit-readme-test-"
                               :suffix ".lisp"
                               :direction :output)
      (write-string script stream)
      :close-stream
      (uiop:run-program (list sbcl-program "--script" (namestring script-path))
                        :directory (repository-root)
                        :output :string
                        :error-output :string
                        :ignore-error-status t
                        :timeout +fresh-sbcl-timeout+))))

(defmacro define-fresh-sbcl-case-markers (&rest cases)
  `(progn
     ,@(loop for (function-name marker-name) in cases
             collect
             `(defun ,function-name (name)
                (format nil ,(concatenate 'string "@@CASE-" marker-name " ~A@@")
                        name)))))

(define-fresh-sbcl-case-markers
  (fresh-sbcl-case-begin-marker "BEGIN")
  (fresh-sbcl-case-pass-marker "PASS")
  (fresh-sbcl-case-fail-marker "FAIL")
  (fresh-sbcl-case-end-marker "END"))

(defmacro define-fresh-sbcl-snippet-helpers (&rest helpers)
  `(progn
     ,@(loop for (function-name body) in helpers
             collect
             `(defun ,function-name ()
                ,body))))

(defun documentation-fresh-sbcl-cookbook-lines (start-section end-section)
  (append
   (documentation-fresh-sbcl-installation-lines)
   (string-lines
    (single-document-fenced-code-block "docs/src/cookbook.md"
                                       start-section
                                       end-section
                                       "lisp"))))

(define-fresh-sbcl-snippet-helpers
  (documentation-fresh-sbcl-installation-lines
   (string-lines (checkout-installation-snippet)))
  (documentation-fresh-sbcl-installation-and-quick-start-lines
   (append
    (documentation-fresh-sbcl-installation-lines)
    (string-lines (nth 0 (document-fenced-code-blocks
                          "docs/src/quick-start.md" "# Quick Start" nil "lisp")))
    (string-lines (nth 1 (document-fenced-code-blocks
                          "docs/src/quick-start.md" "# Quick Start" nil "lisp")))))
  (documentation-fresh-sbcl-testing-repl-lines
   (string-lines
    (replace-substring
     (first (document-fenced-code-blocks
             "docs/src/testing.md" "# Running the Test Suite" nil "lisp"))
     "/path/to/cl-boundary-kit/"
     (namestring (repository-root)))))
  (documentation-fresh-sbcl-contributing-installation-lines
   (string-lines
    (replace-substring
     (nth-document-fenced-code-block "docs/src/contributing.md"
                                     "## Local Setup"
                                     "## Change Guidelines"
                                     "lisp"
                                     0)
     "/path/to/cl-boundary-kit/"
     (namestring (repository-root)))))
  (documentation-fresh-sbcl-cookbook-compose-boundaries-lines
   (documentation-fresh-sbcl-cookbook-lines
    "## Compose Boundaries At The Application Edge"
    "## Assert On Recorded Boundary Calls"))
  (documentation-fresh-sbcl-cookbook-recorded-boundary-lines
   (documentation-fresh-sbcl-cookbook-lines
    "## Assert On Recorded Boundary Calls"
    "## Handle Unsupported Operations Explicitly"))
  (documentation-fresh-sbcl-cookbook-unsupported-operation-lines
   (documentation-fresh-sbcl-cookbook-lines
    "## Handle Unsupported Operations Explicitly"
    nil)))

(defmacro define-documentation-fresh-sbcl-form-groups (&rest groups)
  `(defun documentation-fresh-sbcl-form-groups ()
     (list
      ,@(loop for (name helper) in groups
              collect `(cons ,name (,helper))))))

(define-documentation-fresh-sbcl-form-groups
  ("readme-installation" documentation-fresh-sbcl-installation-lines)
  ("readme-installation-and-quick-start" documentation-fresh-sbcl-installation-and-quick-start-lines)
  ("readme-testing-repl" documentation-fresh-sbcl-testing-repl-lines)
  ("contributing-installation" documentation-fresh-sbcl-contributing-installation-lines)
  ("cookbook-compose-boundaries" documentation-fresh-sbcl-cookbook-compose-boundaries-lines)
  ("cookbook-recorded-boundary" documentation-fresh-sbcl-cookbook-recorded-boundary-lines)
  ("cookbook-unsupported-operation" documentation-fresh-sbcl-cookbook-unsupported-operation-lines))

(defun wrap-fresh-sbcl-form-group (name forms)
  (append
   (list (format nil "(format t \"~A~%%\")" (fresh-sbcl-case-begin-marker name))
         "(handler-case"
         "    (progn")
   forms
   (list (format nil "      (format t \"~A~%%\"))" (fresh-sbcl-case-pass-marker name))
         (format nil "  (error (e)~%    (setf *fresh-sbcl-batch-failures* t)~%    (format t \"~~A ~~A~~%%\" ~S e)))"
                 (fresh-sbcl-case-fail-marker name))
         (format nil "(format t \"~A~%%\")" (fresh-sbcl-case-end-marker name)))))

(defun run-lisp-form-groups-in-fresh-sbcl (groups)
  ;; Load the test system as a standalone top-level form before any group form
  ;; is READ.  The documented README testing snippet references
  ;; CL-BOUNDARY-KIT/TEST:RUN-TESTS, and because --script READs each whole
  ;; top-level (handler-case ...) group form before evaluating it, that package
  ;; must already exist or the READ itself aborts the child and cascades
  ;; failures to every later group.  The child inherits CL_SOURCE_REGISTRY, so
  ;; ASDF can locate the system here.
  (let ((forms (quote ("(defparameter *fresh-sbcl-batch-failures* nil)"
                       "(asdf:load-system :cl-boundary-kit/test)"))))
    (dolist (group groups)
      (setf forms
            (append forms
                    (wrap-fresh-sbcl-form-group (car group) (cdr group)))))
    (run-lisp-forms-in-fresh-sbcl
     (append forms
             (quote ("(uiop:quit (if *fresh-sbcl-batch-failures* 1 0))"))))))

(defun fresh-sbcl-case-output (stdout name)
  (let* ((begin-marker (fresh-sbcl-case-begin-marker name))
         (end-marker (fresh-sbcl-case-end-marker name))
         (begin (search begin-marker stdout))
         (start (and begin (+ begin (length begin-marker))))
         (end (and start (search end-marker stdout :start2 start))))
    (and start end
         (subseq stdout start end))))

(defvar *documentation-fresh-sbcl-batch-result* nil)

(defun documentation-fresh-sbcl-batch-result ()
  (or *documentation-fresh-sbcl-batch-result*
      (setf *documentation-fresh-sbcl-batch-result*
            (multiple-value-list
             (run-lisp-form-groups-in-fresh-sbcl
              (documentation-fresh-sbcl-form-groups))))))

(defun documentation-fresh-sbcl-case-output (name)
  (fresh-sbcl-case-output
   (first (documentation-fresh-sbcl-batch-result))
   name))

(defmacro define-documentation-fresh-sbcl-tests (&rest cases)
  `(progn
     ,@(loop for case in cases
             collect
             (destructuring-bind (test-name case-name &key expected forbidden)
                 case
               `(it ,(string-downcase (string test-name))
                  (unless (readme-testing-child-process-p)
                    (let ((case-output (documentation-fresh-sbcl-case-output ,case-name)))
                      (expect (not (null case-output)) :to-be-truthy)
                      (expect (contains-string-p
                           (fresh-sbcl-case-pass-marker ,case-name)
                           case-output) :to-be-truthy)
                      ,@(loop for needle in expected
                              collect `(expect (contains-string-p ,needle case-output) :to-be-truthy))
                      ,@(loop for needle in forbidden
                              collect `(expect (null (search ,needle case-output)) :to-be-truthy)))))))))
