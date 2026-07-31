;;;; src/args.lisp

(in-package #:cl-boundary-kit)

(defclass args ()
  ((arguments :initarg :arguments :reader args-arguments)))

(defclass test-args (args) ())

(defclass recording-args (args)
  ((delegate :initarg :delegate :reader recording-args-delegate)
   (calls :initform '() :accessor %recording-args-calls)))

(defun %validate-args-list (arguments)
  (unless (listp arguments)
    (error "Command-line arguments must be a list: ~S" arguments))
  (dolist (argument arguments arguments)
    (unless (stringp argument)
      (error "Command-line argument must be a string: ~S" argument))))

(defun %default-command-line-arguments ()
  (host-kit:command-line-arguments))

(defun make-args (&key (arguments (%default-command-line-arguments)))
  "Create a command-line arguments boundary over ARGUMENTS.

ARGUMENTS defaults to the host process's argument vector, so this is the path
that reads the real command line. `args-list` returns the arguments, `args-nth`
returns one by zero-based index (or NIL when out of range), and `args-count`
returns how many there are."
  (make-instance 'args :arguments (copy-list (%validate-args-list arguments))))

(defun make-test-args (&key arguments)
  "Create a command-line arguments boundary from an explicit ARGUMENTS list.

This is the deterministic double for tests: it reads the supplied list instead
of the host process's argument vector."
  (make-instance 'test-args :arguments (copy-list (%validate-args-list arguments))))

(define-recording-boundary-constructor make-recording-args recording-args args (make-test-args)
  "Create a command-line arguments boundary that records reads while delegating
to DELEGATE, which defaults to an empty `make-test-args`."
  :arguments '())

(define-recording-call-log recording-args-calls reset-recording-args-calls
    (args recording-args %recording-args-calls) "command-line arguments")

(defun args-rest (args start)
  "Return ARGS's command-line arguments from zero-based START onward, as a fresh
list.

Derived from `args-list`, so it works across every variant and a recording
arguments boundary records the underlying `:list`. Useful for dropping a leading
program name, e.g. `(args-rest args 1)`."
  (unless (and (integerp start) (>= start 0))
    (error "ARGS-REST start must be a non-negative integer: ~S" start))
  (nthcdr start (args-list args)))

(defmethod args-list ((args args))
  (copy-list (args-arguments args)))

(defmethod args-count ((args args))
  (length (args-arguments args)))

(defmethod args-nth ((args args) index)
  (unless (and (integerp index) (>= index 0))
    (error "ARGS-NTH index must be a non-negative integer: ~S" index))
  (nth index (args-arguments args)))

(define-recording-delegate-method args-list
    (args recording-args recording-args-delegate %recording-args-calls)
    (() ()) :list '())

(define-recording-delegate-method args-count
    (args recording-args recording-args-delegate %recording-args-calls)
    (() ()) :count '())

(define-recording-delegate-method args-nth
    (args recording-args recording-args-delegate %recording-args-calls)
    ((index) (index)) :nth (list index))
