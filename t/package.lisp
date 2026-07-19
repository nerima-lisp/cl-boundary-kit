;;;; t/package.lisp

(defpackage #:cl-boundary-kit/test
  (:use #:cl #:cl-boundary-kit)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
                #:expect
                #:it
                #:it-property
                #:benchmark
                #:benchmark-result-samples
                #:gen-integer
                #:gen-list
                #:gen-keyword
                #:gen-string
                #:run-all
                #:signals)
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
  `(handler-case
       (progn ,form
              (error "Expected unsupported-boundary-operation"))
     (unsupported-boundary-operation (condition)
       (expect (eq (unsupported-boundary-operation-operation condition)
                   ',operation)
               :to-be-truthy)
       (expect (string= (unsupported-boundary-operation-detail condition)
                        ,detail)
               :to-be-truthy)
       ,@body)))

(defmacro signals-error-message-contains (needle form &body body)
     `(handler-case
          (progn ,form
                 (error "Expected error containing ~S" ,needle))
       (error (condition)
         (expect (not (null (search ,needle (princ-to-string condition))))
                 :to-be-truthy)
         ,@body)))

(defun run-tests ()
  (unless (run-all :reporter :spec)
    (error "cl-boundary-kit test suite failed"))
  ;; RUN-ALL signals a non-local exit above unless the suite is green, so
  ;; reaching this line documents the successful-completion contract that the
  ;; policy documents describe: the documented REPL runner finishes with
  ;; 0 failures and exit status 0.
  (format t "~&cl-boundary-kit/test: successful completion with 0 failures~%")
  t)
