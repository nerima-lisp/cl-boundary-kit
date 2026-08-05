;;;; t/helpers-matchers.lisp
;;;;
;;;; Domain-specific cl-weave matchers for cl-boundary-kit's tests. Registering
;;;; these with DEFMATCHER / EXTEND-EXPECT lets boundary tests assert in the
;;;; library's own vocabulary -- "these calls recorded these operations" -- and,
;;;; because a matcher returns structured (pass-p actual-detail expected-detail)
;;;; values, a failure reports the operation list it actually saw instead of a
;;;; bare NIL. Message-substring assertions need no matcher here: cl-weave's
;;;; built-in :TO-THROW already takes a substring, a condition class, or a
;;;; predicate.

(in-package #:cl-boundary-kit/test)

(defmatcher :to-have-recorded-operations (calls expected)
  "Passes when CALLS -- a list of recorded-call plists -- carries exactly the
matcher's operation-keyword list as its :OPERATION values, in recorded order."
  (destructuring-bind (expected-operations) expected
    (let ((operations (mapcar (lambda (call) (getf call :operation)) calls)))
      (values (equal operations expected-operations)
              `(:operations ,operations)
              `(:operations ,expected-operations)))))

(defmatcher :to-have-recorded-calls (calls expected)
  "Passes when CALLS -- the recorded-call plist list a recording boundary hands
back -- is EQUAL to the matcher's expected call-plist list, element for element
and in recorded order."
  (destructuring-bind (expected-calls) expected
    (values (equal calls expected-calls)
            `(:calls ,calls)
            `(:calls ,expected-calls))))
