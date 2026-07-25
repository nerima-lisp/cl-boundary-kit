;;;; src/metrics.lisp

(in-package #:cl-boundary-kit)

(defclass metrics ()
  ((emit-fn :initarg :emit-fn :reader metrics-emit-fn)))

(defclass test-metrics (metrics)
  ((events :initform '() :accessor %metrics-events)))

(defclass recording-metrics (metrics)
  ((delegate :initarg :delegate :reader recording-metrics-delegate)
   (events :initform '() :accessor %metrics-events)))

(define-emit-event-boundary-dispatch metrics)

(define-name-validator %validate-metric-name name "Metric name")

(defun %validate-metric-value (value name)
  (unless (realp value)
    (error "~A must be a real number: ~S" name value))
  value)

(defun %validate-metric-timing (milliseconds)
  (unless (and (realp milliseconds) (>= milliseconds 0))
    (error "Metric timing milliseconds must be a non-negative real number: ~S" milliseconds))
  milliseconds)

(defun %make-metric-event (type name value)
  (list :type type :name (%copy-boundary-value name) :value value))

(defun make-metrics (&key (emit-fn (lambda (event) (declare (ignore event)) nil)))
  "Create a metrics boundary that sends events to EMIT-FN.

EMIT-FN receives each emitted metric event plist. The default drops events, so a
plain `make-metrics` is a no-op sink; inject EMIT-FN to forward metrics to a real
backend."
  (require-function emit-fn "EMIT-FN")
  (make-instance 'metrics :emit-fn emit-fn))

(defun make-test-metrics ()
  "Create a metrics boundary that stores emitted events in memory.

Each `metrics-count`, `metrics-gauge`, and `metrics-timing` call records an
event plist and returns it. The events are available through
`recording-metric-events`."
  (make-instance 'test-metrics :emit-fn nil))

(define-recording-boundary-constructor make-recording-metrics recording-metrics metrics (make-metrics)
  "Create a metrics boundary that records events before forwarding them to DELEGATE.

DELEGATE defaults to a no-op `make-metrics` sink. The recorded events are
available through `recording-metric-events`."
  :emit-fn (metrics-emit-fn delegate))

(defun recording-metric-events (metrics)
  "Return the recorded metric events in emission order."
  (%snapshot-boundary-events (%metrics-events metrics)))

(defun reset-recording-metric-events (metrics)
  "Clear METRICS's recorded event history and return METRICS.

Recording/test metrics otherwise retain every event for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (%reset-metrics-events metrics)
  metrics)

(defmethod metrics-count ((metrics metrics) name amount)
  (%validate-metric-name name)
  (%validate-metric-value amount "Metric count amount")
  (%metrics-emit-event metrics (%make-metric-event :count name amount)))

(defmethod metrics-gauge ((metrics metrics) name value)
  (%validate-metric-name name)
  (%validate-metric-value value "Metric gauge value")
  (%metrics-emit-event metrics (%make-metric-event :gauge name value)))

(defmethod metrics-timing ((metrics metrics) name milliseconds)
  (%validate-metric-name name)
  (%validate-metric-timing milliseconds)
  (%metrics-emit-event metrics (%make-metric-event :timing name milliseconds)))

(defun metrics-increment (metrics name)
  "Emit a counter metric named NAME incremented by 1; sugar over `metrics-count`."
  (metrics-count metrics name 1))
