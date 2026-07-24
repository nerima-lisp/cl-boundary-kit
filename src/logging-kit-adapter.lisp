;;;; src/logging-kit-adapter.lisp

(in-package #:cl-boundary-kit)

(defparameter %log-kit-level-alist
  (list (cons :debug log-kit:+level-debug+)
        (cons :info log-kit:+level-info+)
        (cons :warn log-kit:+level-warn+)
        (cons :error log-kit:+level-error+))
  "Maps this system's :DEBUG/:INFO/:WARN/:ERROR level keywords onto
`log-kit's corresponding level constants. Any other level (already a
log-kit level, or a custom integer) passes through MAKE-LOG-KIT-SINK-FN
unchanged.")

(defun %log-kit-level (level)
  (or (cdr (assoc level %log-kit-level-alist)) level))

(defun make-log-kit-sink-fn (log-kit-logger)
  "Return a SINK-FN for `make-logger' that forwards each emitted event to
LOG-KIT-LOGGER, a `log-kit:logger' from the nerima-lisp `cl-log-kit'
structured logging toolkit.

This lets a boundary logger keep this system's DEPENDENCY-INJECTED
recording/test doubles (`make-test-logger', `make-recording-logger') for
tests while its real sink is a genuine structured destination -- JSON or
text, sync to a stream, filtered by level, and so on -- provided by
`cl-log-kit' rather than a hand-rolled function.

  (make-logger
    :sink-fn (make-log-kit-sink-fn
              (log-kit:make-logger :handler (make-instance 'log-kit:json-handler))))

Signals an error when LOG-KIT-LOGGER is not a `log-kit:logger'."
  (require-instance log-kit-logger 'log-kit:logger "LOG-KIT-LOGGER")
  (lambda (event)
    (log-kit:emit-log log-kit-logger
                       (%log-kit-level (getf event :level))
                       (getf event :message)
                       (getf event :fields))))
