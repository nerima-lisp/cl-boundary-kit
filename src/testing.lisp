;;;; src/testing.lisp

(in-package #:cl-boundary-kit)

(defun assert-recorded-call (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
  "Assert that CALLS contains OPERATION with optional ARGUMENTS and RESULT expectations."
  (let ((matches (%matching-recorded-calls calls
                                          operation
                                          arguments
                                          arguments-supplied-p
                                          result
                                          result-supplied-p)))
    (or (first matches)
      (let ((same-operation-calls
              (remove-if-not (lambda (call)
                               (eql (getf call :operation) operation))
                             calls)))
        (error "Expected recorded call ~S, matching ~S candidates were ~S, all calls were ~S"
               (%recorded-call-expectation operation
                                           arguments
                                           arguments-supplied-p
                                           result
                                           result-supplied-p)
               operation
               same-operation-calls
               calls)))))

(defun assert-recorded-call-count (calls operation expected-count &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
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
               (error "Expected recorded call at index ~D matching ~S, but calls ended after ~D entries"
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

(defun boundary-call-plist (operation arguments &key (result nil result-supplied-p))
  "Build the canonical recorded-call plist for OPERATION, ARGUMENTS, and optional RESULT."
  (unless (listp arguments)
    (error "BOUNDARY-CALL-PLIST expected ARGUMENTS to be a list, got ~S" arguments))
  (if result-supplied-p
      (list :operation operation :arguments arguments :result result)
      (list :operation operation :arguments arguments)))
