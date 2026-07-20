;;;; src/console.lisp

(in-package #:cl-boundary-kit)

(defclass console ()
  ((input-stream :initarg :input-stream :reader console-input-stream)
   (output-stream :initarg :output-stream :reader console-output-stream)
   (error-stream :initarg :error-stream :reader console-error-stream)))

(defclass test-console (console)
  ((input-lines :initarg :input-lines :accessor %test-console-input-lines)
   (output :initform '() :accessor %test-console-output)
   (errors :initform '() :accessor %test-console-errors)))

(defclass recording-console (console)
  ((delegate :initarg :delegate :reader recording-console-delegate)
   (calls :initform '() :accessor %recording-console-calls)))

(defun %validate-console-stream (stream name)
  (unless (streamp stream)
    (error "~A must be a stream: ~S" name stream))
  stream)

(defun %validate-console-input-lines (input-lines)
  (unless (listp input-lines)
    (error "Test console input lines must be a list: ~S" input-lines))
  (dolist (line input-lines input-lines)
    (unless (stringp line)
      (error "Test console input line must be a string: ~S" line))))

(defun %validate-console-line (line)
  (unless (stringp line)
    (error "CONSOLE line must be a string: ~S" line))
  line)

(defun make-console (&key
                       (input *standard-input*)
                       (output *standard-output*)
                       (error *error-output*))
  "Create a console boundary over the INPUT, OUTPUT, and ERROR streams.

The defaults are the standard REPL streams, so this is the path that touches the
real terminal. `console-read-line` returns `nil` at end of input, and the write
operations return the line they emitted."
  (%validate-console-stream input "INPUT")
  (%validate-console-stream output "OUTPUT")
  (%validate-console-stream error "ERROR")
  (make-instance 'console
                 :input-stream input
                 :output-stream output
                 :error-stream error))

(defun make-test-console (&key input-lines)
  "Create an in-memory console fake seeded with INPUT-LINES.

Each `console-read-line` consumes one queued line and returns `nil` once the
queue is exhausted, mirroring stream end of input. Writes are captured in memory
and exposed through `test-console-output` and `test-console-errors` instead of
touching the terminal."
  (make-instance 'test-console
                 :input-stream nil
                 :output-stream nil
                 :error-stream nil
                 :input-lines (copy-list (%validate-console-input-lines input-lines))))

(defun test-console-output (console)
  "Return the text written to CONSOLE's standard output, oldest first.

Each `console-write-line` and `console-write` contributes one entry; the
recording console distinguishes the two operations in its call history."
  (unless (typep console 'test-console)
    (error "Unsupported console type: ~S" console))
  (reverse (%test-console-output console)))

(defun test-console-errors (console)
  "Return the lines written to CONSOLE's error output, oldest first."
  (unless (typep console 'test-console)
    (error "Unsupported console type: ~S" console))
  (reverse (%test-console-errors console)))

(defun make-recording-console (&key (delegate (make-test-console)))
  "Create a console that records interactions while delegating to DELEGATE.

DELEGATE defaults to a `make-test-console`, so a recording console never blocks
on real terminal input unless you pass a delegate backed by a live stream."
  (require-instance delegate 'console "DELEGATE")
  (make-instance 'recording-console
                 :input-stream nil
                 :output-stream nil
                 :error-stream nil
                 :delegate delegate))

(defun recording-console-calls (console)
  "Return the recorded console calls in call order."
  (unless (typep console 'recording-console)
    (error "Unsupported console type: ~S" console))
  (%snapshot-recorded-calls (%recording-console-calls console)))

(defun reset-recording-console-calls (console)
  "Clear CONSOLE's recorded call history and return CONSOLE.

A recording console otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep console 'recording-console)
    (error "Unsupported console type: ~S" console))
  (setf (%recording-console-calls console) nil)
  console)

(defun console-format (console control-string &rest args)
  "Write to CONSOLE the string produced by `format`ting CONTROL-STRING with ARGS,
without adding a newline (use `~%` in CONTROL-STRING), and return that string.

A convenience over `console-write` for formatted output, so it works with any
console and a recording console records the resulting `:write`."
  (console-write console (apply #'format nil control-string args)))

(defun console-format-line (console control-string &rest args)
  "Write to CONSOLE the string produced by `format`ting CONTROL-STRING with ARGS,
followed by a newline (via `console-write-line`), and return that string.

The newline-terminated counterpart of `console-format`, so it works with any
console and a recording console records the resulting `:write-line`."
  (console-write-line console (apply #'format nil control-string args)))

(defun console-prompt (console prompt)
  "Write PROMPT to CONSOLE without a trailing newline, then read and return one
line of input (or NIL at end of input).

A convenience over `console-write` followed by `console-read-line`, so it works
with any console and a recording console records the write and the read."
  (console-write console prompt)
  (console-read-line console))

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
