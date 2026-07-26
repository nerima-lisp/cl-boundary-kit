;;;; src/console-methods.lisp
;;;;
;;;; The console protocol method implementations for each concrete class: the
;;;; native console reads/writes real streams, the test console drains queued
;;;; input and buffers output, and the recording console delegates while logging
;;;; each call. Split from console.lisp, which holds the classes, constructors,
;;;; and derived convenience operations these methods sit under.

(in-package #:cl-boundary-kit)

(defmethod console-read-line ((console console))
  (read-line (console-input-stream console) nil nil))

(defmethod console-write-line ((console console) line)
  (require-string line "CONSOLE line")
  (write-line line (console-output-stream console))
  line)

(defmethod console-write ((console console) text)
  (require-string text "CONSOLE line")
  (write-string text (console-output-stream console))
  text)

(defmethod console-write-error ((console console) line)
  (require-string line "CONSOLE line")
  (write-line line (console-error-stream console))
  line)

(defmethod console-read-line ((console test-console))
  (let ((lines (%test-console-input-lines console)))
    (when lines
      (setf (%test-console-input-lines console) (rest lines))
      (first lines))))

(defmethod console-write-line ((console test-console) line)
  (require-string line "CONSOLE line")
  (push line (%test-console-output console))
  line)

(defmethod console-write ((console test-console) text)
  (require-string text "CONSOLE line")
  (push text (%test-console-output console))
  text)

(defmethod console-write-error ((console test-console) line)
  (require-string line "CONSOLE line")
  (push line (%test-console-errors console))
  line)

(define-recording-delegate-method console-read-line
    (console recording-console recording-console-delegate %recording-console-calls)
    (() ()) :read-line '())

(define-recording-delegate-method console-write-line
    (console recording-console recording-console-delegate %recording-console-calls)
    ((line) (line)) :write-line (list line)
  (require-string line "CONSOLE line"))

(define-recording-delegate-method console-write
    (console recording-console recording-console-delegate %recording-console-calls)
    ((text) (text)) :write (list text)
  (require-string text "CONSOLE line"))

(define-recording-delegate-method console-write-error
    (console recording-console recording-console-delegate %recording-console-calls)
    ((line) (line)) :write-error (list line)
  (require-string line "CONSOLE line"))
