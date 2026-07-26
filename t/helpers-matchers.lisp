;;;; t/helpers-matchers.lisp
;;;;
;;;; Domain-specific cl-weave matchers for cl-boundary-kit's tests. Registering
;;;; these with DEFMATCHER / EXTEND-EXPECT lets boundary tests assert in the
;;;; library's own vocabulary -- "this thunk is rejected with such a message",
;;;; "these calls recorded these operations" -- and, because a matcher returns
;;;; structured (pass-p actual-detail expected-detail) values, a failure reports
;;;; the message or operation list it actually saw instead of a bare NIL.

(in-package #:cl-boundary-kit/test)

(defmatcher :to-signal-message-containing (thunk expected)
  "Passes when funcalling THUNK signals an ERROR whose printed report contains
the substring supplied as the matcher's argument."
  ;; EXPECTED is the list of tokens after the matcher name (cl-weave's calling
  ;; convention, as in :TO-BE-BETWEEN), so a single-argument matcher unwraps it.
  (destructuring-bind (needle) expected
    (handler-case
        (progn
          (funcall thunk)
          (values nil '(:signaled nil) `(:message-containing ,needle)))
      (error (condition)
        (let ((message (princ-to-string condition)))
          (values (and (search needle message) t)
                  `(:signaled t :message ,message)
                  `(:message-containing ,needle)))))))

(defmatcher :to-have-recorded-operations (calls expected)
  "Passes when CALLS -- a list of recorded-call plists -- carries exactly the
matcher's operation-keyword list as its :OPERATION values, in recorded order."
  (destructuring-bind (expected-operations) expected
    (let ((operations (mapcar (lambda (call) (getf call :operation)) calls)))
      (values (equal operations expected-operations)
              `(:operations ,operations)
              `(:operations ,expected-operations)))))
