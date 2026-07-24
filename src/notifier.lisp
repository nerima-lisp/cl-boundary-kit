;;;; src/notifier.lisp

(in-package #:cl-boundary-kit)

(defclass notifier ()
  ((emit-fn :initarg :emit-fn :reader notifier-emit-fn)))

(defclass test-notifier (notifier)
  ((events :initform '() :accessor %notifier-events)))

(defclass recording-notifier (notifier)
  ((delegate :initarg :delegate :reader recording-notifier-delegate)
   (events :initform '() :accessor %notifier-events)))

(define-emit-event-boundary-dispatch notifier)

(defun %validate-notification-field (value name)
  (unless (stringp value)
    (error "~A must be a string: ~S" name value))
  value)

(defun %make-notification (recipient subject body)
  (list :recipient (%copy-boundary-value recipient)
        :subject (%copy-boundary-value subject)
        :body (%copy-boundary-value body)))

(defun make-notifier (&key (emit-fn (lambda (event) (declare (ignore event)) nil)))
  "Create a notifier boundary that sends notifications to EMIT-FN.

EMIT-FN receives each notification event plist. The default drops events, so a
plain `make-notifier` is a no-op sink; inject EMIT-FN to forward notifications to
a real email or push backend."
  (require-function emit-fn "EMIT-FN")
  (make-instance 'notifier :emit-fn emit-fn))

(defun make-test-notifier ()
  "Create a notifier boundary that stores sent notifications in memory.

Each `notifier-notify` call records a `(:recipient <r> :subject <s> :body <b>)`
event and returns it. The events are available through
`recording-sent-notifications`."
  (make-instance 'test-notifier :emit-fn nil))

(defun make-recording-notifier (&key (delegate (make-notifier)))
  "Create a notifier that records notifications before forwarding them to DELEGATE.

DELEGATE defaults to a no-op `make-notifier` sink. The recorded notifications are
available through `recording-sent-notifications`."
  (require-instance delegate 'notifier "DELEGATE")
  (make-instance 'recording-notifier
                 :emit-fn (notifier-emit-fn delegate)
                 :delegate delegate))

(defun recording-sent-notifications (notifier)
  "Return the recorded notifications in send order."
  (%snapshot-boundary-events (%notifier-events notifier)))

(defun reset-recording-sent-notifications (notifier)
  "Clear NOTIFIER's recorded notification history and return NOTIFIER.

Recording/test notifiers otherwise retain every notification for the object's
whole lifetime; call this periodically to bound memory growth instead of only
being able to reclaim it by discarding the object."
  (%reset-notifier-events notifier)
  notifier)

(defmethod notifier-notify ((notifier notifier) recipient subject body)
  (%validate-notification-field recipient "Notification recipient")
  (%validate-notification-field subject "Notification subject")
  (%validate-notification-field body "Notification body")
  (%notifier-emit-event notifier (%make-notification recipient subject body)))
