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

(defmethod %logger-events ((logger logger))
  (error "Unsupported logger type: ~S" logger))

(defun %make-log-event (logger level message fields)
  (list :timestamp (funcall (logger-timestamp-fn logger))
        :level level
        :message (%copy-boundary-value message)
        :fields (%copy-boundary-value fields)))

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

(define-recording-boundary-constructor make-recording-logger recording-logger logger (make-logger)
  "Create a logger that records events before forwarding them to DELEGATE."
  :sink-fn (logger-sink-fn delegate) :timestamp-fn (logger-timestamp-fn delegate))

(defun recording-log-events (logger)
  "Return the recorded log events in emission order."
  (%snapshot-boundary-events (%logger-events logger)))

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
  (%emit-boundary-event (logger-sink-fn logger) event))

(defmethod %logger-emit-event ((logger test-logger) event)
  (push (%copy-boundary-event event) (%logger-events logger))
  event)

(defmethod %logger-emit-event ((logger recording-logger) event)
  ;; Nesting recording-loggers is intentional and tested (each level records
  ;; its own copy while the event cascades to the innermost real sink), so
  ;; the delegate is still reached via %LOGGER-EMIT-EVENT, not LOGGER's own
  ;; copied SINK-FN. The one case that must NOT recurse is a TEST-LOGGER
  ;; delegate: it has no real sink (its own event list *is* its effect), so
  ;; recursing into its %LOGGER-EMIT-EVENT method would push the event onto
  ;; the delegate's own history too -- double-recording, not cascading.
  (push (%copy-boundary-event event) (%logger-events logger))
  ;; No copy for the delegate call: whichever %LOGGER-EMIT-EVENT method
  ;; handles EVENT next always makes its own defensive copy before storing or
  ;; forwarding it further, so a copy made here just to hand off would be
  ;; discarded unused.
  (let ((delegate (recording-logger-delegate logger)))
    (unless (typep delegate 'test-logger)
      (%logger-emit-event delegate event)))
  event)

(defmethod logger-log ((logger logger) level message &rest fields)
  (%logger-emit-event logger (%make-log-event logger level message fields)))

(defun logger-debug (logger message &rest fields)
  "Emit a `:debug` level event through LOGGER; sugar over `logger-log`."
  (apply #'logger-log logger :debug message fields))

(defun logger-info (logger message &rest fields)
  "Emit an `:info` level event through LOGGER; sugar over `logger-log`."
  (apply #'logger-log logger :info message fields))

(defun logger-warn (logger message &rest fields)
  "Emit a `:warn` level event through LOGGER; sugar over `logger-log`."
  (apply #'logger-log logger :warn message fields))

(defun logger-error (logger message &rest fields)
  "Emit an `:error` level event through LOGGER; sugar over `logger-log`."
  (apply #'logger-log logger :error message fields))
