;;;; t/test-macros.lisp
;;;;
;;;; Shared IT-case generators for regression-test shapes repeated across many
;;;; boundary test files, kept apart from MATCHERS.LISP's cl-weave matcher
;;;; registrations since these define whole test cases rather than assertion
;;;; vocabulary.

(in-package #:cl-boundary-kit/test)

(defmacro deftest-reset-recording-clears-history
    (name (var make-form) (calls-fn reset-fn) &body trigger-forms)
  "Define an IT case named NAME asserting the standard reset-recording-*-calls
contract shared by every recording boundary: after TRIGGER-FORMS run against
VAR (bound to MAKE-FORM) and record one call, CALLS-FN reports a single
recorded call, RESET-FN clears the history and returns VAR unchanged, and
CALLS-FN is empty afterward."
  `(it ,name
     (let ((,var ,make-form))
       ,@trigger-forms
       (with-soft-assertions
         (expect (= 1 (length (,calls-fn ,var))) :to-be-truthy)
         (expect (eq ,var (,reset-fn ,var)) :to-be-truthy)
         (expect (null (,calls-fn ,var)) :to-be-truthy)))))
