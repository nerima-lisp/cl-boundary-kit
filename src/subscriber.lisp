;;;; src/subscriber.lisp

(in-package #:cl-boundary-kit)

(defclass subscriber ()
  ((poll-fn :initarg :poll-fn :reader subscriber-poll-fn)))

(defclass test-subscriber (subscriber)
  ((messages :initarg :messages :accessor %test-subscriber-messages)))

(defclass recording-subscriber (subscriber)
  ((delegate :initarg :delegate :reader recording-subscriber-delegate)
   (calls :initform '() :accessor %recording-subscriber-calls)))

(define-list-validator %validate-subscriber-messages messages "Test subscriber messages")

(defun make-subscriber (&key poll-fn)
  "Create a subscriber boundary backed by POLL-FN.

`subscriber-poll` calls POLL-FN with no arguments and returns whatever message
it yields (or NIL when none is available). Wire POLL-FN to a real message source
at the application edge; it is validated at construction time."
  (require-function poll-fn "POLL-FN")
  (make-instance 'subscriber :poll-fn poll-fn))

(defun make-test-subscriber (&key messages)
  "Create a queue-backed subscriber fake that yields MESSAGES in order.

Each `subscriber-poll` call consumes one queued message and returns NIL once the
  queue is exhausted, mirroring a poll that finds nothing waiting."
  (make-instance 'test-subscriber
                 :poll-fn nil
                 :messages (copy-list (%validate-subscriber-messages messages))))

(define-recording-boundary-constructor make-recording-subscriber
    recording-subscriber subscriber (make-test-subscriber)
  "Create a subscriber that records polls while delegating to DELEGATE, which
defaults to an empty `make-test-subscriber`."
  :poll-fn nil)

(define-recording-call-log recording-subscriber-calls reset-recording-subscriber-calls
    (subscriber recording-subscriber %recording-subscriber-calls) "subscriber")

(defun subscriber-poll-batch (subscriber max)
  "Poll SUBSCRIBER up to MAX times, collecting messages until a poll returns NIL
or MAX messages have been collected, and return the list of messages in poll
order.

MAX bounds the work so this always terminates, even for a subscriber that keeps
returning messages. Derived from `subscriber-poll`, so it works with any
subscriber and a recording subscriber records each poll."
  (unless (and (integerp max) (>= max 0))
    (error "SUBSCRIBER-POLL-BATCH max must be a non-negative integer: ~S" max))
  (loop repeat max
        for message = (subscriber-poll subscriber)
        while message
        collect message))

(defmethod subscriber-poll ((subscriber subscriber))
  (funcall (subscriber-poll-fn subscriber)))

(defmethod subscriber-poll ((subscriber test-subscriber))
  (let ((messages (%test-subscriber-messages subscriber)))
    (when messages
      (setf (%test-subscriber-messages subscriber) (rest messages))
      (first messages))))

(define-recording-delegate-method subscriber-poll
    (subscriber recording-subscriber recording-subscriber-delegate %recording-subscriber-calls)
    (() ()) :poll '())
