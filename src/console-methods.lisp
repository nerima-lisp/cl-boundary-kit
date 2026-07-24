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
  (%validate-console-line line)
  (write-line line (console-output-stream console))
  line)

(defmethod console-write ((console console) text)
  (%validate-console-line text)
  (write-string text (console-output-stream console))
  text)

(defmethod console-write-error ((console console) line)
  (%validate-console-line line)
  (write-line line (console-error-stream console))
  line)

(defmethod console-read-line ((console test-console))
  (let ((lines (%test-console-input-lines console)))
    (when lines
      (setf (%test-console-input-lines console) (rest lines))
      (first lines))))

(defmethod console-write-line ((console test-console) line)
  (%validate-console-line line)
  (push line (%test-console-output console))
  line)

(defmethod console-write ((console test-console) text)
  (%validate-console-line text)
  (push text (%test-console-output console))
  text)

(defmethod console-write-error ((console test-console) line)
  (%validate-console-line line)
  (push line (%test-console-errors console))
  line)

(defmethod console-read-line ((console recording-console))
  (let ((result (console-read-line (recording-console-delegate console))))
    (%record-call (%recording-console-calls console)
      :operation :read-line
      :arguments '()
      :result result)
    result))

(defmethod console-write-line ((console recording-console) line)
  (%validate-console-line line)
  (let ((result (console-write-line (recording-console-delegate console) line)))
    (%record-call (%recording-console-calls console)
      :operation :write-line
      :arguments (list line)
      :result result)
    result))

(defmethod console-write ((console recording-console) text)
  (%validate-console-line text)
  (let ((result (console-write (recording-console-delegate console) text)))
    (%record-call (%recording-console-calls console)
      :operation :write
      :arguments (list text)
      :result result)
    result))

(defmethod console-write-error ((console recording-console) line)
  (%validate-console-line line)
  (let ((result (console-write-error (recording-console-delegate console) line)))
    (%record-call (%recording-console-calls console)
      :operation :write-error
      :arguments (list line)
      :result result)
    result))
