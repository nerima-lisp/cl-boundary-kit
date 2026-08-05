;;;; t/package.lisp
(defpackage #:cl-boundary-kit/test (:use #:cl #:cl-boundary-kit)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from
    #:cl-weave
    #:expect
    #:it
    #:it-each
    #:it-property
    #:defmatcher
    #:benchmark
    #:benchmark-result-samples
    #:gen-integer
    #:gen-list
    #:gen-keyword
    #:gen-string
    #:gen-member
    #:run-all
    #:signals
    #:with-soft-assertions
    #:before-each
    #:after-each
    #:before-all
    #:after-all)
  (:export #:run-tests))

(in-package #:cl-boundary-kit/test)

(defparameter *repository-root*
  ;; Prefer ASDF's record of where cl-boundary-kit.asd lives: it is stable
  ;; regardless of whether the test sources are loaded directly (ci-runner)
  ;; or compiled through the ASDF fasl cache (run-tests.lisp).  Falling back
  ;; to *load-truename* would resolve against the fasl cache directory under
  ;; asdf:load-system and break every example/README path lookup.
  (or (ignore-errors (asdf:system-source-directory "cl-boundary-kit"))
      (merge-pathnames
       #P"../"
       (make-pathname :name nil
                      :type nil
                      :defaults (or *load-truename*
                                    *compile-file-truename*
                                    (error "Unable to determine repository root from test package load path"))))))

(defun repository-root ()
  *repository-root*)

(defun repository-pathname (relative-path)
  (merge-pathnames relative-path (repository-root)))

(defmacro signals-unsupported-boundary-operation ((operation detail) form &body body)
  `(handler-case (progn
      ,form
      (error "Expected unsupported-boundary-operation"))
    (unsupported-boundary-operation (condition)
      (expect
        (eq (unsupported-boundary-operation-operation condition) ',operation)
        :to-be-truthy)
      (expect
        (string= (unsupported-boundary-operation-detail condition) ,detail)
        :to-be-truthy)
      ,@body)))

(defun prolog-special-symbol (name)
  (multiple-value-bind (symbol status) (find-symbol name '#:cl-prolog)
    (when (and status (boundp symbol))
      symbol)))

(defun first-prolog-special-binding-or-nil (bindings)
  (dolist (binding bindings (values nil nil))
    (let ((symbol (prolog-special-symbol (first binding))))
      (when symbol
        (return (values symbol (second binding)))))))

(defmacro with-optional-prolog-special ((name value) &body body)
  `(let ((symbol (prolog-special-symbol ,name)))
    (if symbol (progv (list symbol) (list ,value) ,@body)
      (expect (null symbol) :to-be-truthy))))

(defmacro with-optional-first-prolog-special (bindings &body body)
  `(multiple-value-bind (symbol value) (first-prolog-special-binding-or-nil
      (list
        ,@(mapcar
          (lambda (binding)
            `(list ,(first binding) ,(second binding)))
          bindings)))
    (if symbol (progv (list symbol) (list value) ,@body)
      (expect (null symbol) :to-be-truthy))))

(define-condition expected-prolog-parser-resource-error-not-signalled (error)
  ())

(defun prolog-parser-resource-error-symbol ()
  (multiple-value-bind (symbol status) (find-symbol "PROLOG-PARSER-RESOURCE-ERROR" '#:cl-prolog)
    (when status
      symbol)))

(defun prolog-parser-resource-error-p (condition)
  (let ((symbol (prolog-parser-resource-error-symbol)))
    (or (null symbol) (typep condition symbol))))

(defun assert-prolog-parser-resource-error (condition)
  (unless (prolog-parser-resource-error-p condition)
    (error condition))
  condition)

(defun prolog-parser-resource-error-accessor-value (name condition)
  (multiple-value-bind (symbol status) (find-symbol name '#:cl-prolog)
    (when (and status (fboundp symbol))
      (funcall (symbol-function symbol) condition))))

(defun prolog-parser-resource-error-limit-value (condition)
  (prolog-parser-resource-error-accessor-value
    "PROLOG-PARSER-RESOURCE-ERROR-LIMIT"
    condition))

(defun prolog-parser-resource-error-resource-value (condition)
  (prolog-parser-resource-error-accessor-value
    "PROLOG-PARSER-RESOURCE-ERROR-RESOURCE"
    condition))

(defmacro with-prolog-parser-resource-error ((condition) form &body body)
  `(handler-case (progn
      ,form
      (error 'expected-prolog-parser-resource-error-not-signalled))
    (expected-prolog-parser-resource-error-not-signalled ()
      (error "Expected Prolog parser resource error"))
    (error (,condition)
      (assert-prolog-parser-resource-error ,condition)
      ,@body)))

(defun prolog-condition-symbol (name)
  (multiple-value-bind (symbol status) (find-symbol name '#:cl-prolog)
    (when status
      symbol)))

(defun prolog-condition-p (condition name)
  (let ((symbol (prolog-condition-symbol name)))
    (and symbol (typep condition symbol))))

(defun prolog-error-message-contains-p (condition needle)
  (not (null (search needle (princ-to-string condition)))))

(defun run-tests ()
  (unless (readme-testing-child-process-p)
    (unless (run-all :reporter :spec)
      (error "cl-boundary-kit test suite failed")))
  ;; The README smoke test calls this function in a marked child process.
  ;; The outer suite has already run every test, so avoid re-entering it there.
  (format t "~&cl-boundary-kit/test: successful completion with 0 failures~%")
  t)
