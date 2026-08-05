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

(define-scalar-validator %validate-console-stream stream
    (streamp stream)
  "a stream" name)

(define-list-validator %validate-console-input-lines input-lines
    "Test console input lines"
  (line (stringp line) "a string" "Test console input line"))

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

(define-recording-boundary-constructor make-recording-console
    recording-console console (make-test-console)
  "Create a console that records interactions while delegating to DELEGATE.

DELEGATE defaults to a `make-test-console`, so a recording console never blocks
on real terminal input unless you pass a delegate backed by a live stream."
  :input-stream nil :output-stream nil :error-stream nil)

(define-recording-call-log recording-console-calls reset-recording-console-calls
    (console recording-console %recording-console-calls) "console")

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
