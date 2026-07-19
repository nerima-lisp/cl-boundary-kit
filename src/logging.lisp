;;;; src/logging.lisp

;;;; src/logging.lisp

(in-package #:cl-boundary-kit)

(defclass logger ()
  ((sink-fn :initarg :sink-fn :reader logger-sink-fn)
   (timestamp-fn :initarg :timestamp-fn :reader logger-timestamp-fn)))

(defclass test-logger (logger)
  ((events :initform '() :accessor %logger-events)))

(defclass recording-logger (logger)
  ((delegate :initarg :delegate :reader recording-logger-delegate)
   (events :initform '() :accessor %logger-events)))

(defgeneric %logger-events (logger))

(defmethod %logger-events ((logger logger))
  (error "Unsupported logger type: ~S" logger))

(defun %make-log-event (logger level message fields)
  (list :timestamp (funcall (logger-timestamp-fn logger))
        :level level
        :message message
        :fields fields))

(defgeneric %logger-emit-event (logger event))

(defun make-logger (&key
                      (sink-fn (lambda (event) (declare (ignore event)) nil))
                      (timestamp-fn #'get-universal-time))
  "Create a logger that sends events to SINK-FN with timestamps from TIMESTAMP-FN."
  (require-function sink-fn "SINK-FN")
  (require-function timestamp-fn "TIMESTAMP-FN")
  (make-instance 'logger :sink-fn sink-fn :timestamp-fn timestamp-fn))

(defun make-test-logger (&key (timestamp-fn #'get-universal-time))
  "Create a logger that stores emitted events in memory."
  (require-function timestamp-fn "TIMESTAMP-FN")
  (make-instance 'test-logger
                 :sink-fn nil
                 :timestamp-fn timestamp-fn))

(defun make-recording-logger (&key (delegate (make-logger)))
  "Create a logger that records events before forwarding them to DELEGATE."
  (require-instance delegate 'logger "DELEGATE")
  (make-instance 'recording-logger
                 :sink-fn (logger-sink-fn delegate)
                 :timestamp-fn (logger-timestamp-fn delegate)
                 :delegate delegate))

(defun recording-log-events (logger)
  "Return the recorded log events in emission order."
  ;; Copy only the spine: LOGGER-LOG returns each event object to the caller,
  ;; and RECORDING-LOG-EVENTS is contracted to return those same objects (EQ),
  ;; so entries must not be copied the way %SNAPSHOT-RECORDED-CALLS would.
  (reverse (%logger-events logger)))

(defgeneric %reset-logger-events (logger))

(defmethod %reset-logger-events ((logger logger))
  (error "Unsupported logger type: ~S" logger))

(defmethod %reset-logger-events ((logger test-logger))
  (setf (%logger-events logger) nil))

(defmethod %reset-logger-events ((logger recording-logger))
  (setf (%logger-events logger) nil))

(defun reset-recording-log-events (logger)
  "Clear LOGGER's recorded event history and return LOGGER.

Recording/test loggers otherwise retain every event for the object's whole
lifetime; call this periodically to bound memory growth instead of only
being able to reclaim it by discarding the object."
  (%reset-logger-events logger)
  logger)

(defmethod %logger-emit-event ((logger logger) event)
  (funcall (logger-sink-fn logger) event)
  event)

(defmethod %logger-emit-event ((logger test-logger) event)
  (push event (%logger-events logger))
  event)

(defmethod %logger-emit-event ((logger recording-logger) event)
  ;; Nesting recording-loggers is intentional and tested (each level records
  ;; its own copy while the event cascades to the innermost real sink), so
  ;; the delegate is still reached via %LOGGER-EMIT-EVENT, not LOGGER's own
  ;; copied SINK-FN. The one case that must NOT recurse is a TEST-LOGGER
  ;; delegate: it has no real sink (its own event list *is* its effect), so
  ;; recursing into its %LOGGER-EMIT-EVENT method would push the event onto
  ;; the delegate's own history too -- double-recording, not cascading.
  (push event (%logger-events logger))
  (let ((delegate (recording-logger-delegate logger)))
    (unless (typep delegate 'test-logger)
      (%logger-emit-event delegate event)))
  event)

(defmethod logger-log ((logger logger) level message &rest fields)
  (%logger-emit-event logger (%make-log-event logger level message fields)))
