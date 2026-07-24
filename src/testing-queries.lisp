;;;; src/testing-queries.lisp
;;;;
;;;; The reader layer over a recorded-call history: filtering, counting, and
;;;; locating calls, projecting their operations and results, and accessing an
;;;; individual call's fields. The assertion DSL in testing.lisp is built on top
;;;; of these, so reading and asserting stay separable.

(in-package #:cl-boundary-kit)

(defun filter-recorded-calls (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
  "Return the CALLS matching OPERATION and optional ARGUMENTS/RESULT expectations.

Unlike `assert-recorded-call`, this never signals; it returns the matching
subset (in CALLS order) so tests can inspect or further process them."
  (%matching-recorded-calls calls
                            operation
                            arguments
                            arguments-supplied-p
                            result
                            result-supplied-p))

(defun count-recorded-calls (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
  "Return how many CALLS match OPERATION and optional ARGUMENTS/RESULT expectations.

This is the non-asserting counterpart of `assert-recorded-call-count`."
  (loop for call in calls
        count (%recorded-call-matches-p call
                                        operation
                                        arguments
                                        arguments-supplied-p
                                        result
                                        result-supplied-p)))

(defun find-recorded-call (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
  "Return the first call in CALLS matching OPERATION and optional expectations, or NIL.

This is the single-result counterpart of `filter-recorded-calls`, mirroring
`find-event` for recorded operation calls."
  (loop for call in calls
        when (%recorded-call-matches-p call
                                       operation
                                       arguments
                                       arguments-supplied-p
                                       result
                                       result-supplied-p)
          do (return call)))

(defun recorded-call-operations (calls)
  "Return the `:operation` of each recorded call in CALLS, in call order."
  (mapcar (lambda (call) (getf call :operation)) calls))

(defun recorded-call-results (calls)
  "Return the `:result` of each recorded call in CALLS, in call order."
  (mapcar (lambda (call) (getf call :result)) calls))

(defun nth-recorded-call (calls index)
  "Return the recorded call at zero-based INDEX in CALLS, or NIL when out of range."
  (unless (and (integerp index) (>= index 0))
    (error "NTH-RECORDED-CALL index must be a non-negative integer: ~S" index))
  (nth index calls))

(defun last-recorded-call (calls)
  "Return the most recent recorded call in CALLS, or NIL when CALLS is empty."
  (car (last calls)))

(defun recorded-call-operation (call)
  "Return the `:operation` of a single recorded CALL."
  (getf call :operation))

(defun recorded-call-arguments (call)
  "Return the `:arguments` of a single recorded CALL."
  (getf call :arguments))

(defun recorded-call-result (call)
  "Return the `:result` of a single recorded CALL."
  (getf call :result))
