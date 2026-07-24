(in-package #:cl-boundary-kit)

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

(defun %find-event (events constraints)
  (loop for event in events
        when (%event-matches-p event constraints)
        do (return event)))

(defun find-event (events &rest constraints)
  "Return the first event in EVENTS matching all CONSTRAINTS, or NIL.

CONSTRAINTS is a plist of key/value pairs; an event matches when each key in
CONSTRAINTS holds the given value (compared with `equal`). Works for any event
plist shape, so it applies to the log, metric, published-message, and
notification events captured by the fire-and-forget boundaries."
  (%find-event events constraints))

(defun %count-events (events constraints)
  (loop for event in events
        count (%event-matches-p event constraints)))

(defun count-events (events &rest constraints)
  "Return how many events in EVENTS match all CONSTRAINTS (a key/value plist)."
  (%count-events events constraints))

(defun assert-event-present (events &rest constraints)
  "Assert that some event in EVENTS matches all CONSTRAINTS, returning the first
match and signaling an error otherwise. CONSTRAINTS is a key/value plist."
  (or (%find-event events constraints)
      (error "Expected an event matching ~S, but none of ~S matched" constraints events)))

(defun assert-no-event (events &rest constraints)
  "Assert that no event in EVENTS matches CONSTRAINTS, returning EVENTS and
signaling an error otherwise. CONSTRAINTS is a key/value plist."
  (let ((match (%find-event events constraints)))
    (when match
      (error "Expected no event matching ~S, but found ~S" constraints match))
    events))

(defun assert-event-count (events expected-count &rest constraints)
  "Assert that exactly EXPECTED-COUNT events in EVENTS match CONSTRAINTS, returning
EVENTS. CONSTRAINTS is a key/value plist. This mirrors `assert-recorded-call-count`
for the event-based boundaries."
  (let ((actual (%count-events events constraints)))
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
