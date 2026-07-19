;;;; src/protocols.lisp

(in-package #:cl-boundary-kit)

(defgeneric clock-now (clock)
  (:documentation "Return CLOCK's wall-clock time value."))
(defgeneric clock-monotonic (clock)
  (:documentation "Return CLOCK's monotonic time value."))

(defgeneric random-source-random (random-source limit)
  (:documentation "Return a pseudo-random value from RANDOM-SOURCE less than LIMIT."))

(defgeneric logger-log (logger level message &rest fields)
  (:documentation "Emit a log event through LOGGER with LEVEL, MESSAGE, and plist-style FIELDS."))
