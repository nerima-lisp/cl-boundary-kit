;;;; src/publisher.lisp

(in-package #:cl-boundary-kit)

(defclass publisher ()
  ((emit-fn :initarg :emit-fn :reader publisher-emit-fn)))

(defclass test-publisher (publisher)
  ((events :initform '() :accessor %publisher-events)))

(defclass recording-publisher (publisher)
  ((delegate :initarg :delegate :reader recording-publisher-delegate)
   (events :initform '() :accessor %publisher-events)))

(define-emit-event-boundary-dispatch publisher)

(define-name-validator %validate-publisher-topic topic "Publisher topic")

(defun %make-published-message (topic message)
  (list :topic (%copy-boundary-value topic)
        :message (%copy-boundary-value message)))

(defun make-publisher (&key (emit-fn (lambda (event) (declare (ignore event)) nil)))
  "Create a publisher boundary that sends messages to EMIT-FN.

EMIT-FN receives each published message event plist. The default drops events,
so a plain `make-publisher` is a no-op sink; inject EMIT-FN to forward messages
to a real broker or bus."
  (require-function emit-fn "EMIT-FN")
  (make-instance 'publisher :emit-fn emit-fn))

(defun make-test-publisher ()
  "Create a publisher boundary that stores published messages in memory.

Each `publisher-publish` call records a `(:topic <topic> :message <message>)`
event and returns it. The events are available through
`recording-published-messages`."
  (make-instance 'test-publisher :emit-fn nil))

(define-recording-boundary-constructor make-recording-publisher recording-publisher publisher (make-publisher)
  "Create a publisher that records messages before forwarding them to DELEGATE.

DELEGATE defaults to a no-op `make-publisher` sink. The recorded messages are
available through `recording-published-messages`."
  :emit-fn (publisher-emit-fn delegate))

(defun recording-published-messages (publisher)
  "Return the recorded published messages in emission order."
  (%snapshot-boundary-events (%publisher-events publisher)))

(defun reset-recording-published-messages (publisher)
  "Clear PUBLISHER's recorded message history and return PUBLISHER.

Recording/test publishers otherwise retain every message for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (%reset-publisher-events publisher)
  publisher)

(defmethod publisher-publish ((publisher publisher) topic message)
  (%validate-publisher-topic topic)
  (%publisher-emit-event publisher (%make-published-message topic message)))
