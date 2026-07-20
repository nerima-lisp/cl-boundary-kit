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
  (length (%matching-recorded-calls calls
                                    operation
                                    arguments
                                    arguments-supplied-p
                                    result
                                    result-supplied-p)))

(defun find-recorded-call (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
  "Return the first call in CALLS matching OPERATION and optional expectations, or NIL.

This is the single-result counterpart of `filter-recorded-calls`, mirroring
`find-event` for recorded operation calls."
  (first (%matching-recorded-calls calls
                                   operation
                                   arguments
                                   arguments-supplied-p
                                   result
                                   result-supplied-p)))

(defun assert-no-recorded-call (calls operation &key (arguments nil arguments-supplied-p) (result nil result-supplied-p))
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

(defun recorded-call-operations (calls)
  "Return the `:operation` of each recorded call in CALLS, in call order."
  (mapcar (lambda (call) (getf call :operation)) calls))

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

(defun %event-matches-p (event constraints)
  (unless (evenp (length constraints))
    (error "Event constraints must be a plist of key/value pairs: ~S" constraints))
  (loop for (key value) on constraints by #'cddr
        always (equal (getf event key) value)))

(defun event-values (events key)
  "Return the value of KEY from each event in EVENTS, in order.

This is the event-based counterpart of `recorded-call-operations`/`-results`:
where those pull a fixed field from operation-call records, `event-values` pulls
any KEY from the varying event shapes captured by the fire-and-forget boundaries
(for example every log event's `:level` or every metric's `:name`)."
  (mapcar (lambda (event) (getf event key)) events))

(defun find-event (events &rest constraints)
  "Return the first event in EVENTS matching all CONSTRAINTS, or NIL.

CONSTRAINTS is a plist of key/value pairs; an event matches when each key in
CONSTRAINTS holds the given value (compared with `equal`). Works for any event
plist shape, so it applies to the log, metric, published-message, and
notification events captured by the fire-and-forget boundaries."
  (find-if (lambda (event) (%event-matches-p event constraints)) events))

(defun count-events (events &rest constraints)
  "Return how many events in EVENTS match all CONSTRAINTS (a key/value plist)."
  (count-if (lambda (event) (%event-matches-p event constraints)) events))

(defun assert-event-present (events &rest constraints)
  "Assert that some event in EVENTS matches all CONSTRAINTS, returning the first
match and signaling an error otherwise. CONSTRAINTS is a key/value plist."
  (or (find-if (lambda (event) (%event-matches-p event constraints)) events)
      (error "Expected an event matching ~S, but none of ~S matched" constraints events)))

(defun assert-no-event (events &rest constraints)
  "Assert that no event in EVENTS matches CONSTRAINTS, returning EVENTS and
signaling an error otherwise. CONSTRAINTS is a key/value plist."
  (let ((match (find-if (lambda (event) (%event-matches-p event constraints)) events)))
    (when match
      (error "Expected no event matching ~S, but found ~S" constraints match))
    events))

(defun assert-event-count (events expected-count &rest constraints)
  "Assert that exactly EXPECTED-COUNT events in EVENTS match CONSTRAINTS, returning
EVENTS. CONSTRAINTS is a key/value plist. This mirrors `assert-recorded-call-count`
for the event-based boundaries."
  (let ((actual (count-if (lambda (event) (%event-matches-p event constraints)) events)))
    (unless (= actual expected-count)
      (error "Expected ~D events matching ~S, got ~D in ~S"
             expected-count constraints actual events))
    events))

(defun boundary-call-plist (operation arguments &key (result nil result-supplied-p))
  "Build the canonical recorded-call plist for OPERATION, ARGUMENTS, and optional RESULT."
  (unless (listp arguments)
    (error "BOUNDARY-CALL-PLIST expected ARGUMENTS to be a list, got ~S" arguments))
  (if result-supplied-p
      (list :operation operation :arguments arguments :result result)
      (list :operation operation :arguments arguments)))
