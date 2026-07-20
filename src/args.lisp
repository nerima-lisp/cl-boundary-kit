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
  ;; Resolve SB-EXT:*POSIX-ARGV* at call time via FIND-SYMBOL rather than a
  ;; read-time package reference, so this file still loads where SB-EXT is
  ;; absent (for example the examples bootstrap on a non-SBCL host).
  (let ((argv (and (find-package "SB-EXT")
                   (find-symbol "*POSIX-ARGV*" "SB-EXT"))))
    (if (and argv (boundp argv))
        (copy-list (symbol-value argv))
        '())))

(defun make-args (&key (arguments (%default-command-line-arguments)))
  "Create a command-line arguments boundary over ARGUMENTS.

ARGUMENTS defaults to the host process's argument vector, so this is the path
that reads the real command line. `args-list` returns the arguments, `args-nth`
returns one by zero-based index (or NIL when out of range), and `args-count`
returns how many there are."
  (make-instance 'args :arguments (%validate-args-list arguments)))

(defun make-test-args (&key arguments)
  "Create a command-line arguments boundary from an explicit ARGUMENTS list.

This is the deterministic double for tests: it reads the supplied list instead
of the host process's argument vector."
  (make-instance 'test-args :arguments (%validate-args-list arguments)))

(defun make-recording-args (&key (delegate (make-test-args)))
  "Create a command-line arguments boundary that records reads while delegating
to DELEGATE, which defaults to an empty `make-test-args`."
  (require-instance delegate 'args "DELEGATE")
  (make-instance 'recording-args :arguments '() :delegate delegate))

(defun recording-args-calls (args)
  "Return the recorded command-line argument calls in call order."
  (unless (typep args 'recording-args)
    (error "Unsupported command-line arguments type: ~S" args))
  (%snapshot-recorded-calls (%recording-args-calls args)))

(defun reset-recording-args-calls (args)
  "Clear ARGS's recorded call history and return ARGS.

A recording arguments boundary otherwise retains every call for the object's
whole lifetime; call this periodically to bound memory growth instead of only
being able to reclaim it by discarding the object."
  (unless (typep args 'recording-args)
    (error "Unsupported command-line arguments type: ~S" args))
  (setf (%recording-args-calls args) nil)
  args)

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

(defmethod args-list ((args recording-args))
  (let ((result (args-list (recording-args-delegate args))))
    (%record-call (%recording-args-calls args)
      :operation :list
      :arguments '()
      :result result)
    result))

(defmethod args-count ((args recording-args))
  (let ((result (args-count (recording-args-delegate args))))
    (%record-call (%recording-args-calls args)
      :operation :count
      :arguments '()
      :result result)
    result))

(defmethod args-nth ((args recording-args) index)
  (let ((result (args-nth (recording-args-delegate args) index)))
    (%record-call (%recording-args-calls args)
      :operation :nth
      :arguments (list index)
      :result result)
    result))
