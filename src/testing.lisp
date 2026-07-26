;;;; src/testing.lisp

(in-package #:cl-boundary-kit)

(defun assert-recorded-call (calls operation
                             &key (arguments nil arguments-supplied-p)
                                  (result nil result-supplied-p))
  "Assert that CALLS contains OPERATION with optional ARGUMENTS and RESULT expectations."
  (let ((same-operation-calls '())
        (matching-call nil))
    (loop for call in calls
          when (eql (getf call :operation) operation)
            do (push call same-operation-calls)
          when (and (null matching-call)
                    (%recorded-call-matches-p call
                                              operation
                                              arguments
                                              arguments-supplied-p
                                              result
                                              result-supplied-p))
            do (setf matching-call call))
    (if matching-call
        matching-call
        (error "Expected recorded call ~S, matching ~S candidates were ~S, all calls were ~S"
               (%recorded-call-expectation operation
                                           arguments
                                           arguments-supplied-p
                                           result
                                           result-supplied-p)
               operation
               (nreverse same-operation-calls)
               calls))))

(defun assert-recorded-call-count (calls operation expected-count
                                   &key (arguments nil arguments-supplied-p)
                                        (result nil result-supplied-p))
  "Assert that CALLS contains EXPECTED-COUNT matches for OPERATION and optional expectations."
  (let* ((matches (%matching-recorded-calls calls
                                            operation
                                            arguments
                                            arguments-supplied-p
                                            result
                                            result-supplied-p))
         (actual-count (length matches)))
    (unless (= actual-count expected-count)
      (error "Expected ~D recorded calls matching ~S, got ~D matching calls ~S, all calls were ~S"
             expected-count
             (%recorded-call-expectation operation
                                         arguments
                                         arguments-supplied-p
                                         result
                                         result-supplied-p)
             actual-count
             matches
             calls))
    matches))

(defun assert-recorded-call-sequence (calls expected-calls &key (exact-length t))
  "Assert that CALLS matches EXPECTED-CALLS in order.

When EXACT-LENGTH is true, CALLS must have the same length as EXPECTED-CALLS.
Each EXPECTED-CALLS entry must be a plist containing at least :OPERATION and may
optionally constrain :ARGUMENTS and :RESULT."
  (unless (listp expected-calls)
    (error "ASSERT-RECORDED-CALL-SEQUENCE expected EXPECTED-CALLS to be a list, got ~S"
           expected-calls))
  (let ((validated-expectations (mapcar #'%validate-recorded-call-expectation expected-calls)))
    (when (and exact-length (/= (length calls) (length validated-expectations)))
      (error "Expected recorded call sequence length ~D, got ~D calls ~S"
             (length validated-expectations)
             (length calls)
             calls))
    (loop for expectation in validated-expectations
          for index from 0
          for remaining = calls then (rest remaining)
          do (unless remaining
               (error
                "Expected recorded call at index ~D matching ~S, but calls ended after ~D entries"
                index
                expectation
                index))
             (unless (%recorded-call-sequence-entry-matches-p (first remaining) expectation)
               (error "Recorded call mismatch at index ~D, expected ~S, got ~S, all calls were ~S"
                      index
                      expectation
                      (first remaining)
                      calls)))
    calls))

(defun assert-no-recorded-call (calls operation
                                &key (arguments nil arguments-supplied-p)
                                     (result nil result-supplied-p))
  "Assert that CALLS contains no match for OPERATION and optional expectations.

Returns CALLS when the assertion holds, signaling an error otherwise. This lets
tests assert that a boundary operation did not happen, which an
`assert-recorded-call` cannot express."
  (let ((matches (%matching-recorded-calls calls
                                           operation
                                           arguments
                                           arguments-supplied-p
                                           result
                                           result-supplied-p)))
    (when matches
      (error "Expected no recorded call matching ~S, but found ~D: ~S"
             (%recorded-call-expectation operation
                                         arguments
                                         arguments-supplied-p
                                         result
                                         result-supplied-p)
             (length matches)
             matches))
    calls))

(defun assert-recorded-operations (calls &rest operations)
  "Assert that CALLS' operations are exactly OPERATIONS, in order.

Unlike `assert-recorded-call-sequence`, this ignores arguments and results and
only checks the operation names; unlike `assert-recorded-call-order`, it requires
the operations to match exactly (same length, no gaps). Returns CALLS when the
assertion holds, signaling an error otherwise."
  (let ((actual (recorded-call-operations calls)))
    (unless (equal actual operations)
      (error "Expected recorded operations ~S in order, got ~S; all calls were ~S"
             operations actual calls))
    calls))

(defun assert-recorded-call-order (calls &rest operations)
  "Assert that OPERATIONS appear in CALLS in that order as a subsequence.

The operations need not be contiguous or adjacent; only their relative order
matters, so this checks that (for example) an `:open` was recorded before a
`:close`. Returns CALLS when the assertion holds, signaling an error otherwise."
  (let ((remaining operations))
    (dolist (call calls)
      (when (and remaining (eql (getf call :operation) (first remaining)))
        (setf remaining (rest remaining))))
    (when remaining
      (error "Expected recorded operations ~S in order, but ~S did not all appear in sequence in ~S"
             operations remaining calls))
    calls))
